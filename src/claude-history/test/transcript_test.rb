# frozen_string_literal: true

require "test_helper"

# What `show-session` prints: the records of one session file, in file order.
class TranscriptTest < ClaudeHistory::TestCase
  def test_prints_the_resolved_file_and_the_conversation_in_it
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"timestamp":"2026-09-09T09:30:00.000Z","message":{"role":"user","content":"Hello"}}
      {"type":"assistant","uuid":"a1","parentUuid":"u1","timestamp":"2026-09-09T09:31:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Hi there!"}]}}
    JSONL

    assert_equal <<~OUTPUT, output
      Session: session
      File:    #{session_file_path}
      Title:   Hello

      [2026-09-09 18:30] <User> Hello

      [2026-09-09 18:31] <Assistant> Hi there!
    OUTPUT
  end

  def test_prints_a_tool_call_followed_by_its_result
    output = transcript(<<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":{"stdout":"one\\ntwo\\nthree\\nfour\\nfive"}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Read(notes.md)

        ⎿  one
           two
           three
           … +2 lines
    OUTPUT
  end

  def test_verbose_prints_the_whole_tool_result
    output = transcript(<<~JSONL, verbose: true)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":{"stdout":"one\\ntwo\\nthree\\nfour\\nfive"}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Read(notes.md)

        ⎿  one
           two
           three
           four
           five
    OUTPUT
  end

  # An inline script's first line says nothing about what the call is for, and
  # the description doubles as something to grep for.
  def test_heads_a_bash_call_with_its_description
    output = transcript(<<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"set -e\\nfor f in *.rb; do\\n  ruby -c $f\\ndone","description":"Syntax-check every Ruby file"}}]}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Bash: Syntax-check every Ruby file
           $ set -e…
    OUTPUT
  end

  def test_verbose_prints_the_whole_bash_script
    output = transcript(<<~JSONL, verbose: true)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"set -e\\nfor f in *.rb; do\\n  ruby -c $f\\ndone","description":"Syntax-check every Ruby file"}}]}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Bash: Syntax-check every Ruby file
           $ set -e
             for f in *.rb; do
               ruby -c $f
             done
    OUTPUT
  end

  def test_prints_a_bash_call_that_has_no_description
    output = transcript(<<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls -la"}}]}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Bash
           $ ls -la
    OUTPUT
  end

  def test_marks_a_failed_tool_call
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"File does not exist."}]}}
    JSONL

    assert_includes output, "  ⎿  Error: File does not exist."
  end

  def test_prints_an_edit_result_as_a_numbered_diff
    output = transcript(<<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Edit","input":{"file_path":"/tmp/greet.rb"}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":{"structuredPatch":[{"newStart":10,"lines":["-old line","+new line"," kept line"]}]}}
    JSONL

    assert_includes output, <<~OUTPUT
      <Tool> Edit(greet.rb)

        ⎿  Removed 1 lines, added 1 lines
                -  old line
             10 +  new line
             11    kept line
    OUTPUT
  end

  def test_hides_thinking_unless_verbose
    jsonl = <<~JSONL
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"thinking","thinking":"Let me consider this."},{"type":"text","text":"Done."}]}}
    JSONL

    refute_includes transcript(jsonl), "Let me consider this."
    assert_includes transcript(jsonl), "1 records hidden (1 thinking block)"
    assert_includes transcript(jsonl, verbose: true), "💭 Let me consider this."
  end

  def test_prints_a_slash_command_with_its_arguments
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"<command-name>/review-branch</command-name>\\n<command-message>review-branch</command-message>\\n<command-args>main</command-args>"}}
    JSONL

    assert_includes output, "<User> /review-branch main"
  end

  def test_prints_the_output_of_a_built_in_command
    output = transcript(<<~JSONL)
      {"type":"system","uuid":"s1","parentUuid":null,"subtype":"local_command","level":"info","content":"<local-command-stdout>Session renamed to: parent_id_scopes</local-command-stdout>"}
    JSONL

    assert_includes output, "  ⎿  Session renamed to: parent_id_scopes"
  end

  def test_prints_an_expanded_command_prompt_only_when_verbose
    jsonl = <<~JSONL
      {"type":"user","uuid":"u1","parentUuid":null,"isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Review the branch against main."}]}}
    JSONL

    refute_includes transcript(jsonl), "Review the branch against main."
    assert_includes transcript(jsonl, verbose: true), "<Meta> Review the branch against main."
  end

  def test_marks_an_interrupted_response
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
    JSONL

    assert_includes output, "<Interrupted>"
  end

  def test_prints_a_summary_record
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
      {"type":"summary","summary":"Greeting exchange","leafUuid":"u1"}
    JSONL

    assert_includes output, "<Summary> Greeting exchange"
  end

  def test_counts_bookkeeping_records_instead_of_printing_them
    jsonl = <<~JSONL
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
      {"type":"attachment","uuid":"x1","parentUuid":null,"attachment":{"type":"total_tokens_reminder"}}
      {"type":"attachment","uuid":"x2","parentUuid":null,"attachment":{"type":"output_style"}}
      {"type":"ai-title","aiTitle":"Greeting"}
    JSONL

    assert_includes transcript(jsonl),
                    "3 records hidden (2 attachment, 1 ai-title); use --verbose to show them"
    assert_includes transcript(jsonl, verbose: true), "· attachment: total_tokens_reminder"
    assert_includes transcript(jsonl, verbose: true), "· ai-title: Greeting"
  end

  def test_reports_a_record_type_it_does_not_know
    output = transcript(<<~JSONL, verbose: true)
      {"type":"brand-new-record","uuid":"n1","parentUuid":null}
    JSONL

    assert_includes output, "· brand-new-record"
    assert_includes output, %(line 1: unknown_record_type: Unknown record type: "brand-new-record")
  end

  def test_reports_a_line_it_cannot_parse
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"Hello"}}
      {"type":"user","uuid":"u2",
    JSONL

    assert_includes output, "line 2: unparsable_line: Could not parse JSON"
  end

  # Compaction is the one bookkeeping record that always shows: it explains why
  # the transcript around it jumps.
  def test_always_marks_where_the_context_was_compacted
    output = transcript(<<~JSONL)
      {"type":"system","uuid":"s1","parentUuid":null,"subtype":"compact_boundary","compactMetadata":{"trigger":"manual","messagesSummarized":105}}
      {"type":"user","uuid":"u1","parentUuid":"s1","isCompactSummary":true,"message":{"role":"user","content":"This session is being continued from a previous conversation."}}
    JSONL

    assert_includes output, "<Compacted> context compacted (manual, 105 messages summarized)"
    assert_includes output, "<Compacted context> This session is being continued from a previous conversation."
  end

  # Reverting and asking again leaves both attempts in the file, the second
  # answering the same parent as the first. The transcript shows each where the
  # file has it.
  def test_keeps_the_file_order_across_a_revert
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":"First question"}}
      {"type":"assistant","uuid":"a1","parentUuid":"u1","message":{"role":"assistant","content":[{"type":"text","text":"First answer"}]}}
      {"type":"user","uuid":"u2","parentUuid":"u1","message":{"role":"user","content":"Asked again after a revert"}}
    JSONL

    assert_operator output.index("First answer"), :<, output.index("Asked again after a revert")
  end

  def test_prints_text_blocks_of_a_multimodal_prompt
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":[{"type":"image"},{"type":"text","text":"What is in this screenshot?"}]}}
    JSONL

    assert_includes output, "<User> What is in this screenshot?"
  end

  def test_reports_a_content_shape_it_does_not_know
    output = transcript(<<~JSONL)
      {"type":"user","uuid":"u1","parentUuid":null,"message":{"role":"user","content":[{"type":"telepathy"}]}}
    JSONL

    assert_includes output, "line 1: unexpected_content_shape: Unexpected user content blocks: telepathy"
  end

  private

  def transcript(jsonl, verbose: false)
    build_project("project", "session.jsonl" => jsonl)
    commands.show_session("session", verbose: verbose)
  end

  def session_file_path
    File.join(@projects_path, "project", "session.jsonl")
  end
end
