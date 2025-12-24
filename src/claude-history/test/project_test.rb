# frozen_string_literal: true

require "json"
require "tempfile"
require "test_helper"

class ProjectTest < ClaudeHistory::TestCase
  def setup
    project_path = File.join(projects_fixture_path, fixture_project_id)
    @project = ClaudeHistory::Project.new(project_path)
  end

  def test_session_returns_typed_records
    session = @project.session(fixture_main_session_id)

    assert session.records.all? { |r| r.is_a?(ClaudeHistory::Record) }
  end

  def test_session_parses_user_message_records
    session = @project.session(fixture_main_session_id)

    user_records = session.records.select { |r| r.type == "user" }
    refute_empty user_records
    assert user_records.all? { |r| r.is_a?(ClaudeHistory::UserMessage) }
  end

  def test_session_parses_assistant_message_records
    session = @project.session(fixture_main_session_id)

    assistant_records = session.records.select { |r| r.type == "assistant" }
    refute_empty assistant_records
    assert assistant_records.all? { |r| r.is_a?(ClaudeHistory::AssistantMessage) }
  end

  def test_session_excludes_file_history_snapshot_records
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"file-history-snapshot","messageId":"123","snapshot":{},"isSnapshotUpdate":false}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
    assert_empty session.warnings
  end

  def test_session_excludes_system_records
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"system","subtype":"local_command","uuid":"sys-1","content":"<command-name>/add-dir</command-name>\\n<command-message>add-dir</command-message>\\n<command-args></command-args>"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
    assert_empty session.warnings
  end

  def test_session_excludes_is_meta_records
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"meta","parentUuid":null,"isMeta":true,"message":{"role":"user","content":"Caveat: The messages below..."}}
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
    assert_equal %w[1 2], session.records.map(&:uuid)
    assert_empty session.warnings
  end

  def test_session_preserves_tree_when_meta_record_in_middle_of_chain
    # Meta record is a child of the first user message, and assistant is child of meta
    # The tree should still be connected: user -> assistant (skipping meta)
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"user","uuid":"meta","parentUuid":"1","isMeta":true,"message":{"role":"user","content":"Caveat..."}}
        {"type":"assistant","uuid":"2","parentUuid":"meta","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should have both user and assistant, with assistant relinked to user
    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
  end

  def test_session_preserves_tree_when_stdout_record_in_middle_of_chain
    # Command -> stdout -> assistant: stdout is skipped but assistant should still be in tree
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/init</command-name>\\n<command-message>init</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"stdout-1","parentUuid":"cmd-1","message":{"role":"user","content":"<local-command-stdout>done</local-command-stdout>"}}
        {"type":"assistant","uuid":"asst-1","parentUuid":"stdout-1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should have command and assistant (stdout embedded in command)
    assert_equal 2, session.records.size
    assert_includes session.records.map(&:class), ClaudeHistory::BuiltInCommandRecord
    assert_includes session.records.map(&:class), ClaudeHistory::AssistantMessage
  end

  def test_session_records_excludes_summaries
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"summary","summary":"test summary","leafUuid":"2"}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
  end

  def test_summary_only_files_do_not_create_sessions
    project_dir = build_project(
      "main-session.jsonl" => <<~JSONL,
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"hi"}}
      JSONL
      "summary-only.jsonl" => <<~JSONL
        {"type":"summary","summary":"test","leafUuid":"root"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)

    refute_nil project.session("main-session")
    assert_nil project.session("summary-only")
  end

  def test_session_merges_records_from_continuation_files
    project_dir = build_project(
      "main.jsonl" => <<~JSONL,
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"first"}}
        {"type":"assistant","uuid":"a1","parentUuid":"root","message":{"role":"assistant","content":[]}}
      JSONL
      "continuation.jsonl" => <<~JSONL
        {"type":"user","uuid":"u2","parentUuid":"a1","message":{"role":"user","content":"continued"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("main")

    assert_equal 3, session.records.size
    assert_nil project.session("continuation")
  end

  def test_warns_on_multiple_roots_in_session
    project_dir = build_project(
      "session.jsonl" => <<~JSONL
        {"type":"user","uuid":"root1","parentUuid":null,"message":{"role":"user","content":"first"}}
        {"type":"user","uuid":"root2","parentUuid":null,"message":{"role":"user","content":"second"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("session")

    warning = session.warnings.find { |w| w.type == :multiple_roots }
    refute_nil warning
  end

  def test_session_excludes_unknown_record_types_but_warns
    project_dir = build_project(
      "test-session.jsonl" => <<~JSONL
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"unknown-future-type","foo":"bar"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test-session")

    assert_equal 1, session.records.size

    assert_equal 1, session.warnings.size
    warning = session.warnings.first
    assert_equal :unknown_record_type, warning.type
    assert_equal 2, warning.line_number
    assert_equal "test-session.jsonl", warning.filename
    assert_equal({ type: "unknown-future-type", foo: "bar" }, warning.raw_data)
  end

  def test_session_aggregates_warnings_from_records_and_unknown_types
    project_dir = build_project(
      "test-session.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":"hi"}}
        {"type":"unknown-type-1","foo":"bar"}
        {"type":"unknown-type-2","baz":"qux"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test-session")

    # Only the user record is included
    assert_equal 1, session.records.size
    assert_equal "user", session.records.first.type

    # But warnings from unknown types are still present
    assert_equal 2, session.warnings.size
    assert session.warnings.all? { |w| w.type == :unknown_record_type }
  end

  # Content variant tests

  def test_user_message_exposes_uuid_and_parent_uuid
    session = @project.session(fixture_main_session_id)
    user_msg = session.records.find { |r| r.is_a?(ClaudeHistory::UserMessage) }

    refute_nil user_msg.uuid
    first_user = session.records.select { |r| r.is_a?(ClaudeHistory::UserMessage) }.first
    assert_nil first_user.parent_uuid
  end

  def test_record_exposes_timestamp_as_time_object
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-15T10:30:00.000Z","message":{"role":"user","content":"hi"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_instance_of Time, session.records.first.timestamp
    assert_equal Time.utc(2025, 1, 15, 10, 30, 0), session.records.first.timestamp
  end

  def test_record_exposes_line_number_and_filename
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"first"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"third"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 1, session.records[0].line_number
    assert_equal 2, session.records[1].line_number
    assert_equal 3, session.records[2].line_number

    assert_equal "test.jsonl", session.records[0].filename
    assert_equal "test.jsonl", session.records[1].filename
    assert_equal "test.jsonl", session.records[2].filename
  end

  def test_user_message_with_simple_text_content
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","parentUuid":null,"message":{"role":"user","content":"Hello world"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    user_msg = session.records.first

    assert_equal "Hello world", user_msg.content
  end

  def test_user_message_content_type_text
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":"Hello world"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal :text, session.records.first.content_type
  end

  def test_user_message_content_type_tool_result
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_123","content":"file contents"}]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal :tool_result, session.records.first.content_type
  end

  def test_session_excludes_clear_command_and_preserves_tree
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"clear-1","parentUuid":"2","message":{"role":"user","content":"<command-name>/clear</command-name>\\n<command-message>clear</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"stdout-1","parentUuid":"clear-1","message":{"role":"user","content":"<local-command-stdout></local-command-stdout>"}}
        {"type":"user","uuid":"3","parentUuid":"stdout-1","message":{"role":"user","content":"new question"}}
        {"type":"assistant","uuid":"4","parentUuid":"3","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should have 4 records: user, assistant, user, assistant (clear command and stdout skipped)
    assert_equal 4, session.records.size
    assert_equal %w[1 2 3 4], session.records.map(&:uuid)
  end

  def test_session_excludes_resume_command_and_preserves_tree
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"user","uuid":"resume-1","parentUuid":"1","message":{"role":"user","content":"<command-name>/resume</command-name>\\n<command-message>resume</command-message>\\n<command-args></command-args>"}}
        {"type":"assistant","uuid":"2","parentUuid":"resume-1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Resume command skipped, assistant relinked to user
    assert_equal 2, session.records.size
    assert_equal %w[user assistant], session.records.map(&:type)
  end

  def test_user_defined_command_record_parses_reusable_prompt
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/commit</command-name>\\n<command-message>commit</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"prompt-1","parentUuid":"cmd-1","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"# Commit Instructions\\n\\nYou are an expert..."}]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should only have one record (expanded prompt is embedded in slash command)
    assert_equal 1, session.records.size
    record = session.records.first

    assert_instance_of ClaudeHistory::UserDefinedCommandRecord, record
    assert_equal "/commit", record.command_name
    assert_equal "commit", record.command_display_name
    assert_equal "# Commit Instructions\n\nYou are an expert...", record.expanded_prompt
  end

  def test_user_defined_command_record_with_assistant_response
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/review-branch</command-name>\\n<command-message>review-branch</command-message>\\n<command-args>main</command-args>"}}
        {"type":"user","uuid":"prompt-1","parentUuid":"cmd-1","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Review the branch..."}]}}
        {"type":"assistant","uuid":"asst-1","parentUuid":"prompt-1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should have slash command and assistant (prompt merged, tree preserved)
    assert_equal 2, session.records.size
    assert_instance_of ClaudeHistory::UserDefinedCommandRecord, session.records.first
    assert_instance_of ClaudeHistory::AssistantMessage, session.records.last
    assert_equal "main", session.records.first.command_args
  end

  def test_command_record_parses_command_parts
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/init</command-name>\\n<command-message>init</command-message>\\n<command-args></command-args>"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    record = session.records.first

    assert_instance_of ClaudeHistory::BuiltInCommandRecord, record
    assert_equal "/init", record.command_name
    assert_equal "init", record.command_display_name
    assert_equal "", record.command_args
    assert_nil record.stdout_content
  end

  def test_command_record_parses_command_with_args
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/add-dir</command-name>\\n<command-message>add-dir</command-message>\\n<command-args>src/lib</command-args>"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    record = session.records.first

    assert_instance_of ClaudeHistory::BuiltInCommandRecord, record
    assert_equal "/add-dir", record.command_name
    assert_equal "add-dir", record.command_display_name
    assert_equal "src/lib", record.command_args
  end

  def test_command_record_includes_paired_stdout
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/init</command-name>\\n<command-message>init</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"stdout-1","parentUuid":"cmd-1","message":{"role":"user","content":"<local-command-stdout>Initialized</local-command-stdout>"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # Should only have one record (stdout is embedded in command)
    assert_equal 1, session.records.size
    record = session.records.first

    assert_instance_of ClaudeHistory::BuiltInCommandRecord, record
    assert_equal "Initialized", record.stdout_content
  end

  def test_command_record_with_empty_stdout
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"cmd-1","parentUuid":null,"message":{"role":"user","content":"<command-name>/init</command-name>\\n<command-message>init</command-message>\\n<command-args></command-args>"}}
        {"type":"user","uuid":"stdout-1","parentUuid":"cmd-1","message":{"role":"user","content":"<local-command-stdout></local-command-stdout>"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    record = session.records.first

    assert_instance_of ClaudeHistory::BuiltInCommandRecord, record
    assert_equal "", record.stdout_content
  end

  def test_user_message_content_type_interrupt
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal :interrupt, session.records.first.content_type
  end

  def test_assistant_message_exposes_model_and_content_blocks
    session = @project.session(fixture_main_session_id)
    assistant_msg = session.records.find { |r| r.is_a?(ClaudeHistory::AssistantMessage) }

    refute_nil assistant_msg.model
    refute_nil assistant_msg.content_blocks
  end

  def test_user_message_warns_on_unexpected_content_array_shape
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"1"},{"type":"tool_result","tool_use_id":"2"}]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    user_msg = session.records.first

    refute_empty user_msg.warnings
    assert_equal :unexpected_content_shape, user_msg.warnings.first.type
  end

  def test_user_message_warns_on_unexpected_attributes
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"123","message":{"role":"user","content":"hi"},"newField":"x","anotherNew":"y"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    user_msg = session.records.first

    assert_equal 1, user_msg.warnings.size
    warning = user_msg.warnings.first
    assert_equal :unexpected_attributes, warning.type
    assert_includes warning.message, "newField"
    assert_includes warning.message, "anotherNew"
  end

  def test_assistant_message_warns_on_unexpected_attributes
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"assistant","uuid":"123","message":{"role":"assistant","content":[]},"futureField":"x"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 1, session.warnings.size
    assert_equal :unexpected_attributes, session.warnings.first.type
  end

  def test_summary_warns_on_unexpected_attributes
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"summary","summary":"test","leafUuid":"root","futureField":"x"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 1, session.warnings.size
    assert_equal :unexpected_attributes, session.warnings.first.type
  end

  def test_summary_text_returns_summary_content
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"summary","summary":"the summary text","leafUuid":"root"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    summary = session.root_segment.summaries.first

    assert_equal "the summary text", summary.text
  end

  # Session identity tests

  def test_session_id_returns_filename_without_extension
    project_dir = build_project(
      "my-session.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("my-session")

    assert_equal "my-session", session.id
  end

  def test_session_root_returns_record_with_null_parent_uuid
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"root-id","parentUuid":null,"message":{"role":"user","content":"first"}}
        {"type":"assistant","uuid":"2","parentUuid":"root-id","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"second"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal "root-id", session.root.uuid
    assert_nil session.root.parent_uuid
  end

  # Segment tests

  def test_segment_includes_summaries_from_other_files
    project_dir = build_project(
      "main-session.jsonl" => <<~JSONL,
        {"type":"user","uuid":"root","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"leaf","parentUuid":"root","message":{"role":"assistant","content":[]}}
      JSONL
      "other-file.jsonl" => <<~JSONL
        {"type":"summary","summary":"external summary","leafUuid":"leaf"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("main-session")

    assert_equal 1, session.root_segment.summaries.size
    assert_equal "external summary", session.root_segment.summaries.first.raw_data[:summary]
  end

  def test_root_segment_contains_all_records_for_linear_session
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"thanks"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_instance_of ClaudeHistory::Segment, session.root_segment
    assert_equal 3, session.root_segment.records.size
    assert_equal %w[1 2 3], session.root_segment.records.map(&:uuid)
    assert_empty session.root_segment.children
  end

  def test_root_segment_has_children_at_branch_point
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"option a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"option b"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    segment = session.root_segment

    assert_equal %w[1 2], segment.records.map(&:uuid)
    assert_equal 2, segment.children.size
    assert_equal %w[3a 3b], segment.children.map { |s| s.records.first.uuid }.sort
  end

  def test_root_segment_handles_nested_branches
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"start"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"branch a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"branch b"}}
        {"type":"assistant","uuid":"4a","parentUuid":"3a","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"5a1","parentUuid":"4a","message":{"role":"user","content":"nested 1"}}
        {"type":"user","uuid":"5a2","parentUuid":"4a","message":{"role":"user","content":"nested 2"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    root = session.root_segment

    # Root segment ends at first branch
    assert_equal %w[1 2], root.records.map(&:uuid)
    assert_equal 2, root.children.size

    # Find branch 3a which has a nested branch
    branch_3a = root.children.find { |s| s.records.first.uuid == "3a" }
    assert_equal %w[3a 4a], branch_3a.records.map(&:uuid)
    assert_equal 2, branch_3a.children.size
    assert_equal %w[5a1 5a2], branch_3a.children.map { |s| s.records.first.uuid }.sort
  end

  def test_segment_exposes_leaf_uuid
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"thanks"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal "3", session.root_segment.leaf_uuid
  end

  def test_segment_contains_summaries_for_its_leaf
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"summary","summary":"conversation summary","leafUuid":"2"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 1, session.root_segment.summaries.size
    assert_equal "conversation summary", session.root_segment.summaries.first.raw_data[:summary]
  end

  # Thread tests

  def test_linear_session_has_one_thread
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 1, session.threads.size
    assert_instance_of ClaudeHistory::Thread, session.threads.first
  end

  def test_thread_messages_contains_records_in_order
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"thanks"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    assert_equal %w[1 2 3], thread.messages.map(&:uuid)
  end

  def test_branched_session_has_multiple_threads
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"option a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"option b"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal 2, session.threads.size
  end

  def test_each_thread_contains_full_path_from_root
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"option a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"option b"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    thread_paths = session.threads.map { |t| t.messages.map(&:uuid) }.sort

    assert_equal [%w[1 2 3a], %w[1 2 3b]], thread_paths
  end

  def test_thread_summary_is_nil_when_no_summary_exists
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    assert_nil thread.summary
  end

  def test_thread_summary_returns_summary_content_for_its_leaf
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"summary","summary":"conversation about greeting","leafUuid":"2"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    assert_equal "conversation about greeting", thread.summary
  end

  def test_thread_summary_returns_latest_available_summary_not_just_leaf
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"summary","summary":"summary at record 2","leafUuid":"2"}
        {"type":"user","uuid":"3","parentUuid":"2","message":{"role":"user","content":"continue"}}
        {"type":"assistant","uuid":"4","parentUuid":"3","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    assert_equal "summary at record 2", thread.summary
  end

  def test_each_branch_can_have_its_own_summary
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"option a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"option b"}}
        {"type":"summary","summary":"chose option a","leafUuid":"3a"}
        {"type":"summary","summary":"chose option b","leafUuid":"3b"}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    summaries = session.threads.map(&:summary).sort

    assert_equal ["chose option a", "chose option b"], summaries
  end

  def test_nested_branches_produce_correct_number_of_threads
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"start"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","message":{"role":"user","content":"branch a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","message":{"role":"user","content":"branch b"}}
        {"type":"assistant","uuid":"4a","parentUuid":"3a","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"5a1","parentUuid":"4a","message":{"role":"user","content":"nested 1"}}
        {"type":"user","uuid":"5a2","parentUuid":"4a","message":{"role":"user","content":"nested 2"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    # 3 leaves: 3b, 5a1, 5a2
    assert_equal 3, session.threads.size
  end

  def test_thread_last_updated_at_returns_last_message_timestamp
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-15T10:00:00.000Z","message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-15T10:01:00.000Z","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3","parentUuid":"2","timestamp":"2025-01-15T10:02:00.000Z","message":{"role":"user","content":"thanks"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    thread = session.threads.first

    assert_equal Time.utc(2025, 1, 15, 10, 2, 0), thread.last_updated_at
  end

  def test_session_last_updated_at_returns_max_of_threads
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-15T10:00:00.000Z","message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-15T10:01:00.000Z","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","timestamp":"2025-01-15T10:02:00.000Z","message":{"role":"user","content":"branch a"}}
        {"type":"user","uuid":"3b","parentUuid":"2","timestamp":"2025-01-15T10:05:00.000Z","message":{"role":"user","content":"branch b"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")

    assert_equal Time.utc(2025, 1, 15, 10, 5, 0), session.last_updated_at
  end

  def test_threads_are_sorted_descending_by_last_updated_at
    project_dir = build_project(
      "test.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-15T10:00:00.000Z","message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","timestamp":"2025-01-15T10:01:00.000Z","message":{"role":"assistant","content":[]}}
        {"type":"user","uuid":"3a","parentUuid":"2","timestamp":"2025-01-15T10:02:00.000Z","message":{"role":"user","content":"older branch"}}
        {"type":"user","uuid":"3b","parentUuid":"2","timestamp":"2025-01-15T10:05:00.000Z","message":{"role":"user","content":"newer branch"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)
    session = project.session("test")
    threads = session.threads

    assert_equal 2, threads.size
    assert_equal Time.utc(2025, 1, 15, 10, 5, 0), threads[0].last_updated_at
    assert_equal Time.utc(2025, 1, 15, 10, 2, 0), threads[1].last_updated_at
  end

  def test_project_last_updated_at_returns_max_of_sessions
    project_dir = build_project(
      "session-a.jsonl" => <<~JSONL,
        {"type":"user","uuid":"1","parentUuid":null,"timestamp":"2025-01-15T10:00:00.000Z","message":{"role":"user","content":"hi"}}
      JSONL
      "session-b.jsonl" => <<~JSONL
        {"type":"user","uuid":"2","parentUuid":null,"timestamp":"2025-01-15T12:00:00.000Z","message":{"role":"user","content":"hello"}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)

    assert_equal Time.utc(2025, 1, 15, 12, 0, 0), project.last_updated_at
  end

  # Duplicate record handling

  def test_session_deduplicates_records_with_same_uuid
    project_dir = build_project(
      "session.jsonl" => <<~JSONL,
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
      "duplicate.jsonl" => <<~JSONL
        {"type":"user","uuid":"1","parentUuid":null,"message":{"role":"user","content":"hi"}}
        {"type":"assistant","uuid":"2","parentUuid":"1","message":{"role":"assistant","content":[]}}
      JSONL
    )

    project = ClaudeHistory::Project.new(project_dir)

    # Only one session should exist (duplicates merged)
    assert_equal 1, project.sessions.size

    session = project.sessions.first
    assert_equal 2, session.records.size
    assert_equal %w[1 2], session.records.map(&:uuid)
  end

  # Sanity test against real fixture data

  def test_no_warnings_on_real_fixture_sessions
    project_path = File.join(projects_fixture_path, fixture_project_id)
    project = ClaudeHistory::Project.new(project_path)

    session_files = Dir.glob(File.join(project_path, "*.jsonl"))
      .map { |f| File.basename(f, ".jsonl") }
      .reject { |name| name.start_with?("agent-") }
      .reject { |name| File.zero?(File.join(project_path, "#{name}.jsonl")) }

    all_warnings = []

    session_files.each do |session_id|
      session = project.session(session_id)
      next unless session # Summary-only files don't create sessions

      session.warnings.each do |warning|
        all_warnings << { session_id: session_id, warning: warning }
      end
    end

    assert_empty all_warnings, -> {
      all_warnings.map { |w| "#{w[:session_id]}:#{w[:warning].line_number} - #{w[:warning].type}: #{w[:warning].message}" }.join("\n")
    }
  end
end
