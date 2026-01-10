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

    error = assert_raises(ClaudeHistory::Error) do
      history.resolve_project_id("foo")
    end

    assert_includes error.message, "Ambiguous"
    assert_includes error.message, "foo-bar"
    assert_includes error.message, "foo-baz"
  end

  def test_resolve_project_id_raises_error_when_no_match
    history = ClaudeHistory::History.new(@projects_path)

    error = assert_raises(ClaudeHistory::Error) do
      history.resolve_project_id("nonexistent-xyz-123")
    end

    assert_includes error.message, "No project found"
    assert_includes error.message, "nonexistent-xyz-123"
  end

  def test_resolve_project_id_returns_exact_match_when_prefix_of_another
    build_project("foo-bar")
    build_project("foo-bar-extended")

    history = ClaudeHistory::History.new(@projects_path)

    assert_equal "foo-bar", history.resolve_project_id("foo-bar")
  end

  def test_resolve_session_id_returns_session_for_unique_prefix_match
    project = build_project("session-resolve-test", {
      "abc12345-session.jsonl" => build_session_jsonl("abc12345", "2025-01-01T10:00:00Z")
    })

    history = ClaudeHistory::History.new(@projects_path)
    session = history.resolve_session_id("abc12", project_id: project.id)

    assert_equal "abc12345-session", session.id
  end

  def test_resolve_session_id_raises_error_for_ambiguous_prefix
    project = build_project("session-ambiguous-test", {
      "abc12345-session.jsonl" => build_session_jsonl("abc12345", "2025-01-01T10:00:00Z"),
      "abc12999-session.jsonl" => build_session_jsonl("abc12999", "2025-01-02T10:00:00Z")
    })

    history = ClaudeHistory::History.new(@projects_path)

    error = assert_raises(ClaudeHistory::Error) do
      history.resolve_session_id("abc12", project_id: project.id)
    end

    assert_includes error.message, "Ambiguous"
    assert_includes error.message, "abc12345-session"
    assert_includes error.message, "abc12999-session"
  end

  def test_resolve_session_id_raises_error_when_no_match
    project = build_project("session-nomatch-test", {
      "abc12345-session.jsonl" => build_session_jsonl("abc12345", "2025-01-01T10:00:00Z")
    })

    history = ClaudeHistory::History.new(@projects_path)

    error = assert_raises(ClaudeHistory::Error) do
      history.resolve_session_id("xyz99", project_id: project.id)
    end

    assert_includes error.message, "No session found"
    assert_includes error.message, "xyz99"
  end

  def test_sessions_updated_on_returns_threads_with_activity_on_date
    build_project("project-a", {
      "session-a.jsonl" => build_session_jsonl("session-a", "2025-01-15T10:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    assert_equal 1, results.size
    assert_equal "project-a", results[0][:project].id
    assert_equal "session-a", results[0][:session].id
  end

  def test_sessions_updated_on_excludes_sessions_from_other_dates
    build_project("project-a", {
      "session-target.jsonl" => build_session_jsonl("target", "2025-01-15T10:00:00+09:00"),
      "session-other.jsonl" => build_session_jsonl("other", "2025-01-14T10:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    assert_equal 1, results.size
    assert_equal "session-target", results[0][:session].id
  end

  def test_sessions_updated_on_returns_user_message_count_for_target_date
    build_project("project-a", {
      "session-a.jsonl" => build_session_jsonl("session-a", "2025-01-15T10:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    # build_session_jsonl creates 1 user message and 1 assistant message
    assert_equal 1, results[0][:message_count]
  end

  def test_sessions_updated_on_sorts_by_latest_timestamp_on_date_descending
    # Timestamps in JST (UTC+9) - both on Jan 15 JST
    build_project("project-a", {
      "session-early.jsonl" => build_session_jsonl("early", "2025-01-15T08:00:00+09:00"),
      "session-late.jsonl" => build_session_jsonl("late", "2025-01-15T20:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    assert_equal 2, results.size
    assert_equal "session-late", results[0][:session].id
    assert_equal "session-early", results[1][:session].id
  end

  def test_sessions_updated_on_spans_multiple_projects
    build_project("project-a", {
      "session-a.jsonl" => build_session_jsonl("session-a", "2025-01-15T10:00:00+09:00")
    })
    build_project("project-b", {
      "session-b.jsonl" => build_session_jsonl("session-b", "2025-01-15T12:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    assert_equal 2, results.size
    project_ids = results.map { |r| r[:project].id }
    assert_includes project_ids, "project-a"
    assert_includes project_ids, "project-b"
  end

  def test_sessions_updated_on_returns_empty_array_when_no_activity
    build_project("project-a", {
      "session-a.jsonl" => build_session_jsonl("session-a", "2025-01-14T10:00:00+09:00")
    })

    history = ClaudeHistory::History.new(@projects_path)
    results = history.sessions_updated_on(Date.new(2025, 1, 15))

    assert_empty results
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
