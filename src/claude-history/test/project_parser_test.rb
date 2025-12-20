# frozen_string_literal: true

require "json"
require "tempfile"
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

  def test_warns_on_unknown_record_type
    project_dir = build_project(
      "test-session.jsonl" => <<~JSONL
        {"type":"unknown-future-type","foo":"bar"}
      JSONL
    )

    parser = ClaudeHistory::ProjectParser.new(project_dir)
    session = parser.parse_session("test-session")

    assert_equal 1, session.records.size
    record = session.records.first

    assert_instance_of ClaudeHistory::Record, record
    refute_empty record.warnings

    warning = record.warnings.first
    assert_equal :unknown_record_type, warning.type
    assert_equal 1, warning.line_number
    assert_equal({ type: "unknown-future-type", foo: "bar" }, warning.raw_data)
  end

  def test_session_aggregates_warnings_from_records
    project_dir = build_project(
      "test-session.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":"hi"}}
        {"type":"unknown-type-1","foo":"bar"}
        {"type":"unknown-type-2","baz":"qux"}
      JSONL
    )

    parser = ClaudeHistory::ProjectParser.new(project_dir)
    session = parser.parse_session("test-session")

    assert_equal 2, session.warnings.size
    assert session.warnings.all? { |w| w.type == :unknown_record_type }
  end
end
