# Claude History CLI - Handoff Document

## Project Overview

A Ruby CLI tool for parsing and viewing Claude Code conversation histories from `~/.claude/projects/`. The centerpiece is a JSONL parser that validates records and emits warnings for unknown/changed formats.

## Architecture

```
exe/claude-history (executable)
    └── ClaudeHistory::CLI (Thor, humble object - not yet implemented)
            └── ClaudeHistory::History (main API)
                    └── ClaudeHistory::ProjectParser (core parser)
                            └── Record classes + Warning objects
```

## Current State

### What's Working (22 tests passing)

1. **Project structure**: Gemfile, lib/, exe/, test/ with minitest
2. **History#show_session**: Entry point that returns a parsed Session
3. **ProjectParser**: Parses JSONL files, dispatches to typed Record classes
4. **Record types**:
   - `UserMessage` - with content_type detection (:text, :tool_result, :command, :interrupt)
   - `AssistantMessage` - with model and content_blocks accessors
   - `Summary`
   - `FileHistorySnapshot`
5. **Warning system**:
   - Warnings have: type, message, line_number, raw_data
   - Records validate attributes at construction, warn on unexpected
   - Session aggregates warnings from all records
   - Unknown record types emit warnings
   - Unexpected content shapes emit warnings
6. **Fixture test**: Sanity check that parses all real fixture files with zero warnings

### Files Structure

```
lib/
├── claude_history.rb           # Main require
└── claude_history/
    ├── history.rb              # Main API (show_session)
    ├── project_parser.rb       # JSONL parsing
    ├── record.rb               # Base class with attribute validation
    ├── session.rb              # Holds records, aggregates warnings
    ├── warning.rb              # Warning data object
    └── records/
        ├── assistant_message.rb
        ├── file_history_snapshot.rb
        ├── summary.rb
        └── user_message.rb

test/
├── test_helper.rb              # TestCase base with build_project helper
├── history_test.rb             # Entry point test
└── project_parser_test.rb      # Main parser tests

test/fixtures/claude-projects/-Users-user-project/
    └── *.jsonl                 # Real Claude Code session files
```

### Test Helpers

- `projects_fixture_path` - path to fixtures/claude-projects
- `fixture_project_id` - "-Users-user-project"
- `fixture_main_session_id` - main conversation with branches
- `fixture_summary_session_id` - summary-only file
- `build_project(files_hash)` - creates temp dir with JSONL files, auto-cleanup

## What's NOT Done Yet

### From the plan (pending items):

1. **Tree structure** (in_progress):
   - `Session#roots` - find records with null parentUuid
   - `Session#children_of(uuid)` - find children by parentUuid
   - Branch reconstruction via parentUuid walking

2. **CLI** (not started):
   - Thor-based CLI wrapper
   - Commands: projects, sessions, view
   - Options: --compact, --no-thinking, --no-tools, --warnings

3. **Agent files** (deferred):
   - Currently skipped (files starting with `agent-`)
   - Need warmup vs task agent detection

4. **Additional record accessors**:
   - UserMessage: timestamp, sessionId, isMeta, etc.
   - AssistantMessage: thinking_blocks, text_blocks, tool_use_blocks helpers
   - Summary: summary text, leafUuid accessors
   - FileHistorySnapshot: snapshot data accessors

## TDD Approach

User prefers Kent Beck style TDD:
- Write ONE failing test
- Implement smallest change to fix current error
- Refactor when tests pass
- Don't add code without a test driving it

## Key Design Decisions

1. **Records know their line_number** - enables precise warning locations
2. **Validation at construction** - warnings collected upfront, not lazily
3. **EXPECTED_ATTRIBUTES in each class** - strict validation, warns on new fields
4. **content_type as symbol enum** - :text, :tool_result, :command, :interrupt, :unknown
5. **Warnings aggregated at Session level** - `session.warnings` collects from all records

## Running Tests

```bash
cd /Users/kevin/dev-settings/scripts/scripts-and-tools/src/claude-history
bundle exec rake test
```

## References

- **JSONL Format Spec**: `docs/claude-code-history-format-spec.md`
- **Implementation Plan**: `PLAN.md` (original architecture and full TDD flow)

## Next Steps

1. Add tree structure tests and implementation (Session#roots, Session#children_of)
2. Add branch walking/reconstruction
3. Start on CLI with Thor
4. Add more record accessors as needed by CLI display
