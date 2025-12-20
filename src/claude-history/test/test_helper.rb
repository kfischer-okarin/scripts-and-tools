# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/claude_history"

module ClaudeHistory
  class TestCase < Minitest::Test
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
  end
end
