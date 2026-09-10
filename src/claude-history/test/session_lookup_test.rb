# frozen_string_literal: true

require "test_helper"

# How a session id on the command line becomes a file on disk.
class SessionLookupTest < ClaudeHistory::TestCase
  def test_finds_a_session_by_its_full_id
    build_project("project", "3f6ddfee-788c-48a5-8f7a-d43377b51472.jsonl" => user_prompt("Hello"))

    output = commands.show_session("3f6ddfee-788c-48a5-8f7a-d43377b51472", project: "project")

    assert_includes output, "3f6ddfee-788c-48a5-8f7a-d43377b51472.jsonl"
  end

  def test_finds_a_session_by_an_id_prefix
    build_project("project", "3f6ddfee-788c-48a5-8f7a-d43377b51472.jsonl" => user_prompt("Hello"))

    output = commands.show_session("3f6ddfee", project: "project")

    assert_includes output, "3f6ddfee-788c-48a5-8f7a-d43377b51472.jsonl"
  end

  def test_searches_every_project_when_none_is_given
    build_project("-Users-user-other", "aaaaaaaa-1111.jsonl" => user_prompt("Elsewhere"))
    build_project("-Users-user-project", "bbbbbbbb-2222.jsonl" => user_prompt("Hello"))

    output = commands.show_session("bbbbbbbb")

    assert_includes output, "-Users-user-project/bbbbbbbb-2222.jsonl"
  end

  def test_finds_an_agent_session_by_name
    build_project("project", "agent-a434715.jsonl" => user_prompt("A subagent task"))

    assert_includes commands.show_session("agent-a434715", project: "project"), "A subagent task"
  end

  def test_matches_a_project_by_substring
    build_project("-Users-user-workspace-myproject", "session.jsonl" => user_prompt("Hello"))

    assert_includes commands.show_session("session", project: "myproject"), "Hello"
  end

  def test_refuses_an_ambiguous_session_prefix
    build_project(
      "project",
      "3f6ddfee-aaaa.jsonl" => user_prompt("One"),
      "3f6ddfee-bbbb.jsonl" => user_prompt("Two")
    )

    error = assert_raises(ClaudeHistory::Error) { commands.show_session("3f6ddfee", project: "project") }

    assert_includes error.message, "Ambiguous session '3f6ddfee'"
    assert_includes error.message, "3f6ddfee-aaaa"
    assert_includes error.message, "3f6ddfee-bbbb"
  end

  def test_refuses_an_ambiguous_project_substring
    build_project("-Users-user-project-one", "one.jsonl" => user_prompt("One"))
    build_project("-Users-user-project-two", "two.jsonl" => user_prompt("Two"))

    error = assert_raises(ClaudeHistory::Error) { commands.sessions(project: "project") }

    assert_includes error.message, "Ambiguous project 'project'"
  end

  def test_reports_a_session_id_that_matches_nothing
    build_project("project", "session.jsonl" => user_prompt("Hello"))

    error = assert_raises(ClaudeHistory::Error) { commands.show_session("nope", project: "project") }

    assert_equal "No session found matching 'nope'", error.message
  end

  def test_reports_a_project_that_matches_nothing
    build_project("project", "session.jsonl" => user_prompt("Hello"))

    error = assert_raises(ClaudeHistory::Error) { commands.sessions(project: "nope") }

    assert_equal "No project found matching 'nope'", error.message
  end

  private

  def user_prompt(text)
    %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"#{text}"}}\n)
  end
end
