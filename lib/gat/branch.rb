# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Branch

require 'rubygems'
require 'bundler/setup'

require 'gat/path'
require 'gat/checkpoint'

module Gat
  class Branch
    attr_reader :name

    def initialize(root_filepath, name)
      @root = Path.from(root_filepath)
      @name = name
    end

    def setup
      Path.mkfilepaths(branch_dir, {
        checkpoints_subdir => {}
      })
    end

    def branch_dir
      @root.gat_branches_dir + @name
    end

    def branch_file(filepath)
      branch_dir + filepath
    end

    def checkpoints_subdir
      'checkpoints'
    end

    def checkpoints_dir
      branch_dir + checkpoints_subdir
    end

    def checkpoint(git)
      branch_sha = git.revparse(name)
      checkpoint = Checkpoint.new(checkpoints_dir, branch_sha)
      add_checkpoint(checkpoint)
    end

    def add_checkpoint(checkpoint)
      unless checkpoint.nil?
        checkpoint.add_to(self)
        branch_file('queue').open('a') do |f|
          f.puts(checkpoint.id)
        end
        branch_file('current').open('w') do |f|
          f.puts(checkpoint.id)
        end
      end
    end

    def current_checkpoint_id
      branch_file('current').open('r').readline.chomp
    end

    def current_checkpoint
      Checkpoint.from(checkpoints_dir, current_checkpoint_id)
    end

    def current_checkpoint_files_dir
      Checkpoint.files_dir(checkpoints_dir, current_checkpoint_id)
    end
  end
end
