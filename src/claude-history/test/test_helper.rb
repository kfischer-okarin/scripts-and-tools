# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "securerandom"
require "tmpdir"
require_relative "../lib/claude_history"

# Run all tests in JST (UTC+9) for consistent timezone behavior
ENV["TZ"] = "Asia/Tokyo"

module ClaudeHistory
  class TestCase < Minitest::Test
    def before_setup
      super
      @projects_path = Dir.mktmpdir
    end

    def after_teardown
      FileUtils.rm_rf(@projects_path)
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

    def build_project(name_or_files = nil, files = {})
      # Handle both build_project({...}) and build_project("name", {...})
      if name_or_files.is_a?(Hash)
        files = name_or_files
        name = "project-#{SecureRandom.uuid}"
      else
        name = name_or_files || "project-#{SecureRandom.uuid}"
      end

      project_path = File.join(@projects_path, name)
      FileUtils.mkdir_p(project_path)

      base_time = Time.now - files.size
      files.each_with_index do |(filename, content), index|
        path = File.join(project_path, filename)
        mtime = base_time + index
        File.write(path, content)
        File.utime(mtime, mtime, path)
      end

      Project.new(project_path)
    end
  end
end
