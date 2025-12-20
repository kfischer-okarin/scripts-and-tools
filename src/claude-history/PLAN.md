# Claude History CLI - Implementation Plan

## Architecture Overview

```
exe/claude-history (executable)
    └── ClaudeHistory::CLI (Thor, humble object)
            └── ClaudeHistory::History (main API, all behavior)
                    └── ClaudeHistory::ProjectParser (core parser)
                            └── Record classes + Warning objects
```

## Project Structure

```
claude-history/
├── Gemfile
├── mise.toml
├── exe/
│   └── claude-history          # Executable (bundle exec)
├── lib/
│   └── claude_history.rb       # Main require file
│   └── claude_history/
│       ├── cli.rb              # Thor CLI (humble object)
│       ├── history.rb          # Main API class
│       ├── project_parser.rb   # Core parser
│       ├── warning.rb          # Warning objects
│       └── records/
│           ├── base.rb         # Base record class
│           ├── user_message.rb
│           ├── assistant_message.rb
│           ├── summary.rb
│           └── file_history_snapshot.rb
└── test/
    ├── test_helper.rb
    ├── project_parser_test.rb  # Parser-focused tests
    └── history_test.rb         # Behavior-driven CLI feature tests
```

## Implementation Steps

### Step 1: Project Setup
- Add dependencies to Gemfile (thor, minitest)
- Create lib/claude_history.rb with require statements
- Create exe/claude-history executable stub

### Step 2: Warning System
**File**: `lib/claude_history/warning.rb`

```ruby
class ClaudeHistory::Warning
  attr_reader :type, :message, :file_path, :line_number, :record_data

  TYPES = %i[unknown_record_type missing_field unexpected_field type_mismatch]
end
```

- Structured warning objects with location info
- Attached to records or collected at parser level
- Queryable by type, file, severity

### Step 3: Record Base Class
**File**: `lib/claude_history/records/base.rb`

Common fields for user/assistant messages:
- `type`, `uuid`, `parentUuid`, `timestamp`, `sessionId`
- `message`, `cwd`, `version`, `gitBranch`, `slug`
- `isSidechain`, `userType`
- `warnings` array

Validation at construction time - emit warnings for:
- Missing expected fields
- Unexpected fields (new/unknown)
- Type mismatches

### Step 4: Specific Record Classes

**UserMessage** (`records/user_message.rb`):
- `message.content` variants: string, tool_result array, command, interrupt
- `isMeta`, `thinkingMetadata`, `toolUseResult`, `todos`
- Helper methods: `text_content`, `tool_result?`, `command?`, `interrupt?`, `meta?`

**AssistantMessage** (`records/assistant_message.rb`):
- `requestId`, `message.model`, `message.id`, `message.usage`
- Content blocks: thinking, text, tool_use
- Helper methods: `thinking_blocks`, `text_blocks`, `tool_use_blocks`
- Note: Multiple records share same `requestId` (streaming chunks)

**Summary** (`records/summary.rb`):
- `summary` (text), `leafUuid`

**FileHistorySnapshot** (`records/file_history_snapshot.rb`):
- `messageId`, `snapshot`, `isSnapshotUpdate`
- `snapshot.trackedFileBackups` hash

### Step 5: ProjectParser
**File**: `lib/claude_history/project_parser.rb`

```ruby
class ClaudeHistory::ProjectParser
  def initialize(project_path)
  def parse -> ParseResult (files, records, warnings)
  def parse_file(jsonl_path) -> FileParseResult

  private
  def parse_line(json_string, line_number) -> Record
  def classify_file(path) -> :conversation | :summary_only | :file_history_only | :empty
end
```

Focus on main conversation files (UUID.jsonl, not agent-*):
- Parse each line as JSON
- Dispatch to correct Record class based on `type`
- Collect warnings for unknown types or parse errors
- Build tree structure via `parentUuid` linking

### Step 6: History Class
**File**: `lib/claude_history/history.rb`

```ruby
class ClaudeHistory::History
  def initialize(claude_projects_path = "~/.claude/projects")

  # Project discovery
  def projects -> Array of project info hashes

  # Session discovery
  def sessions(project_id:) -> Array of session info

  # Session viewing
  def session(session_id, project_id:) -> ParsedSession
  def branch(session_id, project_id:, leaf_uuid: nil) -> Array of records

  # Warnings access
  def warnings(session_id:, project_id:) -> Array of Warning
  def has_warnings?(session_id:, project_id:) -> Boolean
end
```

### Step 7: CLI Class
**File**: `lib/claude_history/cli.rb`

Thin Thor wrapper - delegates everything to History:

```ruby
class ClaudeHistory::CLI < Thor
  desc "projects", "List all projects"
  desc "sessions", "List sessions in a project"
  option :project, required: true
  desc "view SESSION_ID", "View a session"
  option :project, required: true
  option :compact, type: :boolean
  option :no_thinking, type: :boolean
  option :no_tools, type: :boolean
  option :warnings, type: :boolean  # Show warnings for session
end
```

## TDD Flow

### Phase 1: History Entry Point (brief)
Start with `History#show_session(session_id, project_id:)` test:
```ruby
def test_show_session_returns_parsed_session
  history = ClaudeHistory::History.new(fixture_path)
  session = history.show_session("b3edadab-bca0-4054-9b41-f7ffa6941260",
                                  project_id: "-Users-user-project")
  # Assert on structure - drives out what we need from parser
end
```
This immediately fails and drives us into the parser.

### Phase 2: Parser Focus (main effort)
Once History test exists, focus entirely on parser tests using example-project:

```ruby
# test/project_parser_test.rb

# Record type parsing - one test per type
def test_parses_user_message_record
def test_parses_assistant_message_record
def test_parses_summary_record
def test_parses_file_history_snapshot_record

# Content variants
def test_parses_user_simple_text_content
def test_parses_user_tool_result_content
def test_parses_user_command_content
def test_parses_user_interrupt_marker
def test_parses_assistant_thinking_block
def test_parses_assistant_text_block
def test_parses_assistant_tool_use_block

# Validation & warnings
def test_warns_on_unknown_record_type
def test_warns_on_missing_required_field
def test_warns_on_unexpected_field
def test_warns_on_type_mismatch

# Tree structure
def test_builds_parent_child_relationships
def test_identifies_branch_endpoints

# File classification
def test_classifies_conversation_file
def test_classifies_summary_only_file
def test_classifies_empty_file
```

Record classes emerge organically from parser tests - create them as the tests demand.

### Phase 3: Back to History
Once parser covers the spec, return to History tests for remaining CLI features.

## Validation Completeness

### Top-level fields validated:
- `type` (required, must be known)
- `uuid`, `parentUuid`, `timestamp`, `sessionId` (for messages)
- `message.role`, `message.content` (for messages)

### Nested validation:
- `message.content` block types (text, thinking, tool_use, tool_result)
- `message.usage` structure
- `toolUseResult` variants (create, edit, text)
- `thinkingMetadata` structure

### Warning triggers:
1. Unknown `type` value
2. Missing required field for known type
3. Unknown field present (potential format change)
4. Type mismatch (expected string, got array, etc.)

## Dependencies

```ruby
# Gemfile
gem "thor"           # CLI framework
gem "minitest"       # Testing
gem "rake"           # Task runner for tests
```

## First Implementation Focus

1. Warning class
2. Record base + 4 record types with validation
3. ProjectParser with single-file parsing
4. Basic History with session viewing
5. Minimal CLI to exercise the above
