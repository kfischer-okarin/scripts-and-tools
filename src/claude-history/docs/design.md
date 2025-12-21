# Design

## Architecture

```text
CLI (Thor, humble object - just delegates to History)
  └── History (main API, exposes all functionality)
        └── Project (one per working directory, e.g., "-Users-user-myproject")
              └── Session (logical session: aggregates conversation tree across files)
                    └── Record (base class for parsed lines)
                          ├── UserMessage
                          ├── AssistantMessage
                          └── Summary
```

Note: A Session aggregates all records connected via `parentUuid` chain, which
may span multiple JSONL files. The session ID comes from the file containing the
root record. This differs from the physical CLI session (the JSONL filename).

Development is behavior-driven from the History object - new CLI features start
as History tests, which drive out the underlying Project/Session/Record
functionality.
