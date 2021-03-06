# vim: set sw=2 ts=2 sts=2:

# Gat::Gat

require 'rubygems'
require 'bundler/setup'
require 'git'
require 'fileutils'

require 'gat/path'
require 'gat/settings'
require 'gat/branch'
require 'gat/checkpoint'
require 'gat/repository'

module Gat
  class Gat
    CHECK_MESSAGE_FILENAME = 'CHECK_MSG'
    CURRENT_BRANCH_KEY = 'current_branch'

    def self.init(filepath)
      path = Path.git_root(filepath)
      unless path.nil?
        repo = Repository.new(path)
        repo.setup
      end
    end

    def self.edit(filepath)
      gat = open(filepath)
      gat.edit(filepath)
    end

    def self.check(filepath, force = false, message = nil)
      gat = Gat.open(filepath)
      gat.check(force, message)
    end

    def self.resolve(filepath)
      gat = Gat.open(filepath)
      gat.resolve
    end

    def self.next(filepath)
      gat = Gat.open(filepath)
      gat.next
    end

    def self.list(filepath)
      gat = Gat.open(filepath)
      gat.list
    end

    def self.branch(filepath, name)
      gat = Gat.open(filepath)
      gat.branch(name)
    end

    def self.current_branch_name(filepath)
      gat = Gat.open(filepath)
      gat.current_branch_name
    end

    def self.open(filepath)
      path = Path.git_root(filepath)
      repo = Repository.new(path)
      new(repo)
    end

    def initialize(repository)
      @repository = repository
      @settings = repository.settings
      setup
    end

    def setup
      branch = current_branch
      unless branch.setup?
        branch.checkpoint(git)
      end
    end

    def root
      @repository.root
    end

    def git
      @git = Git.open(root) unless defined?(@git)
      @git
    end

    def current_branch
      Branch.new(@repository, current_branch_name)
    end

    def current_branch_name
      if @settings.include?(CURRENT_BRANCH_KEY)
        @settings[CURRENT_BRANCH_KEY]
      else
        git.current_branch
      end
    end

    def edit(filepath)
      pathname = Pathname(filepath).expand_path
      if !git.track_file?(pathname)
        warn "Error: file is not tracked by Git #{pathname}"
      else
        edit_file(pathname)
      end
    end

    def edit_file(pathname)
      relative = pathname.relative_path_from(root)
      branch = current_branch
      checkpoint = branch.current_checkpoint
      target_path = checkpoint.files_dir + relative
      unless target_path.exist?
        if pathname.directory?
          FileUtils.mkdir_p(target_path)
          Pathname.glob(pathname + '**/*') do |f|
            relative_file = f.relative_path_from(root)
            target_file = checkpoint.files_dir + relative_file
            target_file.open('w') do |f|
              content = git.show(checkpoint.tracking, relative_file)
              f.print(content)
            end
          end
        else
          FileUtils.mkdir_p(target_path.dirname)
          target_path.open('w') do |f|
            content = git.show(checkpoint.tracking, relative)
            f.print(content)
          end
        end
      end
      puts(target_path)
    end

    def write_default_message(default_message)
      @settings[CHECK_MESSAGE_FILENAME] = default_message
      @settings.file_for(CHECK_MESSAGE_FILENAME)
    end

    def message_with_default(default_message)
      message = nil
      message_file = write_default_message(default_message)
      editor = ENV['EDITOR'] || 'vim'
      success = system("#{editor} \"#{message_file}\"")
      if !success
        warn "Error: editor #{editor} quit with status #{$?}"
      elsif message_file.exist?
        lines = message_file.open('r') do |f|
          f.readlines.reject do |line|
            line.match(/^\s*#/) || line.match(/^\s*$/)
          end
        end
        message = lines.join
      end
      FileUtils.rm(message_file, :force => true)
      message
    end

    def check_nochange(branch, checkpoint, force)
      update_to_date = checkpoint.tracking == git.head_sha
      checkpoint.tracking = git.head_sha unless update_to_date
      if force
        branch.check_nochange(checkpoint, git)
      elsif update_to_date
        warn 'No changes to check with, already up-to-date.'
      else
        warn 'No changes to check with, updating to HEAD.'
      end
    end

    def check_branch(branch, checkpoint, message)
      message ||= message_with_default(branch.default_message_for(checkpoint))
      if message.nil? || message.empty?
        warn 'Not checking due to empty check message.'
      else
        branch.check(checkpoint, message, git)
      end
    end

    def check_local_change(branch, checkpoint)
      warn 'Error: cannot integrate checkpoint with local changes in git.'
    end

    def check(force, message)
      branch = current_branch
      checkpoint = branch.current_checkpoint
      if !checkpoint.change?(git)
        check_nochange(branch, checkpoint, force)
      elsif git.local_change?
        check_local_change(branch, checkpoint)
      else
        check_branch(branch, checkpoint, message)
      end
    end

    def resolve
      branch = current_branch
      checkpoint = branch.current_checkpoint
      checkpoint.resolve(git) unless checkpoint.nil?
    end

    def next
      branch = current_branch
      branch.check_next(git)
    end

    def list
      branch = current_branch
      puts(branch.queue)
    end

    def ensure_git_branch(name)
      begin
        git.revparse(name)
      rescue Git::GitExecuteError => e
        git.branch(name)
      end
    end

    def branch(name)
      if name.nil?
        @settings.delete(CURRENT_BRANCH_KEY)
      else
        ensure_git_branch(name)
        @settings[CURRENT_BRANCH_KEY] = name
      end
    end
  end
end
