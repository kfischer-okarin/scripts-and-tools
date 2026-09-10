# frozen_string_literal: true

require "test_helper"

# What `check-format` prints: everything the parser could not account for,
# across real session files.
class FormatCheckTest < ClaudeHistory::TestCase
  def test_reports_nothing_when_every_line_is_understood
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
      {"type":"ai-title","aiTitle":"Greeting"}
    JSONL

    assert_equal "Checked 1 session files. No format warnings.", commands.check_format
  end

  def test_groups_the_same_drift_across_files_into_one_finding
    build_project(
      "project",
      "one.jsonl" => %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hi"},"newField":1}\n),
      "two.jsonl" => %({"type":"user","uuid":"u2","parentUuid":null,"message":{"role":"user","content":"Hi"},"newField":2}\n)
    )

    output = commands.check_format

    assert_includes output, "Checked 2 session files, 2 warnings:"
    assert_includes output, "unexpected_attributes"
    assert_includes output, "Unexpected attributes: newField"
    assert_match(/^2\s+unexpected_attributes/, output.lines.last)
  end

  def test_names_the_first_file_and_line_a_finding_came_from
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
      {"type":"brand-new-record","uuid":"n1","parentUuid":null}
    JSONL

    assert_includes commands.check_format, "session.jsonl:2"
  end

  def test_checks_agent_files_too
    build_project("project", "agent-a434715.jsonl" => %({"type":"mystery-record","uuid":"m1"}\n))

    assert_includes commands.check_format, "Unknown record type: \"mystery-record\""
  end

  def test_can_check_a_single_project
    build_project("-Users-user-clean", "session.jsonl" => %({"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hi"}}\n))
    build_project("-Users-user-drifted", "session.jsonl" => %({"type":"mystery-record","uuid":"m1"}\n))

    assert_equal "Checked 1 session files. No format warnings.", commands.check_format(project: "clean")
    assert_includes commands.check_format(project: "drifted"), "mystery-record"
  end
end
