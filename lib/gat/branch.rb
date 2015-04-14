# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Branch

require 'rubygems'
require 'bundler/setup'

require 'gat/path'

module Gat
  class Branch
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
  end
end
