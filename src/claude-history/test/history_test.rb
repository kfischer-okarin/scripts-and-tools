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

  def test_projects_returns_all_projects
    projects = @history.projects

    assert_kind_of Array, projects
    assert projects.all? { |p| p.is_a?(ClaudeHistory::Project) }
    assert_includes projects.map(&:id), fixture_project_id
  end

  def test_sessions_returns_all_sessions_for_project
    sessions = @history.sessions(project_id: fixture_project_id)

    assert_kind_of Array, sessions
    assert sessions.all? { |s| s.is_a?(ClaudeHistory::Session) }
  end

  def test_sessions_returns_sessions_sorted_descending_by_last_updated
    # Files are created with ascending mtime (older first, newer last)
    project = build_project("sort-test", {
      "older-session.jsonl" => build_session_jsonl("older", "2025-01-01T10:00:00Z"),
      "newer-session.jsonl" => build_session_jsonl("newer", "2025-01-02T10:00:00Z")
    })

    history = ClaudeHistory::History.new(@projects_path)
    sessions = history.sessions(project_id: project.id)

    assert_equal 2, sessions.size
    assert_equal "newer-session", sessions[0].id
    assert_equal "older-session", sessions[1].id
  end

  def test_resolve_project_id_returns_full_id_for_unique_partial_match
    build_project("unique-test-project")

    history = ClaudeHistory::History.new(@projects_path)

    assert_equal "unique-test-project", history.resolve_project_id("unique-test")
  end

  def test_resolve_project_id_raises_error_for_ambiguous_match
    build_project("foo-bar")
    build_project("foo-baz")

    history = ClaudeHistory::History.new(@projects_path)

    error = assert_raises(ArgumentError) do
      history.resolve_project_id("foo")
    end

    assert_includes error.message, "Ambiguous"
    assert_includes error.message, "foo-bar"
    assert_includes error.message, "foo-baz"
  end

  def test_resolve_project_id_raises_error_when_no_match
    history = ClaudeHistory::History.new(@projects_path)

    error = assert_raises(ArgumentError) do
      history.resolve_project_id("nonexistent-xyz-123")
    end

    assert_includes error.message, "No project found"
    assert_includes error.message, "nonexistent-xyz-123"
  end

  private

  def build_session_jsonl(session_id, timestamp)
    user_uuid = "user-#{session_id}"
    assistant_uuid = "assistant-#{session_id}"

    [
      { type: "user", uuid: user_uuid, parentUuid: nil, timestamp: timestamp, message: { content: "Hello" } },
      { type: "assistant", uuid: assistant_uuid, parentUuid: user_uuid, timestamp: timestamp, message: { content: [{ type: "text", text: "Hi" }] } }
    ].map { |r| JSON.generate(r) }.join("\n")
  end
end
