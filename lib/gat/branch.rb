# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Branch

require 'rubygems'
require 'bundler/setup'
require 'fileutils'

module Gat
  class Branch
    def initialize(root_filepath, name)
      @root = root_filepath
      @name = name
    end

    def setup
      branch_dir.mkdir unless branch_dir.directory?
      FileUtils.touch(branch_dir + 'queue')
      FileUtils.touch(branch_dir + 'current')
    end

    def branch_dir
      @root.gat_branches_dir + @name
    end
  end
end
