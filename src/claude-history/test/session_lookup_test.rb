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

  def test_opens_a_session_file_given_by_path
    path = File.join(@projects_path, "exported.jsonl")
    File.write(path, user_prompt("From a file"))

    output = commands.show_session(path)

    assert_includes output, "File:    #{path}"
    assert_includes output, "From a file"
  end

  def test_opens_a_session_file_given_by_relative_path
    File.write(File.join(@projects_path, "exported.jsonl"), user_prompt("From a file"))

    output = Dir.chdir(@projects_path) { commands.show_session("exported.jsonl") }

    assert_includes output, "File:    #{File.realpath(File.join(@projects_path, "exported.jsonl"))}"
  end

  def test_repeats_a_file_path_in_the_next_steps
    path = File.join(@projects_path, "exported.jsonl")
    File.write(path, user_prompt("From a file"))

    assert_includes commands.show_session(path), "claude-history show-session #{path} --verbose"
  end

  def test_finds_the_subagents_of_a_session_file_given_by_path
    project = build_project(
      "project",
      "s1.jsonl" => user_prompt("Parent"),
      "s1/subagents/agent-a434715.jsonl" => user_prompt("A subagent task")
    )

    output = commands.show_session(File.join(project.path, "s1.jsonl"), subagent: "a434715")

    assert_includes output, "A subagent task"
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
