# frozen_string_literal: true

require "test_helper"

# What `sessions` prints: one row per session file of a project.
class SessionListingTest < ClaudeHistory::TestCase
  def test_lists_session_files_newest_first
    project = build_project(
      "-Users-user-project",
      "older.jsonl" => user_prompt("An earlier question"),
      "newer.jsonl" => user_prompt("A later question")
    )
    touch_session(project, "older.jsonl", at: Time.new(2026, 9, 1, 10, 0, 0))
    touch_session(project, "newer.jsonl", at: Time.new(2026, 9, 8, 17, 45, 30))

    output = commands.sessions(project: "-Users-user-project", full_ids: true)

    assert_equal <<~OUTPUT.chomp, output
      Showing 2 of 2 sessions in -Users-user-project

      SESSION ID  LAST UPDATED AT      BRANCH  TITLE
      ----------------------------------------------
      newer       2026-09-08 17:45:30          A later question
      older       2026-09-01 10:00:00          An earlier question
    OUTPUT
  end

  def test_shows_the_branch_the_session_ended_on
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"gitBranch":"main","message":{"role":"user","content":"Start on main"}}
      {"type":"user","uuid":"u2","parentUuid":"u1","gitBranch":"feature/parser","message":{"role":"user","content":"Continue on the feature branch"}}
    JSONL

    assert_includes commands.sessions(project: "project"), "feature/parser"
  end

  def test_titles_a_session_by_its_opening_prompt
    build_project("project", "session.jsonl" => user_prompt("Fix the failing parser test"))

    assert_includes commands.sessions(project: "project"), "Fix the failing parser test"
  end

  def test_prefers_the_title_claude_code_generated_over_the_opening_prompt
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Fix the failing parser test"}}
      {"type":"ai-title","aiTitle":"Parser test failure"}
    JSONL

    assert_includes commands.sessions(project: "project"), "Parser test failure"
  end

  def test_prefers_a_title_the_user_set_over_a_generated_one
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Fix the failing parser test"}}
      {"type":"ai-title","aiTitle":"Parser test failure"}
      {"type":"custom-title","customTitle":"parser-rewrite"}
    JSONL

    assert_includes commands.sessions(project: "project"), "parser-rewrite"
  end

  def test_falls_back_to_a_summary_record_in_older_files
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":[{"type":"text","text":"An array prompt has no title"}]}}
      {"type":"summary","summary":"Discussed the parser rewrite","leafUuid":"u1"}
    JSONL

    assert_includes commands.sessions(project: "project"), "Discussed the parser rewrite"
  end

  def test_shows_only_the_requested_number_of_sessions
    project = build_project(
      "project",
      "first.jsonl" => user_prompt("One"),
      "second.jsonl" => user_prompt("Two")
    )
    touch_session(project, "first.jsonl", at: Time.new(2026, 9, 2, 12, 0, 0))
    touch_session(project, "second.jsonl", at: Time.new(2026, 9, 3, 12, 0, 0))

    output = commands.sessions(project: "project", limit: 1)

    assert_includes output, "Showing 1 of 2 sessions in project"
    assert_includes output, "Two"
    refute_includes output, "One"
  end

  def test_leaves_out_agent_files_unless_asked
    build_project(
      "project",
      "session.jsonl" => user_prompt("A main session"),
      "agent-a434715.jsonl" => user_prompt("A subagent task")
    )

    refute_includes commands.sessions(project: "project"), "A subagent task"
    assert_includes commands.sessions(project: "project", agents: true), "A subagent task"
  end

  def test_leaves_out_empty_files_left_behind_by_resume
    build_project(
      "project",
      "session.jsonl" => user_prompt("A real session"),
      "abandoned.jsonl" => ""
    )

    assert_includes commands.sessions(project: "project"), "Showing 1 of 1 sessions"
  end

  def test_shortens_session_ids_unless_full_ids_are_asked_for
    build_project("project", "3f6ddfee-788c-48a5-8f7a-d43377b51472.jsonl" => user_prompt("Hello"))

    assert_includes commands.sessions(project: "project"), "3f6ddfee "
    assert_includes commands.sessions(project: "project", full_ids: true), "3f6ddfee-788c-48a5-8f7a-d43377b51472"
  end

  def test_says_so_when_a_project_has_no_sessions
    build_project("project")

    assert_equal "No sessions found in project.", commands.sessions(project: "project")
  end

  private

  def user_prompt(text)
    %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"#{text}"}}\n)
  end
end
