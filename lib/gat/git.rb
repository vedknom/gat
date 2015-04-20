# vim: set sw=2 ts=2 sts=2 fdm=indent fml=0:

# Git

require 'rubygems'
require 'bundler/setup'
require 'git'

module Git
  class Lib
    def run(cmd, arr_opts)
      command(cmd, arr_opts)
    end
  end

  class Base
    def head_sha
      revparse('HEAD')
    end

    def cherrypick(arr_opts)
      run('cherry-pick', arr_opts)
    end

    def local_change?
      !run('diff-index', ['HEAD', '--']).empty?
    end

    def conflict?
      !run('diff', ['--name-only', '--diff-filter=U']).empty?
    end

    def run(cmd, arr_opts)
      self.lib.run(cmd, arr_opts)
    end

    def switch_branch(branch_name, &block)
      result = nil
      restore = block.nil? ? nil : current_branch
      checkout(branch_name)
      unless block.nil?
        result = block.call()
        checkout(restore) unless restore.nil?
      end
      result
    end
  end
end
