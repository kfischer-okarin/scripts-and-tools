# Claude Code Conversation History Format Specification

**Version**: 1.2 (Based on Claude Code v2.1.263)
**Last Updated**: 2026-09-10
**Author**: Research analysis of actual Claude Code session files

> Sections below marked "as of v1.1" were written against v2.1.22 and have not
> been re-verified line by line. [Format coverage](#format-coverage) is the
> current, verified inventory — read it first where the two disagree.

---

## Table of Contents

1. [Overview](#overview)
2. [Format coverage](#format-coverage) — verified inventory, read first
3. [Directory Structure](#directory-structure)
4. [File Types](#file-types)
5. [JSONL Format](#jsonl-format)
6. [Record Types Reference](#record-types-reference)
7. [Message Tree Structure](#message-tree-structure)
8. [Session Lifecycle](#session-lifecycle)
9. [Agent Files](#agent-files)
10. [Special Cases](#special-cases)
11. [Implementation Notes](#implementation-notes)

---

## Overview

Claude Code stores conversation histories in JSONL (JSON Lines) format within the user's home directory. Each line is a self-contained JSON record representing a message, metadata, or system event.

**Key characteristics**:
- Conversations are stored as **trees, not linear sequences** (via `parentUuid` linking)
- Multiple file types serve different purposes (conversations, summaries, file history)
- Agent/subagent conversations are stored in separate files with `agent-` prefix
- Checkpoints and reverts create **branches** within the same file

---

## Format coverage

Verified on 2026-09-09 by parsing all 4205 session files under
`~/.claude/projects` (Claude Code v2.0.55 through v2.1.263) and collecting the
union of record types and top-level fields per type.

### Record types

| Type | Status | Seen in versions | Carries |
|------|--------|------------------|---------|
| `user` | current | 2.0.55 – 2.1.263 | prompts, tool results, command invocations, command output, interrupts, compaction summaries |
| `assistant` | current | 2.0.55 – 2.1.263 | `text`, `thinking` and `tool_use` content blocks |
| `system` | current | 2.0.56 – 2.1.263 | hook results, turn durations, compaction boundaries, **built-in slash commands** |
| `attachment` | current | 2.1.90 – 2.1.263 | context Claude Code injects into a turn; the most numerous type by far |
| `file-history-snapshot` | current | — | checkpoint metadata (full snapshot) |
| `file-history-delta` | current | — | checkpoint metadata (one tracked file) |
| `ai-title` | current | — | generated session title, rewritten each turn |
| `custom-title` | current | — | title the user set with `/rename` |
| `mode` | current | — | conversation mode |
| `permission-mode` | current | — | permission mode |
| `atis-latch` | current | — | status line state |
| `last-prompt` | current | — | `leafUuid` of the most recent prompt |
| `queue-operation` | current | — | a queued message being added or absorbed |
| `cost-state` | current | — | cumulative cost, duration and line counts |
| `agent-name` | current | — | name of a background agent |
| `pr-link` | current | — | pull request opened from the session |
| `frame-link` | current | — | published Artifact URL |
| `artifact-comment-monitor` | current | — | Artifact comment watch state |
| `artifact-autoreact-ledger` | current | — | Artifact auto-reply state |
| `summary` | **retired** | last written ~2026-02 | branch summary keyed by `leafUuid`; superseded by `ai-title` |
| `progress` | **retired** | 2.1.9 – 2.1.83 | subagent/hook progress; superseded by `attachment` |

Most of these types are **sidecar state** rather than conversation:
`ai-title`, `custom-title`, `mode`, `permission-mode`, `atis-latch`,
`last-prompt`, `queue-operation`, `cost-state`, `agent-name`, `pr-link`,
`frame-link` and the two `artifact-*` types carry no `uuid`, `parentUuid`,
`timestamp` or `version` — only `sessionId` and their own payload. They are
re-appended as the session progresses, so the newest of each sits nearest the
end of the file and the earlier copies are stale.

The remaining types are shaped like conversation records: `attachment` and the
retired `progress` carry the full envelope, while `summary` and
`file-history-snapshot` carry neither the envelope nor `sessionId` — see their
own sections for the fields they do have.

### Envelope fields

Records that are part of the conversation carry a common envelope:

```
type uuid parentUuid timestamp sessionId session_id cwd version gitBranch
entrypoint isSidechain isMeta userType sessionKind slug agentId forkedFrom
```

`session_id` duplicates `sessionId` in snake_case — both appear on the same
record. `slug` (a generated three-word session name) is no longer written;
`entrypoint`, `sessionKind`, `agentId` and `forkedFrom` are newer. `forkedFrom`
records the session and message a forked session branched from.

### Per-type fields, beyond the envelope

**`user`**: `message`, `toolUseResult`, `promptId`, `promptSource`, `origin`,
`permissionMode`, `queuePriority`, `queueSkipAttachments`, `imagePasteIds`,
`interruptedMessageId`, `sourceToolAssistantUUID`, `sourceToolUseID`,
`turnCompanion`, `toolDenialKind`, `mcpMeta`, `classifierMetaLines`,
`planContent`, `userFeedback`, `isCompactSummary`, `summarizeMetadata`,
`thinkingMetadata` (legacy), `todos` (legacy)

**`assistant`**: `message`, `requestId`, `effort`, `apiBlockIndex`,
`truncatedAfterOutput`, `attributionSkill`, `attributionPlugin`,
`attributionMcpServer`, `attributionMcpTool`, `apiErrorStatus`, `error`,
`errorDetails`, `healsDistinctCarrier`, `isApiErrorMessage`,
`isAbortedMidStream`

**`system`**: `subtype`, `level`, `content`, `toolUseID`, `durationMs`,
`messageCount`, `hasOutput`, `hookAdditionalContext`, `hookCount`, `hookErrors`,
`hookInfos`, `preventedContinuation`, `stopReason`,
`pendingBackgroundAgentCount`, `pendingWorkflowCount`, `compactMetadata`,
`microcompactMetadata`, `logicalParentUuid`, `cause`, `error`, `maxRetries`,
`retryAttempt`, `retryInMs`

### `system` subtypes

| Subtype | Meaning |
|---------|---------|
| `turn_duration` | how long a turn took |
| `stop_hook_summary` | result of Stop hooks |
| `local_command` | a built-in slash command's invocation markup, or its `<local-command-stdout>` |
| `compact_boundary` | where the context was compacted; `compactMetadata` holds trigger, token counts and preserved message uuids |
| `away_summary` | summary written while the user was away |

### `attachment` subtypes

`attachment.type` names what was injected. Observed:
`total_tokens_reminder`, `output_style`, `output_style_instructions`,
`hook_success`, `hook_additional_context`, `hook_system_message`,
`hook_non_blocking_error`, `batching_reminder_sent`, `bash_output_audience_note`,
`edited_text_file`, `file`, `opened_file_in_ide`, `selected_lines_in_ide`,
`selected_lines_in_diff`, `read_truncation_notice`, `diagnostics`,
`skill_listing`, `deferred_tools_delta`, `deferred_tools_record`,
`mcp_instructions_delta`, `agent_listing_delta`, `command_permissions`,
`queued_command`, `prompt_snapshot`, `environment`, `nested_memory`,
`session_context`, `instructions`, `model`, `directory`, `date`, `date_change`,
`auto_mode`, `silent_turn_reminder`, `task_reminder`, `fork_briefing`.

An attachment record's `parentUuid` is `null` even mid-conversation, so
attachments are not part of the message tree.

### `message.content` blocks

`user` content is either a string or an array of `text`, `image`, `document` or
`tool_result` blocks. `assistant` content is an array of `text`, `thinking` and
`tool_use` blocks.

### Known gaps

- **Nested shapes are only partly inventoried.** `toolUseResult` varies per
  tool, and the shapes are recorded here only for the tools whose output is
  read specially; `attachment` payloads, `hookInfos` and `compactMetadata` are
  not inventoried at all.
- **A tool result never names its tool.** `toolUseResult` carries no field
  identifying the tool that produced it; only the `tool_use_id` in the sibling
  content block connects it back to the call.
- **MCP tool results are the server's shape, not Claude Code's.** Records
  carrying them are marked with `mcpMeta`, which is the field to key off when a
  reader wants to hold them to a different standard.
- **Retirement dates are approximate.** They come from file modification times
  in one user's history, not from release notes.
- **Titles have an era gap.** `summary` stopped around 2026-02 and `ai-title`
  started around 2026-04, so sessions in between carry neither.

---

## Directory Structure

```
~/.claude/
└── projects/
    └── {encoded-project-path}/
        ├── {session-uuid}.jsonl           # Main conversation files
        ├── agent-{agent-id}.jsonl         # Agent/subagent conversations
        └── ... (multiple files per project)
```

### Project Path Encoding

The project directory name is the absolute path with `/` replaced by `-`:
- `/Users/kevin/myproject` → `-Users-kevin-myproject`

---

## File Types

### 1. Main Conversation Files (`{uuid}.jsonl`)

Primary conversation storage. Contains:
- User messages
- Assistant responses (text, thinking, tool_use)
- File history snapshots
- Inline summaries (sometimes)

**Identification**: UUID v4 format filename, does NOT start with `agent-`

**Size indicators**:
- 0 bytes: see [Empty Sessions](#empty-sessions)
- < 2KB: Likely metadata-only (summaries or file-history-snapshots only)
- > 2KB: Contains actual conversation

### 2. Summary Files (`{uuid}.jsonl`)

Contains only `type: "summary"` records (and sometimes `file-history-snapshot`).

**Identification**:
- Contains ONLY `type: "summary"` and/or `type: "file-history-snapshot"` records
- No `type: "user"` or `type: "assistant"` records
- Typically small (< 2KB)

### 3. File History Files (`{uuid}.jsonl`)

Contains only `type: "file-history-snapshot"` records.

**Identification**:
- Contains ONLY `type: "file-history-snapshot"` records
- No conversation content
- Created during checkpoint operations

### 4. Subagent Files

Since ~2026-03, a subagent's transcript is filed under the session that spawned
it, named by the agent id that session's tool result reports:

```
{project}/{session-uuid}/subagents/agent-{agent-id}.jsonl
{project}/{session-uuid}/subagents/agent-{agent-id}.meta.json
```

Older versions wrote them into the project directory as
`agent-{7-char-id}.jsonl`. A session directory also holds `tool-results/`, and
sometimes `workflows/`, `session-memory/` or `remote-agents/`.

See [Agent Files](#agent-files) for the fields.

---

## JSONL Format

Each file contains one JSON object per line. Lines are appended as the conversation progresses.

```jsonl
{"type":"file-history-snapshot",...}
{"parentUuid":null,"type":"user",...}
{"parentUuid":"abc123","type":"assistant",...}
{"parentUuid":"def456","type":"user",...}
```

**Important**: Records are NOT necessarily in chronological order after reverts/branches occur. Use `parentUuid` to reconstruct the tree.

---

## Record Types Reference

The field lists in this section are as of v1.1. See
[Per-type fields](#per-type-fields-beyond-the-envelope) for the current sets;
`slug` in particular is no longer written.

### 1. User Message Record

```json
{
  "type": "user",
  "uuid": "string (UUID v4)",
  "parentUuid": "string|null",
  "timestamp": "string (ISO 8601)",
  "sessionId": "string (UUID v4)",
  "message": {
    "role": "user",
    "content": "string | ContentBlock[]"
  },
  "cwd": "string (absolute path)",
  "version": "string (e.g., '2.0.74')",
  "gitBranch": "string|undefined",
  "slug": "string|undefined",
  "isSidechain": "boolean",
  "userType": "external",
  "isMeta": "boolean|undefined",
  "thinkingMetadata": "ThinkingMetadata|undefined",
  "toolUseResult": "ToolUseResult|undefined",
  "todos": "Todo[]|undefined"
}
```

#### `message.content` Variants

**Simple text message**:
```json
"content": "Hello, help me with something"
```

**Tool result message**:
```json
"content": [
  {
    "type": "tool_result",
    "tool_use_id": "toolu_xxx",
    "content": "string | ContentBlock[]"
  }
]
```

**Interrupt marker**: a single text block reading
`[Request interrupted by user]` — see
[Interrupted Response](#interrupted-response).

**Command invocation and output**: `<command-name>` tag markup, or a
`<local-command-stdout>` payload — see
[Command Messages](#command-messages).

#### `thinkingMetadata` Object

```json
{
  "level": "high|medium|low",
  "disabled": "boolean",
  "triggers": [
    {
      "start": "number (char position)",
      "end": "number (char position)",
      "text": "string (e.g., 'ultrathink')"
    }
  ]
}
```

#### `toolUseResult` Object

Attached to user messages that are tool results.

**For file creation**:
```json
{
  "type": "create",
  "filePath": "string",
  "content": "string",
  "structuredPatch": [],
  "originalFile": null
}
```

**For file edit**:
```json
{
  "type": "edit",
  "filePath": "string",
  "oldString": "string",
  "newString": "string",
  "originalFile": "string",
  "structuredPatch": [
    {
      "oldStart": "number",
      "oldLines": "number",
      "newStart": "number",
      "newLines": "number",
      "lines": ["string (prefixed with +/-/ )"]
    }
  ],
  "userModified": "boolean",
  "replaceAll": "boolean"
}
```

**For file read**:
```json
{
  "type": "text",
  "file": {
    "filePath": "string",
    "content": "string",
    "numLines": "number",
    "startLine": "number",
    "totalLines": "number"
  }
}
```

**For Task agent result**:
```json
{
  "status": "completed",
  "prompt": "string",
  "agentId": "string",
  "content": [{"type": "text", "text": "string"}],
  "totalDurationMs": "number",
  "totalTokens": "number",
  "totalToolUseCount": "number",
  "usage": { ... }
}
```

---

### 2. Assistant Message Record

```json
{
  "type": "assistant",
  "uuid": "string (UUID v4)",
  "parentUuid": "string",
  "timestamp": "string (ISO 8601)",
  "sessionId": "string (UUID v4)",
  "requestId": "string",
  "message": {
    "model": "string",
    "id": "string",
    "type": "message",
    "role": "assistant",
    "content": "ContentBlock[]",
    "stop_reason": "string|null",
    "stop_sequence": "string|null",
    "usage": "UsageObject",
    "context_management": "object|undefined"
  },
  "cwd": "string",
  "version": "string",
  "gitBranch": "string|undefined",
  "slug": "string|undefined",
  "isSidechain": "boolean",
  "userType": "external"
}
```

#### `message.content` Array Elements

**Text block**:
```json
{
  "type": "text",
  "text": "string"
}
```

**Thinking block**:
```json
{
  "type": "thinking",
  "thinking": "string",
  "signature": "string (base64)"
}
```

**Tool use block**:
```json
{
  "type": "tool_use",
  "id": "toolu_xxx",
  "name": "string (tool name)",
  "input": { ... },
  "caller": {
    "type": "direct"
  }
}
```

#### `message.usage` Object

```json
{
  "input_tokens": "number",
  "output_tokens": "number",
  "cache_creation_input_tokens": "number",
  "cache_read_input_tokens": "number",
  "cache_creation": {
    "ephemeral_5m_input_tokens": "number",
    "ephemeral_1h_input_tokens": "number"
  },
  "service_tier": "standard"
}
```

#### Streaming Behavior

Assistant responses are often written as **multiple records with the same `requestId`**:

1. First record: thinking block only
2. Second record: text block only
3. Third record: tool_use block only (if applicable)

All share the same `message.id` and `requestId`, but have different `uuid` values.

---

### 3. Summary Record

> **Retired** around 2026-02. Session titles now come from `ai-title` and
> `custom-title` records, which are keyed by `sessionId` rather than by a
> branch leaf.

```json
{
  "type": "summary",
  "summary": "string",
  "leafUuid": "string (UUID v4)"
}
```

**Fields**:
- `summary`: Human-readable description of the conversation branch
- `leafUuid`: UUID of the **last assistant message** in that branch

**Location**: Can appear in:
- Dedicated summary files
- Inline within main conversation files
- Mixed with file-history-snapshot records

**Behavior**:
- Multiple summaries can exist for different branches
- Same `leafUuid` may have different summary text in different files
- Updated/regenerated periodically (on session end or resume)

---

### 4. Progress Record

> **Retired** after v2.1.83. The same information now arrives as `attachment`
> records (`attachment.type` of `hook_success`, `hook_additional_context`, …).

```json
{
  "type": "progress",
  "uuid": "string (UUID v4)",
  "parentUuid": "string",
  "timestamp": "string (ISO 8601)",
  "sessionId": "string (UUID v4)",
  "data": {
    "type": "agent_progress",
    "agentId": "string (7-char)",
    "prompt": "string (original task prompt)",
    "message": {
      "type": "user|assistant",
      "timestamp": "string (ISO 8601)",
      "message": { ... },
      "uuid": "string (UUID v4)"
    },
    "normalizedMessages": []
  },
  "toolUseID": "string",
  "parentToolUseID": "string",
  "cwd": "string",
  "version": "string",
  "gitBranch": "string|undefined",
  "slug": "string|undefined",
  "isSidechain": "boolean",
  "userType": "external"
}
```

**Purpose**: Track real-time progress of subagent execution. These records are
interspersed in the main conversation's parentUuid chain during Task tool
execution.

**Key characteristics**:
- `data.type` is `"agent_progress"`
- `data.agentId` identifies which subagent is running
- `data.message` contains the nested subagent message (user or assistant)
- `toolUseID` links to the Task tool_use block that spawned the agent
- Records chain via parentUuid like regular messages

---

### 5. File History Snapshot Record

```json
{
  "type": "file-history-snapshot",
  "messageId": "string (UUID v4)",
  "snapshot": {
    "messageId": "string (UUID v4)",
    "trackedFileBackups": {
      "{filename}": {
        "backupFileName": "string|null",
        "version": "number",
        "backupTime": "string (ISO 8601)"
      }
    },
    "timestamp": "string (ISO 8601)"
  },
  "isSnapshotUpdate": "boolean"
}
```

**Purpose**: Tracks file versions for checkpoint/revert functionality.

**Fields**:
- `messageId`: Links to the user message this snapshot is associated with
- `trackedFileBackups`: Map of filename → backup metadata
- `backupFileName`: Format `{hash}@v{version}` (e.g. `d95c0fbaebe97e88@v2`), or
  `null` for the initial version; the version increments on each edit
- `isSnapshotUpdate`: `true` if updating existing snapshot, `false` if new

The backup files themselves live outside the project directory (apparently
under `~/.claude/file-history/`).

---

## Message Tree Structure

`parentUuid` is what creates the structure.

### Root Message
```json
{"parentUuid": null, "uuid": "msg-1", ...}
```

### Linear Sequence
```
msg-1 (parentUuid: null)
  └── msg-2 (parentUuid: msg-1)
       └── msg-3 (parentUuid: msg-2)
```

### Branching (after revert)
```
msg-1 (parentUuid: null)
  └── msg-2 (parentUuid: msg-1)
       ├── msg-3 (parentUuid: msg-2) [Branch A]
       │    └── msg-4 (parentUuid: msg-3)
       │
       └── msg-5 (parentUuid: msg-2) [Branch B - after revert]
            └── msg-6 (parentUuid: msg-5)
```

### Reconstruction Algorithm

```python
def build_tree(records):
    nodes = {r['uuid']: r for r in records if 'uuid' in r}
    children = defaultdict(list)
    roots = []

    for uuid, record in nodes.items():
        parent = record.get('parentUuid')
        if parent is None:
            roots.append(uuid)
        else:
            children[parent].append(uuid)

    return roots, children, nodes

def get_branch(nodes, children, leaf_uuid):
    """Get linear path from root to leaf"""
    path = []
    current = leaf_uuid
    while current:
        path.append(nodes[current])
        current = nodes[current].get('parentUuid')
    return list(reversed(path))
```

### Finding Branch Endpoints

A message is a branch endpoint if it has no children. In files written before
~2026-02, a `summary` record's `leafUuid` also pointed at one.

---

## Session Lifecycle

### New Session

1. New `{uuid}.jsonl` file created
2. `file-history-snapshot` record written (if files exist)
3. User message written (parentUuid: null)
4. Assistant response(s) written

### Resume Session (`claude --resume`)

1. New messages appended to existing file
2. `parentUuid` links to last message of previous session

### Resume with No Action

1. New `{uuid}.jsonl` file created (empty, 0 bytes)
2. No records written

### Checkpoint Revert (code + conversation)

1. `file-history-snapshot` written to new or existing file
2. Next user message has `parentUuid` pointing to earlier message
3. Creates a branch in the tree

### Conversation-Only Revert

1. Similar to checkpoint revert
2. File changes persist, only conversation state reverts

### /clear Command

1. Current conversation continues in original file
2. `/clear` logged as a command record — a `system` record with
   `subtype: "local_command"` in current versions, a `user` record with
   `<command-name>` markup before that; not `isMeta` in either case
3. New session file created
4. New session becomes active

---

## Agent Files

### File Naming

```
agent-{7-char-id}.jsonl
```

The 7-character ID (e.g., `a434715`) is used to identify and resume agents.

### Common Fields

All agent records have:
```json
{
  "isSidechain": true,
  "agentId": "string (7-char)",
  "sessionId": "string (parent session UUID)"
}
```

### Task Agents

An agent file holds one subagent's conversation: its task prompt, then real
conversation with tool usage. Its `agentId` is referenced in the parent
session's tool result.

Until ~2026-01, Claude Code also wrote **warmup agent** files — internal
probes whose first message was exactly `"Warmup"`, created in haiku/opus pairs,
which readers had to filter out. None have been written since.

---

## Special Cases

### Interrupted Response

When user presses Escape/Ctrl+C during response:

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [{"type": "text", "text": "[Request interrupted by user]"}]
  }
}
```

As of v1.1 no partial assistant response was saved. Current assistant records
carry `isAbortedMidStream` and `truncatedAfterOutput`, so a partial response
can now be written — treat the flags as the authority.

### Meta Messages

System messages not part of conversation flow:

```json
{
  "type": "user",
  "isMeta": true,
  "message": {
    "content": "Caveat: The messages below were generated..."
  }
}
```

### Command Messages

Slash commands are logged as user messages with XML-like tags:

```json
{
  "type": "user",
  "uuid": "b981afe9-...",
  "message": {
    "content": "<command-name>/clear</command-name>\n<command-message>clear</command-message>\n<command-args></command-args>"
  }
}
```

**Content structure**:
- `<command-name>`: The slash command (e.g., `/clear`, `/init`)
- `<command-message>`: Display name of the command
- `<command-args>`: Command arguments (may be empty)

#### Built-in Commands (with stdout)

> **Moved.** Built-in commands are now logged as `system` records with
> `subtype: "local_command"`, whose `content` holds the same invocation markup
> or the `<local-command-stdout>` payload. User-defined slash commands are
> still `user` records as described below. A reader that skips `system` records
> misses every built-in command invocation.

As of v1.1, built-in commands like `/clear` produced a child stdout message:

```json
{
  "type": "user",
  "parentUuid": "b981afe9-...",
  "uuid": "e8e28ecc-...",
  "message": {
    "content": "<local-command-stdout>output here</local-command-stdout>"
  }
}
```

**Key characteristics**:
- The stdout message's `parentUuid` points directly to the command message's `uuid`
- Timestamps are typically milliseconds apart
- Stdout content may be empty (`<local-command-stdout></local-command-stdout>`)

#### User-Defined Slash Commands (with expanded prompt)

User-defined slash commands (skills) produce a child message with the expanded prompt:

```json
{
  "type": "user",
  "parentUuid": "b8f5ed6b-...",
  "isMeta": true,
  "message": {
    "content": [{"type": "text", "text": "# Review Instructions\n\nYou are an expert..."}]
  }
}
```

**Key characteristics**:
- Has `isMeta: true` (distinguishes from regular user messages)
- Content is an array with a text block, not a simple string
- Contains the full expanded skill prompt
- No `<local-command-stdout>` message is produced

#### System Command Variant

Some commands appear as system records instead of user records:

```json
{
  "type": "system",
  "subtype": "local_command",
  "content": "<command-name>/add-dir</command-name>\n<command-message>add-dir</command-message>\n<command-args></command-args>",
  "uuid": "bdfd8daf-..."
}
```

**Differences from user-type commands**:
- `type` is `"system"` instead of `"user"`
- Has `subtype: "local_command"`
- Content is at top level, not wrapped in a `message` object
- The output arrives as a second `local_command` record whose `content` is the
  `<local-command-stdout>` payload, rather than as a child user message

This is the shape **every** built-in command now takes; see the note under
[Built-in Commands](#built-in-commands-with-stdout) above.

### Empty Sessions

A 0-byte `{uuid}.jsonl` file is created by `claude --resume` or
`claude --continue` when no action follows. No records are ever written to it,
so it should be filtered from session listings.

---

## Implementation Notes

> One way to read these files. `claude-history` takes a different one: it
> prints every line in file order, so the commands, interrupts and compaction
> boundaries filtered out below are transcript lines for it. See
> `docs/design.md`.

### Filtering for Display

One approach to picking out "real" conversation content:

```python
def is_displayable_message(record):
    if record.get('type') not in ('user', 'assistant'):
        return False
    if record.get('isMeta'):
        return False

    # Check for interrupt marker
    content = record.get('message', {}).get('content', '')
    if isinstance(content, list):
        for block in content:
            if block.get('text') == '[Request interrupted by user]':
                return False  # Or handle specially

    # Check for command messages
    if isinstance(content, str) and content.startswith('<command-name>'):
        return False

    return True
```

## Appendix: Known Models

`message.model` values observed in session files, most frequent first:
`claude-opus-4-5-20251101`, `claude-opus-4-7`, `claude-opus-4-6`,
`claude-opus-4-8`, `claude-opus-5`, `claude-fable-5`,
`claude-haiku-4-5-20251001`, `claude-sonnet-4-5-20250929`,
`claude-sonnet-4-6`, `claude-sonnet-5`, and `<synthetic>` for records Claude
Code generates itself rather than receiving from the API.

Newer ids drop the date suffix that the 4.5 generation carried, and a context
variant appears in brackets (`claude-opus-5[1m]`). Treat the list as a sample,
not a closed set.

---

## Appendix: Tool Names

Common tool names observed:

- `Read` - Read file contents
- `Write` - Create new file
- `Edit` - Modify existing file
- `Bash` - Execute shell command
- `Glob` - Find files by pattern
- `Grep` - Search file contents
- `Task` - Spawn subagent
- `TodoWrite` - Update todo list
- `WebFetch` - Fetch URL content
- `WebSearch` - Search the web

---

## Changelog

- **1.2** (2026-09-10): Added the [Format coverage](#format-coverage) inventory
  verified against v2.1.263: 19 current record types (15 of them previously
  undocumented, `attachment` chief among them), the shared envelope field set,
  per-type fields, `system` and `attachment` subtypes. Marked `summary`,
  `progress` and warmup agent files retired, and noted that built-in slash
  commands moved into `system` records. Deleted the Summary System, File
  History Snapshots and most Implementation Notes sections, which restated the
  record-type sections or documented retired formats, and refreshed the model
  appendix.
- **1.1** (2026-01-30): Added `progress` record type documentation (subagent execution updates)
- **1.0** (2025-12-20): Initial specification based on analysis of Claude Code v2.0.74 session files
