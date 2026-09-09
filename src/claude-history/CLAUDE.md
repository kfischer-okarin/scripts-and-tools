# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

A Ruby CLI tool for browsing Claude Code conversation histories from
`~/.claude/projects/`. A session is one JSONL file: the tool resolves a session
id to that file and prints it readably, in file order, with no tree or branch
reconstruction.

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
command's output; `test/transcript_test.rb` is the centerpiece.

`build_project` writes JSONL into a temporary project directory. Session
timestamps come from file modification times, so tests that assert on ordering
or timestamps set them with `touch_session`.

`test/real_session_files_test.rb` reads the captured session files in
`test/fixtures/claude-projects/-Users-user-project/` and fails on any format
warning. Those fixtures were captured in 2025-12, so they only prove the tool
still reads what it read then.

## Checking the format against reality

The fixtures cannot catch Claude Code having moved on. `check-format` can: it
reads every session file under `~/.claude/projects` and reports every line the
parser could not account for, grouped by what went wrong.

```bash
claude-history check-format                 # all projects, ~20s for 4000 files
claude-history check-format --project foo   # one project
```

**Run it after any change to the record classes, and whenever you are asked
whether the format has drifted.** A clean run prints one line. Anything else is
drift: add the field to the right `EXPECTED_ATTRIBUTES` (or
`Record::ENVELOPE_ATTRIBUTES` if it appears on more than one record type), or
the type to `MetadataRecord::DETAIL_PATHS`, then record what changed in
`docs/claude-code-history-format-spec.md` and its changelog.

A field appearing on several record types belongs in the envelope, not copied
into each list — `forkedFrom` was the case that taught us this.

## Reference Documentation

See `docs/claude-code-history-format-spec.md` for the Claude Code session file
format specification, and its "Format coverage" section for what this tool
currently understands and where the known gaps are.
