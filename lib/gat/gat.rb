# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Gat

require 'rubygems'
require 'bundler/setup'
require 'git'
require 'fileutils'

require 'gat/path'
require 'gat/branch'
require 'gat/checkpoint'

module Gat
  class Gat
    def self.setup(path)
      gat_repo = path.gat_repo
      exists = gat_repo.directory?
      if exists
        puts "Gat is already initialized in #{gat_repo}"
      else
        path.gat_mkdirs
        puts "Initialized Gat data in #{gat_repo}"
      end
      !exists
    end

    def self.init(filepath)
      path = Path.from_git(filepath)
      unless path.nil?
        root = path.git_root
        if setup(root)
          gat = open(root)
          gat.add_current_branch
        end
      end
    end

    def self.edit(filepath)
      gat = open(filepath)
      gat.edit(filepath)
    end

    def self.open(filepath)
      path = Path.git_root(filepath)
      new(path)
    end

    def initialize(root_filepath)
      @root = Path.from(root_filepath)
    end

    def git
      @git ||= Git.open(@root)
    end

    def current_branch
      Branch.new(@root, git.current_branch)
    end

    def add_current_branch
      branch = current_branch
      branch.setup
      branch.checkpoint(git)
    end

    def edit(filepath)
      pathname = Pathname(filepath).expand_path
      relative = pathname.relative_path_from(@root.name)
      branch = current_branch
      checkpoint = branch.current_checkpoint
      target_path = checkpoint.files_dir + relative
      unless target_path.exist?
        FileUtils.mkdir_p(target_path.dirname)
        target_path.open('w') do |f|
          content = git.show(checkpoint.tracking, relative)
          f.print(content)
        end
      end
      puts(target_path)
    end

    def check
      current_branch.checkpoint(git)
    end
  end
end

