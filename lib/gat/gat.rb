# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Gat

require 'rubygems'
require 'bundler/setup'
require 'git'

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

    def add_current_branch
      branch_name = git.current_branch
      branch = Branch.new(@root, branch_name)
      branch.setup
      branch_sha = git.revparse(branch_name)
      checkpoint = Checkpoint.new(branch_sha)
      branch.add_checkpoint(checkpoint)
    end
  end
end

