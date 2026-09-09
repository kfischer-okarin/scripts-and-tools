# frozen_string_literal: true

require "test_helper"

# How each tool's result reads in a transcript. Claude Code records a different
# result shape per tool and never says which tool it came from, so these pin
# the shapes down by example.
class ToolResultTest < ClaudeHistory::TestCase
  # Answers and plans are content in their own right, not a preview of
  # something a reader can go and look at, so both modes print them whole.

  def test_prints_every_question_and_answer_in_full
    result = {
      questions: [{ question: "Case-sensitive or case-insensitive?" }],
      answers: {
        "Case-sensitive or case-insensitive?" => "Case-sensitive",
        "Which separator?" => "Keep `__`"
      }
    }

    output = transcript_of_result("AskUserQuestion", result)

    assert_includes output, <<~OUTPUT
      <Tool> AskUserQuestion

        ⎿  Q: Case-sensitive or case-insensitive?
           A: Case-sensitive
           Q: Which separator?
           A: Keep `__`
    OUTPUT
  end

  def test_prints_an_answer_that_runs_over_several_lines
    result = { answers: { "Which approach?" => "Option 2.\nThough the path looks odd." } }

    assert_includes transcript_of_result("AskUserQuestion", result), <<~OUTPUT
      <Tool> AskUserQuestion

        ⎿  Q: Which approach?
           A: Option 2.
           Though the path looks odd.
    OUTPUT
  end

  def test_prints_an_approved_plan_in_full
    result = { plan: "# Plan\n\n1. First\n2. Second\n3. Third\n4. Fourth", filePath: "/tmp/plan.md", isAgent: false }

    assert_includes transcript_of_result("ExitPlanMode", result), <<~OUTPUT
        ⎿  Plan:
           # Plan
      #{"     "}
           1. First
           2. Second
           3. Third
           4. Fourth
    OUTPUT
  end

  # ExitPlanMode sometimes records the plan as a bare string, which only the
  # tool name distinguishes from any other text result.
  def test_prints_a_plan_that_arrived_as_a_bare_string
    output = transcript_of_result("ExitPlanMode", "# Plan\n\n1. One\n2. Two\n3. Three\n4. Four")

    assert_includes output, <<~OUTPUT
      <Tool> ExitPlanMode

        ⎿  Plan:
           # Plan
    OUTPUT
    assert_includes output, "4. Four"
  end

  def test_names_the_skill_that_was_activated
    result = { commandName: "brew-maintenance", success: true }

    assert_includes transcript_of_result("Skill", result), "⎿  Skill(brew-maintenance) activated"
  end

  def test_shows_a_web_search_query_and_its_results_when_verbose
    result = { query: "ruby minitest assert_output", durationSeconds: 4.2, results: [{ content: "Result one\nResult two" }] }

    assert_includes transcript_of_result("WebSearch", result), %(⎿  Searched for "ruby minitest assert_output")
    assert_includes transcript_of_result("WebSearch", result, verbose: true), "Result one"
  end

  def test_shows_a_web_fetch_url_and_its_body_when_verbose
    result = { url: "https://example.com/docs", code: 200, bytes: 4096, codeText: "OK", result: "The fetched page." }

    assert_includes transcript_of_result("WebFetch", result), "⎿  HTTP 200 https://example.com/docs (4096 bytes)"
    assert_includes transcript_of_result("WebFetch", result, verbose: true), "The fetched page."
  end

  def test_counts_todos_by_status_and_lists_them_when_verbose
    result = {
      newTodos: [
        { content: "Write the parser", status: "completed" },
        { content: "Render the transcript", status: "in_progress" }
      ],
      oldTodos: []
    }

    assert_includes transcript_of_result("TodoWrite", result), "⎿  2 todos (1 completed, 1 in_progress)"
    assert_includes transcript_of_result("TodoWrite", result, verbose: true), "[in_progress] Render the transcript"
  end

  def test_shows_a_task_status_change
    result = { taskId: "3", statusChange: { from: "in_progress", to: "completed" }, success: true, updatedFields: ["status"] }

    assert_includes transcript_of_result("TaskUpdate", result), "⎿  Task 3: in_progress → completed"
  end

  def test_shows_a_created_task
    result = { task: { task_id: "bk8numkvi", description: "Wait for CI to run", status: "running" } }

    assert_includes transcript_of_result("TaskCreate", result), "⎿  Task bk8numkvi: Wait for CI to run: running"
  end

  def test_shows_a_task_update_that_changed_no_status
    result = { taskId: "7", success: true, updatedFields: %w[description] }

    assert_includes transcript_of_result("TaskUpdate", result), "⎿  Task 7 updated (description)"
  end

  def test_reports_a_written_file_by_its_length
    result = { type: "create", filePath: "/tmp/greet.rb", content: "one\ntwo\nthree", structuredPatch: [] }

    assert_includes transcript_of_result("Write", result), "⎿  Wrote 3 lines"
  end

  def test_reports_reading_an_image
    result = { type: "image", file: { base64: "iVBORw0KGgo=", originalSize: 2048 } }

    assert_includes transcript_of_result("Read", result), "⎿  Read an image"
  end

  # A tool nobody taught the renderer about — including every tool added after
  # this was written — still shows what it returned, so no maintenance is owed
  # and nothing is warned about.
  def test_prints_the_fields_of_a_tool_it_knows_nothing_about
    result = { somethingNew: 42, nested: { a: 1, b: 2 }, several: [1, 2, 3], note: "a short note" }

    output = transcript_of_result("BrandNewTool", result)

    assert_includes output, <<~OUTPUT
      <Tool> BrandNewTool

        ⎿  somethingNew: 42
           nested: {a, b}
           several: [3 items]
           note: a short note
    OUTPUT
    refute_includes output, "Format warnings"
  end

  def test_shortens_a_long_field_unless_verbose
    result = { listing: "agent one\nagent two\n#{"x" * 200}" }

    assert_includes transcript_of_result("ListAgents", result), "…"
    assert_includes transcript_of_result("ListAgents", result, verbose: true), "x" * 200
  end

  # The only tool result worth warning about is one with nothing in it at all.
  def test_warns_when_a_tool_result_holds_nothing_showable
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"BrokenTool","input":{}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":42}
    JSONL

    output = commands.show_session("session")

    assert_includes output, "line 2: unreadable_tool_result: Tool result is neither text nor fields: Integer"
  end

  # MCP result shapes belong to the server, not to Claude Code, and can change
  # whenever the server does. Claude Code marks those records with mcpMeta.
  def test_stays_quiet_about_a_result_shape_an_mcp_server_chose
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"mcp__github__pull_request_read","input":{"owner":"agileware-jp","repo":"bamboo","pullNumber":274}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","mcpMeta":{"serverName":"github"},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":{"whateverTheServerSends":true}}
    JSONL

    output = commands.show_session("session")

    refute_includes output, "unexpected_tool_result_shape"
  end

  # An MCP tool's arguments are the server's own JSON, so they get the shape a
  # Bash script gets: the tool named on one line, its input underneath.
  def test_prints_an_mcp_call_with_its_input_underneath
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"mcp__github__pull_request_read","input":{"owner":"agileware-jp","pullNumber":274}}]}}
    JSONL

    assert_includes commands.show_session("session"), <<~OUTPUT
      <Tool> mcp__github__pull_request_read
             {"owner":"agileware-jp","pullNumber":274}
    OUTPUT

    assert_includes commands.show_session("session", verbose: true), <<~OUTPUT
      <Tool> mcp__github__pull_request_read
             {
               "owner": "agileware-jp",
               "pullNumber": 274
             }
    OUTPUT
  end

  private

  # A tool call and the result Claude Code recorded for it, one after the other
  # in the file, which is how the renderer knows which tool a result belongs to.
  def transcript_of_result(tool_name, tool_use_result, verbose: false)
    build_project("project", "session.jsonl" => <<~JSONL)
      {"type":"assistant","uuid":"a1","parentUuid":null,"message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"#{tool_name}","input":{}}]}}
      {"type":"user","uuid":"u1","parentUuid":"a1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]},"toolUseResult":#{JSON.generate(tool_use_result)}}
    JSONL

    commands.show_session("session", verbose: verbose)
  end
end
