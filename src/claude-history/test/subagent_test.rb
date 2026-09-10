# frozen_string_literal: true

require "test_helper"

# A subagent keeps its own transcript, in a `subagents` directory beside the
# session that spawned it. It is reached through that session rather than from
# the project listing.
class SubagentTest < ClaudeHistory::TestCase
  def test_an_agent_result_names_the_agent_it_ran
    build_parent_and_subagent

    output = commands.show_session("parent")

    assert_includes output, <<~OUTPUT
      <Tool> Agent(general-purpose: Audit the docs)

        ⎿  completed · agent a216e84faa0b993ef
    OUTPUT
  end

  # The transcript ends with the commands that open what it left out.
  def test_offers_the_subagent_command_when_the_session_called_one
    build_parent_and_subagent

    output = commands.show_session("parent")

    assert_includes output, <<~OUTPUT.chomp
      ──────────────────────────────────────────────────────────────────────────────
      claude-history show-session parent --verbose              # thinking, full tool output, bookkeeping records
      claude-history show-session parent --subagent <agent-id>  # one subagent's own transcript
    OUTPUT
  end

  def test_offers_only_the_verbose_command_when_no_subagent_ran
    build_project("project", "session.jsonl" => user_prompt("No agents here"))

    output = commands.show_session("session")

    assert_includes output, "claude-history show-session session --verbose  # thinking, full tool output, bookkeeping records"
    refute_includes output, "--subagent <agent-id>"
  end

  def test_offers_nothing_more_when_already_verbose_and_agentless
    build_project("project", "session.jsonl" => user_prompt("No agents here"))

    refute_includes commands.show_session("session", verbose: true), "claude-history"
  end

  # Inside a subagent view, --verbose keeps pointing at the same transcript,
  # naming the agent in full even when a prefix was given.
  def test_keeps_the_subagent_selection_in_the_verbose_command
    build_parent_and_subagent

    output = commands.show_session("parent", subagent: "a216")

    assert_includes output, "claude-history show-session parent --subagent a216e84faa0b993ef --verbose"
  end

  def test_prints_the_subagent_transcript_and_names_its_parent
    build_parent_and_subagent

    output = commands.show_session("parent", subagent: "a216e84faa0b993ef")

    assert_equal <<~OUTPUT.chomp, output
      Session:     agent-a216e84faa0b993ef
      Subagent of: parent
      File:        #{File.join(@projects_path, "project", "parent", "subagents", "agent-a216e84faa0b993ef.jsonl")}
      Title:       Audit these four documents, reporting findings only

      [2026-09-09 19:55] <User> Audit these four documents, reporting findings only

      [2026-09-09 19:56] <Assistant> I read all four. Findings below.

      ──────────────────────────────────────────────────────────────────────────────
      claude-history show-session parent --subagent a216e84faa0b993ef --verbose  # thinking, full tool output, bookkeeping records
    OUTPUT
  end

  # A subagent's title is its task prompt, which can run to paragraphs, so the
  # header shows only as much as fits on a line.
  def test_shortens_a_long_task_prompt_in_the_header
    long_prompt = "Audit the docs. #{"Look closely at every heading. " * 10}"
    build_project(
      "project",
      "parent.jsonl" => user_prompt("Parent"),
      "parent/subagents/agent-a1.jsonl" => user_prompt(long_prompt)
    )

    title_line = commands.show_session("parent", subagent: "a1").lines[3]

    assert_match(/^Title:       Audit the docs\. Look closely.*…$/, title_line)
    assert_operator ClaudeHistory::DisplayWidth.of(title_line.chomp), :<=, 113
  end

  def test_finds_a_subagent_by_an_id_prefix
    build_parent_and_subagent

    assert_includes commands.show_session("parent", subagent: "a216"), "agent-a216e84faa0b993ef"
  end

  def test_refuses_an_ambiguous_subagent_prefix
    build_project(
      "project",
      "parent.jsonl" => user_prompt("Parent"),
      "parent/subagents/agent-a111aaa.jsonl" => user_prompt("First"),
      "parent/subagents/agent-a111bbb.jsonl" => user_prompt("Second")
    )

    error = assert_raises(ClaudeHistory::Error) { commands.show_session("parent", subagent: "a111") }

    assert_includes error.message, "Ambiguous subagent of parent 'a111'"
  end

  def test_reports_a_subagent_that_has_no_transcript
    build_project("project", "parent.jsonl" => user_prompt("Parent"))

    error = assert_raises(ClaudeHistory::Error) { commands.show_session("parent", subagent: "a999") }

    assert_equal "No subagent of parent found matching 'a999'", error.message
  end

  # Older versions of Claude Code wrote subagent transcripts straight into the
  # project directory, so an id is looked up there too.
  def test_finds_a_subagent_stored_in_the_old_location
    build_project(
      "project",
      "parent.jsonl" => user_prompt("Parent"),
      "agent-a434715.jsonl" => user_prompt("An older subagent task")
    )

    assert_includes commands.show_session("parent", subagent: "a434715"), "An older subagent task"
  end

  def test_keeps_subagents_out_of_the_session_listing
    build_parent_and_subagent

    output = commands.sessions(project: "project")

    assert_includes output, "Showing 1 of 1 sessions"
    refute_includes output, "a216e84faa0b993ef"
  end

  def test_keeps_subagents_out_of_the_activity_listing
    project = build_parent_and_subagent
    touch_session(project, "parent.jsonl", at: Time.new(2026, 9, 9, 20, 0, 0))
    touch_session(project, "parent/subagents/agent-a216e84faa0b993ef.jsonl", at: Time.new(2026, 9, 9, 20, 0, 0))

    output = commands.sessions_updated_on("2026-09-09")

    assert_includes output, "parent"
    refute_includes output, "a216e84faa0b993ef"
  end

  # check-format is the one place that wants every file: a subagent transcript
  # can carry an unfamiliar record type just as a session can.
  def test_checks_subagent_transcripts_for_format_drift
    build_project(
      "project",
      "parent.jsonl" => user_prompt("Parent"),
      "parent/subagents/agent-a1.jsonl" => %({"type":"mystery-record","uuid":"m1"}\n)
    )

    output = commands.check_format

    assert_includes output, "Checked 2 session files"
    assert_includes output, %(Unknown record type: "mystery-record")
  end

  private

  def build_parent_and_subagent
    build_project(
      "project",
      "parent.jsonl" => <<~JSONL,
        {"type":"user","uuid":"u1","parentUuid":null,"timestamp":"2026-09-09T10:54:00.000Z","message":{"role":"user","content":"Audit the docs please"}}
        {"type":"assistant","uuid":"a1","parentUuid":"u1","timestamp":"2026-09-09T10:55:00.000Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"general-purpose","description":"Audit the docs","prompt":"Audit these four documents"}}]}}
        {"type":"user","uuid":"u2","parentUuid":"a1","timestamp":"2026-09-09T10:56:00.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":{"agentId":"a216e84faa0b993ef","status":"completed","content":[{"type":"text","text":"Findings below."}],"totalTokens":63243}}
      JSONL
      "parent/subagents/agent-a216e84faa0b993ef.jsonl" => <<~JSONL
        {"type":"user","uuid":"s1","parentUuid":null,"isSidechain":true,"agentId":"a216e84faa0b993ef","timestamp":"2026-09-09T10:55:00.000Z","message":{"role":"user","content":"Audit these four documents, reporting findings only"}}
        {"type":"assistant","uuid":"s2","parentUuid":"s1","isSidechain":true,"agentId":"a216e84faa0b993ef","timestamp":"2026-09-09T10:56:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"I read all four. Findings below."}]}}
      JSONL
    )
  end

  def user_prompt(text)
    %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"#{text}"}}\n)
  end
end
