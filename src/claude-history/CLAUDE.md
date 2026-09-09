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
warning. When Claude Code's format moves on, add a fresh capture there.

## Reference Documentation

See `docs/claude-code-history-format-spec.md` for the Claude Code session file
format specification, and its "Format coverage" section for what this tool
currently understands and where the known gaps are.
