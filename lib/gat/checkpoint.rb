# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Gat::Checkpoint

require 'rubygems'
require 'bundler/setup'
require 'securerandom'

module Gat
  class Checkpoint
    attr_reader :id, :tracking

    def initialize(commitish, id = SecureRandom.uuid)
      @tracking = commitish
      @id = id
    end

    def to_s
      id
    end

    def add_to(branch)
      dir = branch.checkpoints_dir + id
      if dir.directory?
        warn "Error: checkpoint already exists #{checkpoint}"
      else
        dir.mkdir
        (dir + 'tracking').open('w') do |f|
          f.puts(tracking)
        end
      end
    end
  end
end
