# Design

## Architecture

```text
CLI (Thor, humble object - just delegates to History)
  └── History (main API, exposes all functionality)
        └── Project (one per working directory, e.g., "-Users-user-myproject")
              └── Session (one per JSONL file, identified by UUID)
                    └── Record (base class for parsed lines)
                          ├── UserMessage
                          ├── AssistantMessage
                          └── Summary
```

Development is behavior-driven from the History object - new CLI features start
as History tests, which drive out the underlying Project/Session/Record
functionality.
