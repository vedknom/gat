# vim: set sw=2 ts=2 sts=2:

# Gat::Checkpoint

require 'rubygems'
require 'bundler/setup'
require 'securerandom'

require 'gat/path'
require 'gat/git'

module Gat
  class Checkpoint
    attr_reader :repository

    TRACKING_KEY = 'tracking'
    FILES_KEY = 'files'
    CHECKING_KEY = 'checking'
    COMMIT_KEY = 'commit_sha'
    CONFLICT_KEY = 'conflict'

    def initialize(branch, id = SecureRandom.uuid)
      @repository = branch.repository
      @branch_name = branch.name
      @settings = repository.checkpoint_settings(branch.name, id)
    end

    def to_s
      id
    end

    def id
      @settings.name
    end

    def tracking
      @settings[TRACKING_KEY]
    end

    def tracking=(sha)
      @settings[TRACKING_KEY] = sha
    end

    def files_dir
      @settings.files_dir(FILES_KEY)
    end

    def relative_glob(pattern, &block)
      @settings.files_glob(FILES_KEY, pattern, &block)
    end

    def add
      unless @settings.setup
        warn "Error: checkpoint already exists #{self}"
      end
    end

    def change?
      !@settings.files_empty?(FILES_KEY)
    end

    def checking?
      @settings.include?(CHECKING_KEY)
    end

    def check(message)
      already_checking = checking?
      if already_checking
        warn "Error: checkpoint '#{self}' is already checking"
      else
        @settings[CHECKING_KEY] = message
      end
      !already_checking
    end

    def conflict?
      @settings.bool_value(CONFLICT_KEY)
    end

    def conflict=(boolean)
      @settings[CONFLICT_KEY] = boolean
    end

    def committed?
      @settings.include?(COMMIT_KEY)
    end

    def commit_sha
      @settings[COMMIT_KEY]
    end

    def commit_sha=(sha)
      @settings[COMMIT_KEY] = sha
    end

    def copy_files_to(filepath)
      Path.rsync(files_dir, filepath)
    end

    def commit_changes(git)
      message = @settings[CHECKING_KEY]
      git.commit_all(message)
    end

    def detached_commit(git)
      git.switch_branch(tracking) do
        copy_files_to(git.dir.path)
        commit_changes(git)
        git.head_sha
      end
    end

    def cherrypick(sha, git)
      git.cherrypick([sha])
    end

    def warn_conflict
      warn "Error: checkpoint is in conflict, use 'gat resolve' when resolved"
    end

    def git_error(e)
      warn "Error from git: #{e}"
    end

    def integrate_commit(detached_sha, git)
      begin
        self.tracking = git.head_sha
        cherrypick(detached_sha, git)
        self.commit_sha = git.head_sha
      rescue Git::GitExecuteError => e
        self.conflict = true
        git_error(e)
        warn_conflict
      end
    end

    def commit(git)
      if conflict?
        warn_conflict
      elsif committed?
        warn "Error: checkpoint '#{self}' has already been committed"
      elsif !checking?
        warn "Error: cannot commit without checking first"
      else
        integrate_commit(detached_commit(git), git)
      end
    end

    def resolve(git)
      if !conflict?
        warn 'No conflict to resolve'
      elsif git.conflict?
        warn 'Error: cannot resolve with git conflicts.'
      else
        begin
          git.commit(['--no-edit'])
          self.conflict = false
        rescue Git::GitExecuteError => e
          git_error(e)
          warn 'Error: failed to resolve changes'
        end
      end
    end

    def remove
      @settings.remove
    end
  end
end
