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

    def self.check(filepath, message = nil)
      gat = Gat.open(filepath)
      gat.check(message)
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
      Branch.new(@repository, git.current_branch)
    end

    def edit(filepath)
      pathname = Pathname(filepath).expand_path
      relative = pathname.relative_path_from(root)
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

    def check_nochange(branch, checkpoint)
      if checkpoint.tracking == git.head_sha
        warn 'No changes to check with, already up-to-date.'
      else
        warn 'No changes to check with, updating to HEAD.'
        branch.remove_checkpoint(checkpoint)
        branch.checkpoint(git)
      end
    end

    def check_branch(branch, checkpoint, message)
      message ||= message_with_default(branch.default_message_for(checkpoint))
      if message.nil? || message.empty?
        warn 'Not checking due to empty check message.'
      else
        branch.check(git, message)
      end
    end

    def check_local_change(branch, checkpoint)
      warn 'Error: cannot integrate checkpoint with local changes in git.'
    end
    
    def check(message)
      branch = current_branch
      checkpoint = branch.current_checkpoint
      if !checkpoint.change?
        check_nochange(branch, checkpoint)
      elsif git.local_change?
        check_local_change(branch, checkpoint)
      else
        check_branch(branch, checkpoint, message)
      end
    end
  end
end
