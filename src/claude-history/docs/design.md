# Design

## The premise

A session is one JSONL file. The tool resolves a session id to that file and
prints it readably, in the order Claude Code wrote it.

It deliberately does not reconstruct the conversation tree. `parentUuid` links
records into a tree that branches on every revert, but reconstructing which
branch "won" produces a transcript that no longer matches the file, and the
answer is only ever a guess. Printing in file order means an abandoned branch
stays visible where the file has it — the same thing reading the file by hand
shows.

## Architecture

```text
CLI (Thor: parses arguments, prints what Commands returns)
  └── Commands (one method per command, returns the text to print)
        └── History (the ~/.claude/projects tree: finds projects, resolves ids)
              └── Project (one directory: finds session files)
                    └── Session (one JSONL file)
                          ├── Record (one line, via RecordFactory)
                          │     ├── UserMessage      (prompts, tool results, commands, …)
                          │     ├── AssistantMessage (text, thinking, tool_use blocks)
                          │     ├── SystemRecord     (hooks, durations, built-in commands)
                          │     ├── Summary          (older files only)
                          │     └── MetadataRecord   (titles, modes, attachments, …)
                          └── SessionOverview (title, branch, start time)
```

`Commands` is the surface the tests drive; the Thor class holds no logic beyond
argument parsing. `SessionRenderer` turns records into the transcript, and
`Table` renders the listings.

## Reading a file

`Session#records` maps every line to exactly one `Record`. `RecordFactory`
picks the class from the line's `type`:

| Type                                  | Class            |
| ------------------------------------- | ---------------- |
| `user`                                | `UserMessage`    |
| `assistant`                           | `AssistantMessage` |
| `system`                              | `SystemRecord`   |
| `summary`                             | `Summary`        |
| any other known bookkeeping type      | `MetadataRecord` |
| an unknown type, or an unreadable line | `MetadataRecord` + warning |

Nothing is skipped. A line the tool does not understand still becomes a record,
carrying a warning that `show-session` prints under the transcript.

`UserMessage` covers more than typed prompts, so it classifies itself into a
`content_type` — `:text`, `:command`, `:command_output`, `:tool_result`,
`:interrupt`, `:compact_summary`, `:meta` or `:unknown` — and the renderer
decides how each looks. The `<command-name>` / `<local-command-stdout>` markup
is parsed by `CommandMarkup`, shared with `SystemRecord` because built-in
commands are now logged as system records.

## Listings read only the ends of a file

Session files reach tens of megabytes, and `sessions-updated-on` looks at every
project. So listings never parse whole files:

- **last activity** is the file's modification time, straight from the
  filesystem.
- **title, branch, start time** come from `SessionOverview`, which reads a 64 KiB
  window at each end. Titles and summaries are appended as a session progresses,
  so they are found near the tail; the opening prompt and first timestamp are in
  the head.

`sessions-updated-on` uses the mtime to rule a session out before opening it.

## Warnings

Warnings exist to catch format drift rather than to fail. Each `Record`
subclass lists the fields particular to its type in `EXPECTED_ATTRIBUTES`;
`Record::ENVELOPE_ATTRIBUTES` holds the fields Claude Code stamps on every
record, so they are declared once. A `MetadataRecord` declares no attributes and
so opts out: its shapes are Claude Code's own bookkeeping and change often.

| Warning type                | Trigger                                            |
| --------------------------- | -------------------------------------------------- |
| `:unexpected_attributes`    | A top-level field in neither list                  |
| `:unexpected_content_shape` | A user content block or content type nobody expects |
| `:unknown_record_type`      | A `type` that is not in the known set              |
| `:unparsable_line`          | A line that is not JSON                            |

`show-session` prints them under the transcript, so drift is visible at the
point where it might mislead a reader. `check-format` reads every session file
under `~/.claude/projects` and groups the warnings by what went wrong, which is
how the format is verified against reality rather than against fixtures.

## Rendering

`Session#render` hands each record to the renderer in file order; each record
class calls the matching `render_*` method (visitor pattern), which keeps
formatting out of the record classes.

```text
[2026-09-09 18:30] <User> Fix the failing parser test

[2026-09-09 18:31] <Assistant> I'll look at the test first.

[2026-09-09 18:31] <Assistant> Bash(bundle exec rake test)
  ⎿  Run options: --seed 42620
     1 runs, 3 assertions, 1 failures
     … +12 lines
```

Plain mode keeps the conversation and counts what it left out. `--verbose`
keeps everything: thinking blocks, expanded command prompts, full tool output
and every bookkeeping line.
