# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::CLI

require 'rubygems'
require 'bundler/setup'
require 'thor'
require 'gat/gat'

module Gat
  class CLI < Thor
    desc 'init', 'Initialize Gat in a Git repository'
    def init
      Gat.init('.')
    end

    desc 'edit FILE', 'Edit FILE inside current checkpoint'
    def edit(filepath)
      gat = Gat.open(filepath)
      gat.edit(filepath)
    end
  end
end
