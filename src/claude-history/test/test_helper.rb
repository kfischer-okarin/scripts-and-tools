# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "../lib/claude_history"

module ClaudeHistory
  class TestCase < Minitest::Test
    def before_setup
      super
      @temp_dirs = []
    end

    def after_teardown
      @temp_dirs.each { |dir| FileUtils.rm_rf(dir) }
      super
    end

    def projects_fixture_path
      File.expand_path("fixtures/claude-projects", __dir__)
    end

    def fixture_project_id
      "-Users-user-project"
    end

    def fixture_main_session_id
      "b3edadab-bca0-4054-9b41-f7ffa6941260"
    end

    def fixture_summary_session_id
      "be89c3cd-bfbf-4c4f-a515-5af6e13249bf"
    end

    def build_project(files)
      dir = Dir.mktmpdir
      @temp_dirs << dir

      base_time = Time.now - files.size
      files.each_with_index do |(filename, content), index|
        path = File.join(dir, filename)
        mtime = base_time + index
        File.write(path, content)
        File.utime(mtime, mtime, path)
      end

      dir
    end
  end
end
