# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

A Ruby CLI tool for browsing Claude Code conversation histories from
`~/.claude/projects/`. A session is one JSONL file: the tool resolves a session
id to that file and prints every line of it, in the order Claude Code wrote it.

## Commands

```bash
# Run all tests
bundle exec rake test

# Run a single test file
bundle exec rake test TEST=test/transcript_test.rb

# Run tests matching a name pattern
bundle exec rake test TESTOPTS="--name=/test_prints_a_tool_call/"
```

## Architecture

See @docs/design.md for architecture and design decisions. When planning changes
that affect the architecture, update design.md first.

## Tests

Behaviour is specified against `Commands`, the application API behind the CLI —
one method per command, returning the text to print. Each test file covers one
topic: what a transcript shows (`transcript_test.rb`, the centerpiece), how each
tool's result reads (`tool_result_test.rb`), how ids resolve to files, and what
each listing prints.

`build_project` writes JSONL into a temporary project directory. Session
timestamps come from file modification times, so tests that assert on ordering
or timestamps set them with `touch_session`.

`test/real_session_files_test.rb` reads the captured session files in
`test/fixtures/claude-projects/-Users-user-project/` and fails on any format
warning. It drives `History` and `Session` directly rather than going through
`Commands`, because what it checks is parsing rather than output. Those fixtures
were captured in 2025-12, so they only prove the tool still reads what it read
then.

## Checking the format against reality

The fixtures cannot catch Claude Code having moved on. `check-format` can: it
reads every non-empty session file under `~/.claude/projects`, subagent
transcripts included, and reports every line the parser could not account for,
grouped by what went wrong.

```bash
claude-history check-format                 # all projects, ~20s for 4000 files
claude-history check-format --project foo   # one project
```

**Run it after any change to the record classes, and whenever you are asked
whether the format has drifted.** A clean run prints one line. Anything else
needs a decision, and which one depends on the warning:

| Warning | What to do |
|---------|------------|
| `unexpected_attributes` | Add the field to that record class's `EXPECTED_ATTRIBUTES`, or to `Record::ENVELOPE_ATTRIBUTES` if it is part of the session envelope every record carries rather than that type's own payload. `error` sits on two types and still belongs to neither envelope. |
| `unknown_record_type` | Add the type to `MetadataRecord::DETAIL_PATHS`, mapped to the path of the field holding its gist, or to `nil` when it carries nothing worth showing. |
| `unexpected_content_shape` | A user message content block nobody expected. Add the block type to `UserMessage::TEXT_BLOCK_TYPES` if it is text-like; otherwise it needs its own handling in `determine_content_type`. |
| `unparsable_line` | Not drift — a truncated or corrupt line, usually a half-written last line. Nothing to change in the code. |
| `unreadable_tool_result` | A tool result that is neither text nor fields. Check what the tool now returns before deciding; `ToolResult` may need a new kind. |

Then record what changed in `docs/claude-code-history-format-spec.md` and its
changelog.

## Reference Documentation

`docs/claude-code-history-format-spec.md` describes the Claude Code session
file format; its "Format coverage" section is the part verified against current
files, and the rest is older research. What *this tool* understands lives in
the code — `RecordFactory::MESSAGE_TYPES`, `MetadataRecord::DETAIL_PATHS`,
`ToolResult::KINDS_BY_MARKER` and the `EXPECTED_ATTRIBUTES` lists — with the
reasoning in @docs/design.md.
