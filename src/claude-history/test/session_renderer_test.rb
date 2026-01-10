# frozen_string_literal: true

require "test_helper"

class SessionRendererTest < ClaudeHistory::TestCase
  def test_renders_user_text_message_with_timestamp
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Hello world"}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    # 10:30 UTC = 19:30 JST
    assert_equal "[2025-01-07 19:30] <User> Hello world\n", renderer.output
  end

  def test_renders_built_in_command_with_timestamp
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"<command-name>/init</command-name>\\n<command-message>init</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"2","parentUuid":"1","message":{"role":"user","content":"<local-command-stdout>Initialized project</local-command-stdout>"}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    assert_equal "[2025-01-07 19:30] <User> /init\n", renderer.output
  end

  def test_renders_user_defined_command_with_timestamp
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"<command-name>/commit</command-name>\\n<command-message>commit</command-message>\\n<command-args>-m fix</command-args>"}}
        {"type":"user","uuid":"2","parentUuid":"1","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Expanded commit prompt..."}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    assert_equal "[2025-01-07 19:30] <User> /commit -m fix\n", renderer.output
  end

  def test_renders_assistant_text_block_with_timestamp
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Hello

      [2025-01-07 19:31] <Assistant> Hi there!
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_renders_tool_use_block
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Read file.txt"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Read","input":{"file_path":"/path/to/file.txt"}}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Read file.txt

      [2025-01-07 19:31] <Assistant> Read(file.txt)
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_renders_tool_result
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Read file.txt"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Read","input":{"file_path":"/path/to/file.txt"}}]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":"file contents here"}]},"toolUseResult":{"type":"text","file":{"filePath":"/path/to/file.txt","numLines":10,"totalLines":10}}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Read file.txt

      [2025-01-07 19:31] <Assistant> Read(file.txt)
        ⎿  Read 10 lines
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_renders_edit_tool_result
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Edit file.txt"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Edit","input":{"file_path":"/path/to/file.txt","old_string":"old","new_string":"new"}}]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":"edited"}]},"toolUseResult":{"filePath":"/path/to/file.txt","structuredPatch":[{"oldStart":1,"oldLines":2,"newStart":1,"newLines":6,"lines":[" context","-removed1","-removed2"," ","+added1","+added2","+added3"]}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Edit file.txt

      [2025-01-07 19:31] <Assistant> Edit(file.txt)
        ⎿  Removed 2 lines, added 3 lines
              1    context
                -  removed1
                -  removed2
              2
              3 +  added1
              4 +  added2
              5 +  added3
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_verbose_mode_shows_thinking_blocks
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Let me think about this...","signature":"abc123"}]}}
        {"type":"assistant","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new(verbose: true)

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    assert_includes renderer.output, "Let me think about this..."
  end

  def test_default_mode_hides_thinking_blocks
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Let me think about this...","signature":"abc123"}]}}
        {"type":"assistant","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    refute_includes renderer.output, "Let me think about this..."
    assert_includes renderer.output, "Hi there!"
  end

  def test_renders_blank_line_between_assistant_and_next_user
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Hello"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:32:00Z","message":{"role":"user","content":"Thanks"}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Hello

      [2025-01-07 19:31] <Assistant> Hi there!

      [2025-01-07 19:32] <User> Thanks
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_verbose_shows_full_bash_command_and_output
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Run it"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Bash","input":{"command":"echo hello &&\\necho world"}}]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":"line1\\nline2\\nline3\\nline4\\nline5"}]},"toolUseResult":"line1\\nline2\\nline3\\nline4\\nline5"}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new(verbose: true)

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> Run it

      [2025-01-07 19:31] <Assistant> Bash(echo hello &&
      echo world)
        ⎿  line1
           line2
           line3
           line4
           line5
    OUTPUT
    assert_equal expected, renderer.output
  end

  def test_renders_multiline_bash_command_truncated
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"Run script"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Bash","input":{"command":"echo hello && \\necho world"}}]}}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    assert_includes renderer.output, "Bash(echo hello && …)"
  end

  def test_renders_bash_with_command_and_output_preview
    project = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-07T10:30:00Z","message":{"role":"user","content":"List files"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-07T10:31:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_123","name":"Bash","input":{"command":"ls -la"}}]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-07T10:31:01Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":"line1\\nline2\\nline3\\nline4\\nline5"}]},"toolUseResult":"line1\\nline2\\nline3\\nline4\\nline5"}
      JSONL
    )
    thread = project.session("test").threads.first
    renderer = ClaudeHistory::SessionRenderer.new

    with_timezone("Asia/Tokyo") do
      thread.render(renderer)
    end

    expected = <<~OUTPUT
      [2025-01-07 19:30] <User> List files

      [2025-01-07 19:31] <Assistant> Bash(ls -la)
        ⎿  line1
           line2
           line3
           … +2 lines
    OUTPUT
    assert_equal expected, renderer.output
  end

  private

  def with_timezone(tz)
    old_tz = ENV["TZ"]
    ENV["TZ"] = tz
    yield
  ensure
    ENV["TZ"] = old_tz
  end
end
