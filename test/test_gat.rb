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

class TestGatSpec < MiniTest::Spec
  attr_reader :git

  def root
    @root = Pathname(Dir.mktmpdir('test_gat')) unless defined?(@root)
    @root
  end

  def gat_dir
    root.expand_path + '.gat'
  end

  def file(name, content)
    pathname = root + name
    FileUtils.mkdir_p(pathname.dirname)
    pathname.open('w') do |f|
      f.write(content)
    end
    git.add(pathname.to_path)
  end

  def text_file(name, content)
    file(name, content.gsub(/^\s+\|/, ''))
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
  end

  def setup_repo
    setup_git
    add_files
  end

  def cleanup
    @git = nil
    @gat = nil
    FileUtils.remove_entry(root)
  end

  def should_output(out, err, &block)
    block.must_output out, err
  end

  def should_err(err, &block)
    block.must_output '', err, &block
  end

  def should_out(out, &block)
    should_output out, '', &block
  end
end

class TestGat < TestGatSpec
  before do
    setup_repo
  end

  after do
    cleanup
  end

  describe 'Gat repository' do
    it 'cannot be created outside of Git repository' do
      Dir.mktmpdir('test_gat') do |dir|
        absolute = Pathname(dir).expand_path
        should_err "Error: '#{absolute}' is not a git repository\n" do
          Gat::Gat.init(dir) 
        end
      end
    end

    it 'can only be created inside a Git repostiory' do
      should_out "Initialized Gat data in #{gat_dir}\n" do
        Gat::Gat.init(root)
      end
    end

    it 'cannot be reinitialized' do
      should_output nil, nil do
        Gat::Gat.init(root)
      end
      should_out "Gat is already initialized in #{gat_dir}\n" do
        Gat::Gat.init(root)
      end
    end
  end
end
