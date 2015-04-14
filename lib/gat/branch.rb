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

    def to_s
      name
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
        checkpoint.add
        branch_file('queue').open('a') do |f|
          f.puts(checkpoint.id)
        end
        branch_file('current').open('w') do |f|
          f.puts(checkpoint.id)
        end
      end
    end

    def checkpoint_for(id)
      Checkpoint.from(checkpoints_dir, id)
    end

    def first_checkpoint_id
      branch_file('queue').open('r').readline.chomp
    end

    def first_checkpoint
      checkpoint_for(first_checkpoint_id)
    end

    def current_checkpoint_id
      branch_file('current').open('r').readline.chomp
    end

    def current_checkpoint
      checkpoint_for(current_checkpoint_id)
    end

    def current_checkpoint_files_dir
      Checkpoint.files_dir(checkpoints_dir, current_checkpoint_id)
    end

    def queue_size
      branch_file('queue').open('r').readlines.size
    end

    def default_message_for(checkpoint)
      default_header = [
        "",
        "# Please enter the check message for your changes.",
        "# On branch #{self} (checkpoint #{checkpoint})",
        "# Files to be copied:"
      ]
      checkpoint.relative_glob do |p|
        default_header << "#\t#{p}"
      end
      default_header.join("\n")
    end

    def check(git, message)
      first = queue_size == 1
      current = current_checkpoint
      checking = current.check(message)
      if checking && first
        current.commit(git)
      end
      checkpoint(git)
    end
  end
end
