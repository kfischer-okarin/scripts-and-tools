# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

The joplin data API documentation can be found in `docs/joplin-api-spec.md`.

## Commands

```bash
# Run all tests
bundle exec rake test

# Run a single test file
bundle exec ruby -Itest test/client_test.rb

# Run the CLI locally
bundle exec ./exe/joplin folders
bundle exec ./exe/joplin folders --debug  # Shows raw HTTP requests/responses
```

## Environment

- Requires `JOPLIN_TOKEN` environment variable (from Joplin desktop > Web
  Clipper Options)
- Joplin desktop must be running with clipper server enabled (port 41184)
- Ruby version managed via `mise.toml`

## Architecture

This is a CLI tool for interacting with the Joplin note-taking app's REST API.

**Layer structure:**

- `Joplin::CLI` (Thor) - Thin wrapper that delegates to domain objects
- `Joplin::Client` - Domain object handling API communication, accepts optional
  `logger:` lambda for debugging
- Renderer objects - Handle CLI output formatting
- Value objects representing Joplin data structures

**Key patterns:**

- Tests drive the `Client` layer using `webmock` for HTTP stubbing, not the CLI
  layer

**Entry points:**

- `exe/joplin` - Ruby executable
