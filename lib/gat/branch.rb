# vim: set sw=2 ts=2 sts=2:

# Gat::Branch

require 'rubygems'
require 'bundler/setup'

require 'gat/path'
require 'gat/checkpoint'

module Gat
  class Branch
    attr_reader :repository

    QUEUE_KEY = 'queue'
    CURRENT_KEY = 'current'
    HISTORY_KEY = 'history'

    def initialize(repository, name)
      @repository = repository
      @settings = repository.branch_settings(name)
      @settings.setup
    end

    def setup?
      @settings.include?(CURRENT_KEY)
    end

    def to_s
      name
    end

    def name
      @settings.name
    end

    def checkpoint(git)
      branch_sha = git.revparse(name)
      checkpoint = Checkpoint.new(self)
      add_checkpoint(checkpoint)
      checkpoint.tracking = branch_sha
    end

    def add_checkpoint(checkpoint)
      unless checkpoint.nil?
        previous = current_checkpoint
        checkpoint.add
        @settings.list_add(QUEUE_KEY, checkpoint.id)
        self.current_checkpoint_id = checkpoint.id
        previous.copy_files_to(checkpoint.files_dir) unless previous.nil?
      end
    end

    def remove_checkpoint(checkpoint)
      unless checkpoint.nil?
        checkpoint.remove
        id = @settings.list_shift(QUEUE_KEY)
        @settings.list_add(HISTORY_KEY, id)
        unless id == checkpoint.id
          puts "id: #{id.length} checkpoint: #{checkpoint.id.length}"
          raise "Commit non-first checkpoint #{checkpoint} expects #{id}"
        end
        @settings.delete(CURRENT_KEY) if queue_size == 0
      end
    end

    def checkpoint_for(id)
      Checkpoint.new(self, id) unless id.nil?
    end

    def first_checkpoint_id
      @settings.list_first(QUEUE_KEY)
    end

    def first_checkpoint
      checkpoint_for(first_checkpoint_id)
    end

    def current_checkpoint_id
      @settings[CURRENT_KEY]
    end

    def current_checkpoint_id=(id)
      @settings[CURRENT_KEY] = id
    end

    def current_checkpoint
      checkpoint_for(current_checkpoint_id)
    end

    def queue
      @settings.list_values(QUEUE_KEY)
    end

    def queue_size
      @settings.list_size(QUEUE_KEY)
    end

    def default_message_for(checkpoint)
      default_header = [
        "",
        "# Please enter the check message for your changes.",
        "# On branch #{self} (checkpoint #{checkpoint})",
        "# Files to be copied:"
      ]
      checkpoint.relative_glob('**/*') do |p|
        default_header << "#\t#{p}"
      end
      default_header.join("\n")
    end

    def check(current, message, git)
      first = queue_size == 1
      checking = current.check(message)
      if checking && first
        sha = commit(current, git)
        failed = sha.nil?
      end
      checkpoint(git) unless failed
    end

    def check_nochange(current, git)
      current.check('Pseudo checkpoint with no changes')
      checkpoint(git)
    end

    def subsequents(checkpoint)
      ids = queue
      index = ids.find_index { |id| id == checkpoint.id }
      if index.nil?
        warn "Error: checkpoint '#{checkpoint}' not found in queue: " +
          "#{ids.join(' ')}"
        []
      else
        ids[(index + 1)..-1]
      end
    end

    def adjust_subsequent(checkpoint, commit_sha)
      subsequents(checkpoint).each do |id|
        adjust = checkpoint_for(id)
        if adjust.tracking == checkpoint.tracking
          adjust.tracking = commit_sha
        end
      end
    end

    def commit(checkpoint, git)
      commit_sha = checkpoint.commit(git)
      adjust_subsequent(checkpoint, commit_sha) unless commit_sha.nil?
      commit_sha
    end

    def check_next(git)
      checkpoint = first_checkpoint
      unless checkpoint.nil?
        if !checkpoint.committed?
          warn "Error: checkpoint is not committed yet #{checkpoint}"
        else
          remove_checkpoint(checkpoint)
        end
      end
      current_first = first_checkpoint
      commit(current_first, git) unless current_first.nil?
    end
  end
end
