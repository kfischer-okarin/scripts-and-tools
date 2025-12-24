# frozen_string_literal: true

require "test_helper"

class CLITest < ClaudeHistory::TestCase
  def test_thread_summary_returns_summary_when_present
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"summary","summary":"This is the summary","leafUuid":"2"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    thread = project.session("test").threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 50)

    assert_equal "This is the summary", result
  end

  def test_thread_summary_fallback_shows_first_and_last_segment_messages
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Hello, how are you today?"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"Tell me about Ruby programming"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"Tell me about Python programming"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    ruby_thread = session.threads.find { |t| t.id == "3a" }

    result = ClaudeHistory::CLI.thread_summary(ruby_thread, max_length: 30)

    # 30 - 4 (" -> ") = 26 chars for both parts, 13 each
    assert_equal "Hello, how... -> Tell me ab...", result
  end

  def test_thread_summary_fallback_distributes_length_when_first_is_short
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Hi"},"timestamp":"2025-01-01T00:00:00Z"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]},"timestamp":"2025-01-01T00:00:01Z"}
        {"type":"user","uuid":"branch","parentUuid":"2","message":{"role":"user","content":"branch"},"timestamp":"2025-01-01T00:00:02Z"}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"Tell me about Ruby programming please"},"timestamp":"2025-01-01T00:00:03Z"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 30)

    # "Hi" is 2 chars, leaves 24 for second part (30 - 4 - 2 = 24)
    assert_equal "Hi -> Tell me about Ruby pr...", result
  end

  def test_thread_summary_fallback_distributes_length_when_second_is_short
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Tell me about Ruby programming please"},"timestamp":"2025-01-01T00:00:00Z"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]},"timestamp":"2025-01-01T00:00:01Z"}
        {"type":"user","uuid":"branch","parentUuid":"2","message":{"role":"user","content":"branch"},"timestamp":"2025-01-01T00:00:02Z"}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"Ok"},"timestamp":"2025-01-01T00:00:03Z"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    thread = project.session("test").threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 30)

    # "Ok" is 2 chars, leaves 24 for first part (30 - 4 - 2 = 24)
    assert_equal "Tell me about Ruby pr... -> Ok", result
  end

  def test_thread_summary_fallback_with_single_message
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    thread = project.session("test").threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 50)

    assert_equal "Hello", result
  end

  def test_thread_summary_fallback_includes_user_defined_command_names
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Help me review code"},"timestamp":"2025-01-01T00:00:00Z"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]},"timestamp":"2025-01-01T00:00:01Z"}
        {"type":"user","uuid":"branch","parentUuid":"2","message":{"role":"user","content":"branch"},"timestamp":"2025-01-01T00:00:02Z"}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"<command-name>/review-branch</command-name>\\n<command-message>review-branch</command-message>\\n<command-args>main</command-args>"},"timestamp":"2025-01-01T00:00:03Z"}
        {"type":"user","uuid":"4","parentUuid":"3","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Review instructions..."}]},"timestamp":"2025-01-01T00:00:04Z"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    thread = project.session("test").threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 50)

    assert_equal "Help me review code -> /review-branch", result
  end

  def test_thread_summary_fallback_with_reversed_tag_order
    # Claude Code changed tag order: command-message before command-name
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Help me review code"},"timestamp":"2025-01-01T00:00:00Z"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]},"timestamp":"2025-01-01T00:00:01Z"}
        {"type":"user","uuid":"branch","parentUuid":"2","message":{"role":"user","content":"branch"},"timestamp":"2025-01-01T00:00:02Z"}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"<command-message>review-branch</command-message>\\n<command-name>/review-branch</command-name>"},"timestamp":"2025-01-01T00:00:03Z"}
        {"type":"user","uuid":"4","parentUuid":"3","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Review instructions..."}]},"timestamp":"2025-01-01T00:00:04Z"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    thread = project.session("test").threads.first

    result = ClaudeHistory::CLI.thread_summary(thread, max_length: 50)

    assert_equal "Help me review code -> /review-branch", result
  end

  def test_session_summary_uses_latest_thread
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"summary","summary":"Latest thread summary","leafUuid":"2"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    result = ClaudeHistory::CLI.session_summary(session, max_length: 50)

    assert_equal "Latest thread summary", result
  end
end
