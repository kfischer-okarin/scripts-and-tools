# Design

## Architecture

```text
CLI (Thor, humble object - just delegates to History)
  └── History (main API, exposes all functionality)
        └── Project (one per working directory, e.g., "-Users-user-myproject")
              └── Session (logical session: aggregates conversation tree across files)
                    ├── Record (base class for parsed lines)
                    │     ├── UserMessage
                    │     │     ├── BuiltInCommandRecord (built-in commands with optional stdout)
                    │     │     └── UserDefinedCommandRecord (reusable prompts with expanded prompt)
                    │     ├── AssistantMessage
                    │     │     └── ToolCallRecord (tool_use block + paired tool_result)
                    │     └── Summary
                    ├── Segment (contiguous records between branch points)
                    │     └── Segment... (children at branch points)
                    └── Thread (a single path from root to leaf)
```

Note: A Session aggregates all records connected via `parentUuid` chain, which
may span multiple JSONL files. The session ID comes from the file containing the
root record. This differs from the physical CLI session (the JSONL filename).

A Segment groups contiguous records between branch points. When a record has
multiple children, the segment ends and each child starts a new segment. Access
via `session.root_segment`.

A Thread represents a single path from root to leaf through the segment tree.
Each thread exposes `messages` (ordered records) and `summary` (the summary text
for its leaf, if any). Access all threads via `session.threads`.

Development is behavior-driven from the History object - new CLI features start
as History tests, which drive out the underlying Project/Session/Record
functionality.

## Record Aggregation

Some JSONL records are paired with related records during parsing. The Parser
indexes these relationships and passes paired data to constructors. Paired
records are skipped from the main record list.

| Record Type | Paired With | Indexed By |
|-------------|-------------|------------|
| BuiltInCommandRecord | stdout UserMessage | parent_uuid |
| UserDefinedCommandRecord | expanded prompt (isMeta) | parent_uuid |
| AssistantMessage.tool_call_records | tool_result UserMessage | tool_use_id |

Key design constraint: One JSONL line maps to 0-1 Record objects. ToolCallRecord
is not a Record subclass - it's a simple data class embedded in AssistantMessage
because a single assistant JSONL record can contain multiple tool_use blocks.

## Skipped Record Types

Some record types are skipped during parsing but must be handled carefully to
preserve the parentUuid chain. When a record is skipped, its children are
remapped to point to the skipped record's parent instead.

| Skipped Type | Reason |
|--------------|--------|
| file-history-snapshot | Checkpoint metadata, not conversation content |
| system | System events (e.g., /add-dir commands) |
| progress | Subagent execution updates |

## Rendering

SessionRenderer uses the visitor pattern to render threads. Each Record type
implements `render(renderer)` which calls the appropriate renderer method
(e.g., `render_user_message`, `render_assistant_message`). This decouples
record structure from output formatting.

```text
Thread#render(renderer)
  └── iterates over records
        └── record.render(renderer)
              ├── UserMessage → renderer.render_user_message
              ├── BuiltInCommandRecord → renderer.render_built_in_command
              ├── UserDefinedCommandRecord → renderer.render_user_defined_command
              └── AssistantMessage → renderer.render_assistant_message
```

Output format uses `<User>` and `<Assistant>` prefixes with timestamps:

```
[2025-01-07 19:30] <User> Hello world
[2025-01-07 19:31] <Assistant> Hi there!
[2025-01-07 19:31] <Assistant> Read(file.txt)
  ⎿  Read 10 lines
```
