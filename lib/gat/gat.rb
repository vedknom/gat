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
      @git = Git.open(@root) unless defined?(@git)
      @git
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

    def write_default_message(default_message)
      message_file = @root.gat_file('CHECK_MSG')
      message_file.open('w') do |f|
        f.puts(default_message)
      end
      message_file
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

    def check(message)
      branch = current_branch
      checkpoint = branch.current_checkpoint
      if !checkpoint.change?
        warn "No changes to check with, updating to HEAD."
        checkpoint.remove
        branch.checkpoint(git)
      else
        message ||= message_with_default(branch.default_message_for(checkpoint))
        if message.nil? || message.empty?
          warn "Not checking due to empty check message."
        else
          branch.check(git, message)
        end
      end
    end
  end
end
