# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Unit tests for Gat

require 'rubygems'
require 'bundler/setup'

require 'minitest/spec'
require 'minitest/autorun'

require 'tmpdir'
require 'fileutils'
require 'stringio'

require 'git'
require 'gat/gat'
require 'gat/git'

class TestGatSpec < MiniTest::Spec
  attr_reader :git

  def root
    @root = Pathname(Dir.mktmpdir('test_gat')) unless defined?(@root)
    @root
  end

  def gat_dir
    root.expand_path + '.gat'
  end

  def silent(&block)
    should_output nil, nil, &block
  end

  def file(name, content)
    pathname = root + name
    FileUtils.mkdir_p(pathname.dirname)
    pathname.open('w') do |f|
      f.write(content)
    end
    git.add(pathname.to_path)
  end

  def heredoc(content)
    content.gsub(/^\s+\|/, '')
  end

  def setup_git
    FileUtils.mkdir_p(root)
    @git = Git.init(root.to_path)
  end

  def all_test_files
    ['test1.txt', 'test2.txt', 'sub/subtest1.txt', 'sub/subtest2.txt']
  end

  def add_files
    all_test_files.each do |relative|
      file relative, "This is a test file #{relative}"
    end
    @git.commit_all('Initial import')
  end

  def setup_repo
    setup_git
    add_files
    silent { gat_init }
  end

  def cleanup
    @git = nil
    FileUtils.remove_entry(root)
  end

  def should_output(out, err, &block)
    block.must_output out, err
  end

  def should_have_no_output(&block)
    should_output '', '', &block
  end

  def should_err1(err, &block)
    should_err(err + "\n", &block)
  end

  def should_err(err, &block)
    should_output '', err, &block
  end

  def should_out1(out, &block)
    should_out(out + "\n", &block)
  end

  def should_out(out, &block)
    should_output out, '', &block
  end

  def files_should_have_same_content(file0, file1)
    file0.wont_equal file1
    File.read(file0).must_equal File.read(file1)
  end

  def files_wont_have_same_content(file0, file1)
    File.read(file0).wont_equal File.read(file1)
  end

  def gat_init
    Gat::Gat.init(root)
  end

  def gat_edit(filepath)
    Gat::Gat.edit(filepath)
  end

  def gat_check(message = nil)
    Gat::Gat.check(root, false, message)
  end

  def gat_force_check(message = nil)
    Gat::Gat.check(root, true, message)
  end

  def gat_resolve
    Gat::Gat.resolve(root)
  end

  def gat_next()
    Gat::Gat.next(root)
  end

  def gat_open
    Gat::Gat.open(root)
  end

  def gat_edit_filepath(filepath)
    out, err = capture_io { gat_edit(filepath) }
    err.must_be_empty
    Pathname(out.chomp)
  end

  def gat_edit_file_should_have_same_content_as_git(relative_filepath)
    filepath = root + relative_filepath
    gat_filepath = gat_edit_filepath(filepath)
    filepath.to_s.wont_equal gat_filepath
    files_should_have_same_content filepath, gat_filepath
  end

  def gat_write_file(filepath, content)
    gat_filepath = gat_edit_filepath(filepath)
    gat_filepath.open('w') do |f|
      f.write(content)
    end
    gat_filepath
  end

  def gat_write_change0_file(filepath = nil)
    gat_write_file(filepath, change0_test1_text)
  end

  def gat_write_change0_test1
    gat_write_file(filepath1, change0_test1_text)
  end

  def gat_write_change1_file(filepath = nil)
    gat_write_file(filepath, change1_test1_text)
  end

  def gat_write_change1_test1
    gat_write_file(filepath1, change1_test1_text)
  end

  def gat_current_checkpoint
    gat = gat_open
    gat.current_branch.current_checkpoint
  end

  def gat_conflict?
    gat_current_checkpoint.conflict?
  end

  def git_has_change?
    git.local_change?
  end

  def git_commit_change0_test1
    apply_change0_test1
    git.commit_all('Change0 to test1')
  end

  def git_commit_change1_test1
    apply_change1_test1
    git.commit_all('Change1 to test1')
  end

  def checkpoint_must_track_head
    gat = gat_open
    tracking = gat.current_branch.current_checkpoint.tracking
    tracking.must_equal git.head_sha
  end

  def check_should_err1(err, message = nil)
    should_err1(err) { gat_check(message) }
  end

  def change0_test1_text
    heredoc <<-EOS
      |This is a simple test
      |This is an added line for testing
    EOS
  end

  def apply_change0_test1
    file 'test1.txt', change0_test1_text
  end

  def change1_test1_text
    heredoc <<-EOS
      |This is a whole different test
      |This will definitely conflict
    EOS
  end

  def apply_change1_test1
    file 'test1.txt', change1_test1_text
  end

  def filepath1
    root + 'test1.txt'
  end

  def filepath2
    root + 'test2.txt'
  end

  def subpath1
    root + 'sub'
  end

  def subfilepath1
    subpath1 + 'subtest1.txt'
  end

  def subfilepath2
    subpath1 + 'subtest2.txt'
  end
end

class TestGatInit < TestGatSpec
  before do
    setup_git
  end

  after do
    cleanup
  end

  describe 'Gat repository' do
    it 'cannot be created outside of Git repository' do
      Dir.mktmpdir('test_gat') do |dir|
        absolute = Pathname(dir).expand_path
        should_err1 "Error: '#{absolute}' is not a git repository" do
          Gat::Gat.init(dir)
        end
      end
    end

    it 'can only be created inside a Git repostiory' do
      should_out1("Initialized Gat data in #{gat_dir}") { gat_init }
    end

    it 'cannot be reinitialized' do
      silent { gat_init }
      should_out1("Gat is already initialized in #{gat_dir}") { gat_init }
    end
  end
end

class TestGatCommands < TestGatSpec
  before do
    setup_repo
  end

  after do
    cleanup
  end

  describe 'Gat edit' do
    it 'copies file from Git to Gat' do
      all_test_files.each do |filepath|
        # then
        gat_edit_file_should_have_same_content_as_git filepath
      end
    end

    it 'uses same filepath for the same file' do
      gat_filepath0 = gat_edit_filepath(filepath1)
      gat_filepath1 = gat_edit_filepath(filepath1)
      # then
      gat_filepath0.must_equal gat_filepath1
    end

    it 'copies file from previous checkpoint if available' do
      silent { gat_check }
      gat_write_change0_test1
      gat_check('First check with changes')
      # and
      gat_filepath2 = gat_write_change0_file(filepath2)
      gat_check('Second check with changes')
      gat_filepath2_1 = gat_edit_filepath(filepath2)
      # then
      files_should_have_same_content gat_filepath2_1, gat_filepath2
    end

    it 'copies all files if editing a directory' do
      silent { gat_check }
      gat_write_change1_test1
      silent { gat_check('Change 1') }
      # when
      gat_dirpath1 = gat_edit_filepath(subpath1)
      # then
      files_should_have_same_content subfilepath1, gat_dirpath1 + 'subtest1.txt'
      files_should_have_same_content subfilepath2, gat_dirpath1 + 'subtest2.txt'
      # when
      gat_write_file(subfilepath1, change0_test1_text)
      silent { gat_check('Change subdir') }
      gat_dirpath2 = gat_edit_filepath(subpath1)
      # then
      gat_sub1filepath1 = gat_dirpath1 + 'subtest1.txt'
      gat_sub2filepath1 = gat_dirpath2 + 'subtest1.txt'
      files_should_have_same_content gat_sub1filepath1, gat_sub2filepath1
    end

    it 'should not allow editing files within Gat repo' do
      silent { gat_check }
      gat_filepath0 = gat_edit_filepath(filepath1)
      should_err1 "Error: file is not tracked by Git #{gat_filepath0}" do
        gat_edit(gat_filepath0.expand_path)
      end
    end
  end

  describe 'Gat check' do
    it 'does nothing when checkpoint is empty and update-to-date' do
      err = 'No changes to check with, already up-to-date.'
      # then
      check_should_err1 err
      checkpoint_must_track_head
      # when
      gat_edit_filepath(filepath1)
      # then
      check_should_err1 err, 'Should not be comitted due to no change'
    end

    it 'can be forced to have empty checkpoint to check changes in HEAD' do
      should_have_no_output { gat_force_check }
      gat = gat_open
      # then
      gat.current_branch.queue_size.must_equal 2
    end

    it 'updates to HEAD when checkpoint is empty but not up-to-date' do
      silent { gat_check }
      # when
      git_commit_change0_test1
      # then
      err = 'No changes to check with, updating to HEAD.'
      check_should_err1 err
      checkpoint_must_track_head
      # when
      git_commit_change1_test1
      gat_edit_filepath(filepath1)
      # then
      check_should_err1 err, 'Should not be comitted due to no change'
    end

    it 'does not allow checking with local changes in Git' do
      silent { gat_check }
      gat_write_change1_test1
      # when
      apply_change0_test1
      # then
      err = 'Error: cannot integrate checkpoint with local changes in git.'
      check_should_err1 err
    end

    it 'commits checkpoint changes to Git for testing' do
      silent { gat_check }
      # when
      gat_filepath = gat_write_change0_test1
      gat_check('Check with changes')
      # then
      files_should_have_same_content filepath1, gat_filepath
      git_has_change?.must_equal false
    end

    it 'can conflict with changes in Git' do
      silent { gat_check }
      gat_write_change1_test1
      git_commit_change0_test1
      # and
      gat_conflict?.must_equal false
      git.conflict?.must_equal false
      # when
      silent { gat_check('Check will conflict') }
      # then
      gat_conflict?.must_equal true
      git.conflict?.must_equal true
    end
  end

  describe 'Gat resolve' do
    it 'no-ops when there is no conflict' do
      silent { gat_check }
      gat_conflict?.must_equal false
      # then
      should_err1 'No conflict to resolve' do
        gat_resolve
      end
    end

    it 'commits conflicted changes once resolved' do
      silent { gat_check }
      gat_write_change1_test1
      git_commit_change0_test1
      # and
      silent { gat_check('Check will conflict') }
      gat_conflict?.must_equal true
      git.conflict?.must_equal true
      # but
      should_err1 'Error: cannot resolve with git conflicts.' do
        gat_resolve
      end
      # when
      apply_change1_test1
      git.conflict?.must_equal false
      gat_conflict?.must_equal true
      # then
      gat_resolve
      gat_conflict?.must_equal false
    end
  end

  describe 'Gat next' do
    it 'marks current checkpoint as success and proceeds to next' do
      silent { gat_check }
      initial = gat_current_checkpoint
      initial.exist?.must_equal true
      gat_filepath1_0 = gat_write_change0_test1
      # when
      silent { gat_check('Check change 0') }
      # then
      initial.committed?.must_equal true
      # given
      gat_filepath1_1 = gat_write_change1_test1
      silent { gat_check('Check change 1') }
      # and
      files_should_have_same_content filepath1, gat_filepath1_0
      files_wont_have_same_content filepath1, gat_filepath1_1
      gat_write_file(filepath1, 'Changes will not be checked')
      # when
      should_have_no_output { gat_next }
      # then
      initial.exist?.must_equal false
      files_should_have_same_content filepath1, gat_filepath1_1
      # when
      should_have_no_output { gat_next }
      # then
      gat_current_checkpoint.checking?.must_equal false
    end
  end
end
