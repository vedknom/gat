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

  def add_files
    file 'test1.txt', 'This is a simple test'
    file 'test2.txt', 'This is another test'
    file 'sub/subtest1.txt', 'This is a test in subdir'
    file 'sub/subtest2.txt', 'This is another test in subdir'
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

  def should_err1(err, &block)
    should_err(err + "\n", &block)
  end

  def should_err(err, &block)
    block.must_output '', err, &block
  end

  def should_out1(out, &block)
    should_out(out + "\n", &block)
  end

  def should_out(out, &block)
    should_output out, '', &block
  end

  def files_should_have_same_content(file0, file1)
    File.read(file0).must_equal File.read(file1)
  end

  def gat_init
    Gat::Gat.init(root)
  end

  def gat_edit(filepath)
    Gat::Gat.edit(filepath)
  end

  def gat_check(message = nil)
    Gat::Gat.check(root, message)
  end

  def gat_open
    Gat::Gat.open(root)
  end

  def gat_edit_filepath(filepath)
    out, err = capture_io { gat_edit(filepath) }
    err.must_be_empty
    Pathname(out.chomp)
  end

  def git_has_change?
    @git.local_change?
  end

  def git_commit_test1
    @git.commit_all('Changes to test1')
  end

  def checkpoint_must_track_head
    gat = gat_open
    tracking = gat.current_branch.current_checkpoint.tracking
    tracking.must_equal @git.head_sha
  end

  def check_should_err1(err)
    should_err1(err) { gat_check}
  end

  def change0_test1_text
    heredoc <<-EOS
      |This is a simple test
      |This is an added line for testing
    EOS
  end

  def change0_test1
    file 'test1.txt', change0_test1_text
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
      filepath = root + 'test1.txt'
      gat_filepath = gat_edit_filepath(filepath)
      filepath.to_s.wont_equal gat_filepath
      files_should_have_same_content filepath, gat_filepath
    end

    it 'uses same filepath for the same file' do
      filepath = root + 'test1.txt'
      gat_filepath0 = gat_edit_filepath(filepath)
      gat_filepath1 = gat_edit_filepath(filepath)
      gat_filepath0.must_equal gat_filepath1
    end
  end

  describe 'Gat check' do
    it 'does nothing when checkpoint is empty and update-to-date' do
      check_should_err1 'No changes to check with, already up-to-date.'
      checkpoint_must_track_head
    end

    it 'updates to HEAD when checkpoint is empty but not update-to-date' do
      silent { gat_check }
      change0_test1
      git_commit_test1
      check_should_err1 'No changes to check with, updating to HEAD.'
      checkpoint_must_track_head
    end

    it 'does not allow checking with local changes in Git' do
      silent do
        gat_check
        gat_edit(root + 'test1.txt')
      end
      change0_test1
      err = 'Error: cannot integrate checkpoint with local changes in git.'
      check_should_err1 err
    end

    it 'commits checkpoint changes to Git for testing' do
      silent { gat_check }
      filepath = root + 'test1.txt'
      gat_filepath = gat_edit_filepath(filepath)
      gat_filepath.open('w') do |f|
        f.write(change0_test1_text)
      end
      gat_check('Check with changes')
      files_should_have_same_content filepath, gat_filepath
      git_has_change?.must_equal false
    end
  end
end
