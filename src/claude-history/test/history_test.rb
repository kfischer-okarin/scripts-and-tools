# frozen_string_literal: true

require "test_helper"

class HistoryTest < ClaudeHistory::TestCase
  def setup
    @history = ClaudeHistory::History.new(projects_fixture_path)
  end

  def test_show_session_returns_parsed_session_with_records
    session = @history.show_session(fixture_main_session_id, project_id: fixture_project_id)

    refute_nil session
    refute_empty session.records
  end
end
