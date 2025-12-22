# Design

## Architecture

```text
CLI (Thor, humble object - just delegates to History)
  └── History (main API, exposes all functionality)
        └── Project (one per working directory, e.g., "-Users-user-myproject")
              └── Session (logical session: aggregates conversation tree across files)
                    ├── Record (base class for parsed lines)
                    │     ├── UserMessage
                    │     ├── AssistantMessage
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
