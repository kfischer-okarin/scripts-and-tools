# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

A Ruby CLI tool for displaying and searching Claude Code conversation histories
from `~/.claude/projects/`. The centerpiece is a parser that converts JSONL
session files into typed Ruby objects with validation and warning collection.

## Commands

```bash
# Run all tests
bundle exec rake test

# Run a single test file
bundle exec rake test TEST=test/project_test.rb

# Run tests matching a name pattern
bundle exec rake test TESTOPTS="--name=/test_session_returns/"
```

## Architecture

See @docs/design.md for architecture and design decisions. When planning changes
that affect the architecture, update design.md first.

## Test Fixtures

Real Claude Code session files are in
`test/fixtures/claude-projects/-Users-user-project/`. The test helper provides
`build_project` to create temporary project directories with custom JSONL
content for isolated testing.

## Reference Documentation

See `docs/claude-code-history-format-spec.md` for the complete Claude Code
session file format specification.
