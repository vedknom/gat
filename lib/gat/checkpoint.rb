# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Checkpoint

require 'rubygems'
require 'bundler/setup'
require 'securerandom'

require 'gat/path'

module Gat
  class Checkpoint
    attr_reader :id, :tracking

    def self.from(dirpath, id)
      dir = dirpath + id
      tracking = (dir + 'tracking').open('r').readline.chomp
      new(dirpath, tracking, id)
    end

    def initialize(dirpath, commitish, id = SecureRandom.uuid)
      @dirpath = dirpath
      @tracking = commitish
      @id = id
    end

    def to_s
      id
    end

    def checkpoint_dir
      @dirpath + id
    end

    def checkpoint_file(filepath)
      checkpoint_dir + filepath
    end

    def files_dir
      checkpoint_file('files')
    end

    def relative_glob
      result = block_given? ? nil : []
      dir = files_dir
      Pathname.glob(dir + '**/*') do |p|
        relative = p.relative_path_from(dir)
        if block_given?
          yield relative
        else
          result << relative
        end
      end
      result
    end

    def add
      dirpath = checkpoint_dir
      if dirpath.directory?
        warn "Error: checkpoint already exists #{checkpoint}"
      else
        dirpath.mkdir
        checkpoint_file('tracking').open('w') do |f|
          f.puts(tracking)
        end
      end
    end

    def change?
      change = false
      Pathname.glob(files_dir + '**/*') do |p|
        change = true
        break
      end
      change
    end

    def checking?
      checkpoint_file('checking').exist?
    end

    def check(message)
      already_checking = checking?
      if already_checking
        warn "Error: checkpoint '#{self}' is already checking"
      else
        checkpoint_file('checking').open('w') { |f| f.write(message) }
      end
      !already_checking
    end

    def commit(git)
      already_committed = checkpoint_file('commit').exist?
      if already_committed
        warn "Error: checkpoint '#{self}' has already been committed"
      else
        Path.rsync(files_dir, git.dir.path)
        message = checkpoint_file('checking').open('r') { |f| f.read }
        git.commit_all(message)
        commit_sha = git.revparse('HEAD')
        checkpoint_file('commit').open('w') { |f| f.puts(commit_sha) }
      end
    end

    def remove
      FileUtils.rm_r(checkpoint_dir)
    end
  end
end
