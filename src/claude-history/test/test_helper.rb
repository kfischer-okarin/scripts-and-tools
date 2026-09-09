# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
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

    # Writes session files into a project directory under the temporary
    # ~/.claude/projects stand-in.
    def build_project(name, files = {})
      project_path = File.join(@projects_path, name)
      FileUtils.mkdir_p(project_path)
      files.each { |filename, content| File.write(File.join(project_path, filename), content) }
      Project.new(project_path)
    end

    # A session's last activity is the file's modification time, so tests that
    # assert on ordering or timestamps set it explicitly.
    def touch_session(project, filename, at:)
      path = File.join(project.path, filename)
      File.utime(at, at, path)
    end

    def commands(color: false)
      Commands.new(@projects_path, color: color)
    end

    def projects_fixture_path
      File.expand_path("fixtures/claude-projects", __dir__)
    end
  end
end
