# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Path

require 'rubygems'
require 'bundler/setup'
require 'pathname'

module Gat
  class Path
    attr_reader :name

    def self.from_git(filepath)
      path = new(filepath)
      unless path.git?
        warn "Error: '#{path.absolute}' is not a git repository"
        path = nil
      end
      path
    end

    def self.git_root(filepath)
      from_git(filepath).git_root
    end

    def initialize(filepath)
      @name = Pathname(filepath)
    end

    def to_s
      absolute.to_s
    end

    def to_path
      @name.to_path
    end

    def subdirectory?(filepath)
      (@name + filepath).directory?
    end

    def ascend_find(&block)
      result = nil
      absolute.ascend do |p|
        path = self.class.new(p)
        result = path if block.call(path)
        break unless result.nil?
      end
      result
    end

    def absolute
      @name.expand_path
    end

    def git_subdir
      '.git'
    end

    def git_root?
      subdirectory?(git_subdir)
    end

    def git_root
      @git_root ||= ascend_find { |p| p.git_root? }
    end

    def git?
      !git_root.nil?
    end

    def gat_subdir
      '.gat'
    end

    def gat_repo
      git_root.name + gat_subdir
    end

    def gat_dir_for(filepath)
      gat_repo + filepath
    end

    def gat_branches_dir
      gat_dir_for('branches')
    end

    def gat_std_dirs_each
      yield gat_branches_dir
    end

    def gat_mkdirs
      gat_repo.mkdir
      gat_std_dirs_each { |pathname| pathname.mkdir }
    end
  end
end
