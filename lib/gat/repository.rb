# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Repository

require 'rubygems'
require 'bundler/setup'

require 'gat/path'

module Gat
  class Repository
    attr_reader :root, :path

    def initialize(root_filepath)
      @root = Pathname(root_filepath)
      @path = @root + '.gat'
    end

    def setup
      exists = path.directory?
      if exists
        puts "Gat is already initialized in #{path}"
      else
        setup_dirs
        puts "Initialized Gat data in #{path}"
      end
      !exists
    end

    def setup_dirs
      Path.mkfilepaths(path, {
        branches_subdir => {}
      })
    end

    def branches_subdir
      'branches'
    end

    def checkpoints_subdir
      'checkpoints'
    end

    def settings
      Settings.new(@path, '', '')
    end

    def branch_settings(name)
      Settings.new(@path, branches_subdir, name)
    end

    def checkpoint_settings(branch_name, id)
      subdir = "#{branches_subdir}/#{branch_name}/#{checkpoints_subdir}"
      Settings.new(@path, subdir, id)
    end
  end
end
