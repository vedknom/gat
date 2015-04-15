# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Path

require 'rubygems'
require 'bundler/setup'
require 'pathname'
require 'fileutils'

module Gat
  class Path
    attr_reader :name

    def self.from(filepath)
      filepath.kind_of?(self) ? filepath : new(filepath)
    end

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

    def self.mkfilepaths(prefix, spec)
      pathname = Pathname(prefix)
      pathname.mkdir unless pathname.directory?
      spec.each do |k, v|
        current = pathname + k
        if v.nil?
          FileUtils.touch(current)
        elsif v.kind_of?(Hash)
          mkfilepaths(current, v)
        else
          raise ArgumentError, "Invalid value #{v} type #{v.class}"
        end
      end
    end

    def self.rsync(source_filepath, target_filepath, mkdir = false)
      target = Pathname(target_filepath)
      source = Pathname(source_filepath)
      target += source.basename if mkdir
      Pathname.glob(source + '**/*') do |f|
        unless f.directory?
          relative = f.relative_path_from(source)
          FileUtils.cp(f, target + relative)
        end
      end
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
      @git_root = ascend_find { |p| p.git_root? } unless defined?(@git_root)
      @git_root
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

    def gat_file(filepath)
      gat_repo + filepath
    end

    def gat_branches_subdir
      'branches'
    end

    def gat_branches_dir
      gat_file(gat_branches_subdir)
    end

    def gat_mkdirs
      Path.mkfilepaths(gat_repo, {
        gat_branches_subdir => {}
      })
    end
  end
end
