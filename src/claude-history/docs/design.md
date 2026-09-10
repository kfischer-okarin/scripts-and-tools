# Design

## The premise

A session is one JSONL file. The tool resolves a session id to that file and
prints every line of it, in the order Claude Code wrote it.

File order is the whole model, and it is what makes the output trustworthy: the
transcript holds what the file holds, so any line of it can be checked against
the file, and a reader who greps a session and then opens it by hand finds the
same things in the same places. Where a session was reverted and continued from
an earlier point, the abandoned attempt and the retry both appear, in the order
they were written.

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

`ToolResult` classifies one tool's output, and `CommandMarkup` the pseudo-XML
of a slash command — both value objects the records hand out.

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

Every line becomes a record, an unfamiliar one included: it gets a warning and
still prints.

`UserMessage` covers more than typed prompts, so it classifies itself into a
`content_type` — `:text`, `:command`, `:command_output`, `:tool_result`,
`:interrupt`, `:compact_summary`, `:meta` or `:unknown` — and the renderer
decides how each looks. The `<command-name>` / `<local-command-stdout>` markup
is parsed by `CommandMarkup`, shared with `SystemRecord` because built-in
commands are now logged as system records.

## Listings read only the ends of a file

Session files reach tens of megabytes, and `sessions-updated-on` looks at every
project.

- **last activity** is the file's modification time, straight from the
  filesystem, so `sessions-updated-on` can rule a session out before opening it.
- **title, branch, start time** come from `SessionOverview`, which reads a 64 KiB
  window at each end. Titles and summaries are re-appended as a session
  progresses, so the latest of them is near the tail; the opening prompt and
  first timestamp are in the head.

## Tool results

Claude Code records a tool's output in `toolUseResult` with a different shape
per tool and no field saying which tool produced it. `ToolResult` classifies a
result by the fields it carries, and that `kind` is what the renderer formats
against.

A kind is worth adding when a result reads badly as a list of fields. That
covers the tools used most — the shell, file and search tools — and the tools
whose result is content in its own right rather than a summary of something
stored elsewhere: `AskUserQuestion` and `ExitPlanMode` print in full in both
modes, because an answer is a decision the user made and a plan is the work
they approved.

Everything else falls to `:fields`, which prints what a result contains without
knowing which tool it came from. That covers the long tail of smaller tools and
every tool added since, which is why an unrecognised shape is not a warning: it
still reads fine, so warning about it would only produce a list of work nobody
intends to do. An `Artifact` result shows its published URL without anyone
having taught the renderer about `Artifact`.

The renderer needs the tool's name for one case — `ExitPlanMode` sometimes
records its plan as a bare string, which nothing else distinguishes from any
other text result. It gets the name by remembering the `tool_use` blocks it has
already printed, which works because a call always precedes its result in the
file; an id the renderer never saw yields nil and the result falls back to its
shape.

## Warnings

Warnings exist to catch format drift rather than to fail. Each `Record`
subclass lists the fields particular to its type in `EXPECTED_ATTRIBUTES`;
`Record::ENVELOPE_ATTRIBUTES` holds the session envelope — the fields Claude
Code stamps on a conversation record whatever its type — so they are declared
once. The test is what a field belongs to, not how many types carry it: `error`
appears on both assistant and system records and is payload on each, so it
stays in both lists. A `MetadataRecord` declares no attributes and so opts out:
its shapes are Claude Code's own bookkeeping and change often.

| Warning type                | Trigger                                            |
| --------------------------- | -------------------------------------------------- |
| `:unexpected_attributes`    | A top-level field in neither list                  |
| `:unexpected_content_shape` | A user content block or content type nobody expects |
| `:unknown_record_type`      | A `type` that is not in the known set              |
| `:unparsable_line`          | A line that is not JSON                            |
| `:unreadable_tool_result`   | A tool result that is neither text nor fields (MCP results exempt) |

`show-session` prints them under the transcript, so drift is visible at the
point where it might mislead a reader. `check-format` reports them across the
whole history, which is how the format is verified against reality rather than
against fixtures.

## Rendering

`Session#render` hands each record to the renderer in file order; each record
class calls the matching `render_*` method (visitor pattern), which keeps
formatting out of the record classes.

A tool call is labelled `<Tool>` rather than `<Assistant>`: it is not something
Claude said, and the two are much easier to read apart. Bash calls lead with
their `description`, since the first line of an inline script rarely says what
the call is for.

```text
[2026-09-09 18:30] <User> Fix the failing parser test

[2026-09-09 18:31] <Assistant> I'll look at the test first.

[2026-09-09 18:31] <Tool> Bash: Run the test suite
     $ bundle exec rake test

  ⎿  Run options: --seed 42620
     # Running:
     F
     … +12 lines
```

Plain mode keeps the conversation and counts what it left out. `--verbose`
keeps everything: thinking blocks, expanded command prompts, full tool output
and every bookkeeping line.
