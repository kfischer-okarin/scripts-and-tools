# frozen_string_literal: true

require "test_helper"

# A canary against format drift: the fixtures are real session files captured
# from Claude Code, and reading them must produce no format warnings. When
# Claude Code changes its format, add a fresh capture here and this test says
# what the parser no longer understands.
#
# See test/fixtures/claude-projects/-Users-user-project/README.md for what the
# captured session contains.
class RealSessionFilesTest < ClaudeHistory::TestCase
  def test_reads_every_captured_session_file_without_format_warnings
    warnings = fixture_sessions.flat_map { |session| session.warnings }

    assert_empty warnings.map { |warning| "#{warning.filename}:#{warning.line_number} #{warning.type}: #{warning.message}" }
  end

  def test_renders_a_captured_session_as_a_transcript
    output = fixture_commands.show_session("b3edadab-bca0-4054-9b41-f7ffa6941260", project: "-Users-user-project")

    assert_includes output, "<User> Hello I want to have some test conversation with you create some file for me"
    assert_includes output, "<Tool> Write(test-file.txt)"
  end

  def test_renders_a_captured_agent_session
    output = fixture_commands.show_session("agent-a434715", project: "-Users-user-project")

    assert_includes output, "<Tool> Read(test-file.txt)"
  end

  private

  def fixture_sessions
    ClaudeHistory::History.new(projects_fixture_path).projects.flat_map(&:all_sessions)
  end

  def fixture_commands
    ClaudeHistory::Commands.new(projects_fixture_path)
  end
end
