# frozen_string_literal: true

require "test_helper"

# What `projects` and `sessions-updated-on` print: an overview across projects.
class ProjectListingTest < ClaudeHistory::TestCase
  def test_lists_projects_by_last_activity
    quiet = build_project("-Users-user-quiet", "session.jsonl" => user_prompt("Hello"))
    busy = build_project("-Users-user-busy", "session.jsonl" => user_prompt("Hello"))
    touch_session(quiet, "session.jsonl", at: Time.new(2026, 8, 20, 9, 0, 0))
    touch_session(busy, "session.jsonl", at: Time.new(2026, 9, 8, 21, 15, 0))

    assert_equal <<~OUTPUT.chomp, commands.projects
      PROJECT ID         LAST UPDATED AT
      ----------------------------------
      -Users-user-busy   2026-09-08 21:15:00
      -Users-user-quiet  2026-08-20 09:00:00
    OUTPUT
  end

  def test_says_so_when_there_are_no_projects
    assert_equal "No projects found.", commands.projects
  end

  def test_lists_sessions_that_were_active_on_a_date
    project = build_project("-Users-user-project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"timestamp":"2026-09-08T01:00:00.000Z","message":{"role":"user","content":"Started here"}}
    JSONL
    touch_session(project, "session.jsonl", at: Time.new(2026, 9, 8, 15, 0, 0))

    output = commands.sessions_updated_on("2026-09-08", full_ids: true)

    assert_equal <<~OUTPUT.chomp, output
      Sessions with activity on 2026-09-08:

      PROJECT              SESSION  LAST UPDATED AT      TITLE
      --------------------------------------------------------
      -Users-user-project  session  2026-09-08 15:00:00  Started here
    OUTPUT
  end

  # A session that ran for days is active on every day it spans, not only the
  # day it was last written.
  def test_includes_a_session_that_spans_the_date
    project = build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"timestamp":"2026-09-01T01:00:00.000Z","message":{"role":"user","content":"Started on the first"}}
    JSONL
    touch_session(project, "session.jsonl", at: Time.new(2026, 9, 5, 12, 0, 0))

    assert_includes commands.sessions_updated_on("2026-09-03"), "Started on the first"
  end

  def test_leaves_out_sessions_that_ended_before_the_date
    project = build_project("project", "session.jsonl" => user_prompt("Old news"))
    touch_session(project, "session.jsonl", at: Time.new(2026, 9, 1, 12, 0, 0))

    assert_equal "No sessions found with activity on 2026-09-08.", commands.sessions_updated_on("2026-09-08")
  end

  def test_rejects_something_that_is_not_a_date
    error = assert_raises(ClaudeHistory::Error) { commands.sessions_updated_on("last tuesday") }

    assert_equal "Not a date: last tuesday", error.message
  end

  private

  def user_prompt(text)
    %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"#{text}"}}\n)
  end
end
