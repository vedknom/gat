# vim: set sw=2 ts=2 sts=2:

# Gat::Settings

require 'rubygems'
require 'bundler/setup'
require 'fileutils'

module Gat
  class Settings
    attr_reader :root, :relative, :name

    def initialize(root_filepath, subdir_filepath, name)
      @root = Pathname(root_filepath)
      @relative = Pathname(subdir_filepath) + name
      @name = name
    end

    def setup
      result = !exist?
      FileUtils.mkdir_p(absolute) if result
      result
    end

    def remove
      absolute.rmtree
    end

    def absolute
      @absolute = root + relative unless defined?(@absolute)
      @absolute
    end

    def exist?
      absolute.directory?
    end

    def file_for(key)
      absolute + key
    end

    def include?(key)
      file_for(key).exist?
    end

    def delete(key)
      f = file_for(key)
      f.rmtree if f.exist?
    end

    def [](key)
      read(key) if include?(key)
    end

    def []=(key, value)
      write(key, value)
    end

    def bool_value(key)
      self[key] == true.to_s
    end

    def list_add(key, value)
      open(key, 'a') do |f|
        f.puts(value)
      end
    end

    def list_shift(key)
      values = list_values(key)
      first = values.shift
      list_set_values(key, values)
      first
    end

    def list_first(key)
      open(key, 'r') do |f|
        f.readline.chomp
      end
    end

    def list_size(key)
      open(key, 'r') do |f|
        f.readlines.size
      end
    end

    def list_values(key)
      open(key, 'r') do |f|
        f.readlines.map(&:chomp)
      end
    end

    def list_set_values(key, values)
      write(key, values.join("\n"))
    end

    def files_dir(key)
      file_for(key)
    end

    def files_glob(key, pattern = '**/*')
      result = block_given? ? nil : []
      base_dir = files_dir(key)
      Pathname.glob(base_dir + pattern) do |p|
        relative = p.relative_path_from(base_dir)
        if block_given?
          yield relative
        else
          result << relative
        end
      end
      result
    end

    def files_empty?(key)
      files_glob(key) { |p| return false }
      return true
    end

    def open(key, mode, &block)
      file_for(key).open(mode, &block)
    end

    def read(key)
      open(key, 'r') do |f|
        f.read
      end
    end

    def write(key, value)
      open(key, 'w') do |f|
        f.write(value)
      end
    end
  end
end
