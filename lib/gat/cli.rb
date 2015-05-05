# vim: set sw=2 ts=2 sts=2:

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
      Gat.edit(filepath)
    end

    desc 'check', 'Checkpoint current changes'
    option :message, :aliases => :m
    option :force, :type => :boolean, :aliases => :f
    def check
      Gat.check('.', options[:force], options[:message])
    end

    desc 'resolve', 'Checkpoint once Git conflicts are resolved'
    def resolve
      Gat.resolve('.')
    end

    desc 'next', 'Mark first checkpoint as success and proceed to next'
    def next
      Gat.next('.')
    end

    desc 'list', 'List current checkpoint'
    def list
      Gat.list('.')
    end

    desc 'branch [NAME]', 'Display or set current gat branch to NAME'
    option :clear, :type => :boolean, :aliases => :c
    def branch(name = nil)
      if !options[:clear] && name.nil?
        puts(Gat.current_branch_name('.'))
      else
        Gat.branch('.', name)
      end
    end
  end
end
