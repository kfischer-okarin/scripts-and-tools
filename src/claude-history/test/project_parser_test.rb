# frozen_string_literal: true

require "test_helper"

class ProjectParserTest < ClaudeHistory::TestCase
  def setup
    project_path = File.join(projects_fixture_path, fixture_project_id)
    @parser = ClaudeHistory::ProjectParser.new(project_path)
  end

  def test_parses_session_into_typed_records
    session = @parser.parse_session(fixture_main_session_id)

    assert session.records.all? { |r| r.is_a?(ClaudeHistory::Record) }
  end

  def test_parses_user_message_records
    session = @parser.parse_session(fixture_main_session_id)

    user_records = session.records.select { |r| r.type == "user" }
    refute_empty user_records
    assert user_records.all? { |r| r.is_a?(ClaudeHistory::UserMessage) }
  end

  def test_parses_assistant_message_records
    session = @parser.parse_session(fixture_main_session_id)

    assistant_records = session.records.select { |r| r.type == "assistant" }
    refute_empty assistant_records
    assert assistant_records.all? { |r| r.is_a?(ClaudeHistory::AssistantMessage) }
  end

  def test_parses_file_history_snapshot_records
    session = @parser.parse_session(fixture_main_session_id)

    snapshot_records = session.records.select { |r| r.type == "file-history-snapshot" }
    refute_empty snapshot_records
    assert snapshot_records.all? { |r| r.is_a?(ClaudeHistory::FileHistorySnapshot) }
  end

  def test_parses_summary_records
    session = @parser.parse_session(fixture_summary_session_id)

    summary_records = session.records.select { |r| r.type == "summary" }
    refute_empty summary_records
    assert summary_records.all? { |r| r.is_a?(ClaudeHistory::Summary) }
  end
end
