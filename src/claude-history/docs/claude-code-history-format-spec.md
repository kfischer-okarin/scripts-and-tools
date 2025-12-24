# Claude Code Conversation History Format Specification

**Version**: 1.0 (Based on Claude Code v2.0.74)
**Last Updated**: 2025-12-20
**Author**: Research analysis of actual Claude Code session files

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [File Types](#file-types)
4. [JSONL Format](#jsonl-format)
5. [Record Types Reference](#record-types-reference)
6. [Message Tree Structure](#message-tree-structure)
7. [Session Lifecycle](#session-lifecycle)
8. [Agent Files](#agent-files)
9. [Summary System](#summary-system)
10. [File History Snapshots](#file-history-snapshots)
11. [Special Cases](#special-cases)
12. [Implementation Notes](#implementation-notes)

---

## Overview

Claude Code stores conversation histories in JSONL (JSON Lines) format within the user's home directory. Each line is a self-contained JSON record representing a message, metadata, or system event.

**Key characteristics**:
- Conversations are stored as **trees, not linear sequences** (via `parentUuid` linking)
- Multiple file types serve different purposes (conversations, summaries, file history)
- Agent/subagent conversations are stored in separate files with `agent-` prefix
- Checkpoints and reverts create **branches** within the same file

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
- 0 bytes: Empty session (created by `--resume`/`--continue` with no action)
- < 2KB: Likely metadata-only (summaries or file-history-snapshots only)
- > 2KB: Contains actual conversation

### 2. Summary Files (`{uuid}.jsonl`)

Contains only `type: "summary"` records (and sometimes `file-history-snapshot`).

**Identification**:
- Contains ONLY `type: "summary"` and/or `type: "file-history-snapshot"` records
- No `type: "user"` or `type: "assistant"` records
- Typically small (< 2KB)

**Purpose**: Track summaries for different conversation branches across sessions.

### 3. File History Files (`{uuid}.jsonl`)

Contains only `type: "file-history-snapshot"` records.

**Identification**:
- Contains ONLY `type: "file-history-snapshot"` records
- No conversation content
- Created during checkpoint operations

### 4. Agent Files (`agent-{agent-id}.jsonl`)

Subagent conversation logs. Two categories:

**a) Warmup Agents (internal)**
- First message content is exactly `"Warmup"`
- Models: `claude-haiku-4-5-*` or `claude-opus-4-5-*`
- Should be filtered out for user-facing history

**b) Task Agents (user-triggered)**
- First message contains actual task prompt
- Model: typically `claude-sonnet-4-5-*`
- `isSidechain: true`
- Contains real conversation with tool usage

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

**Interrupt marker**:
```json
"content": [{"type": "text", "text": "[Request interrupted by user]"}]
```

**Command message** (e.g., /clear):
```json
"content": "<command-name>/clear</command-name>\n<command-message>clear</command-message>\n<command-args></command-args>"
```

**Command output**:
```json
"content": "<local-command-stdout></local-command-stdout>"
```

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

### 4. File History Snapshot Record

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
- `backupFileName`: Format `{hash}@v{version}` or `null` for initial version
- `isSnapshotUpdate`: `true` if updating existing snapshot, `false` if new

---

## Message Tree Structure

Conversations are **trees**, not linear sequences. The `parentUuid` field creates the structure.

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

A message is a branch endpoint if:
- It has no children, OR
- It's referenced by a `summary` record's `leafUuid`

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
3. New warmup agents may be created

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
2. `/clear` command logged with `isMeta: true`
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

### Warmup Agents (Filter These)

**Identification**:
```python
def is_warmup_agent(records):
    first_user = next((r for r in records if r.get('type') == 'user'), None)
    if first_user:
        content = first_user.get('message', {}).get('content', '')
        return content == 'Warmup'
    return False
```

**Characteristics**:
- Created in pairs (one haiku, one opus typically)
- Models: `claude-haiku-4-5-*`, `claude-opus-4-5-*`
- Only contain "Warmup" message and greeting response
- Internal system mechanism, not user-visible

### Task Agents (Include These)

**Identification**:
- First message is NOT "Warmup"
- Contains actual task description

**Characteristics**:
- Model: typically `claude-sonnet-4-5-*`
- Contains real conversation with tool usage
- `agentId` referenced in parent session's tool result

---

## Summary System

### Summary Generation

Summaries are generated:
- When session ends (user exits Claude Code)
- When session is resumed
- Periodically during long sessions
- After significant conversation events

### Storage Locations

1. **Dedicated summary files**: Contain multiple summaries for different branches
2. **Inline in main file**: Single summary record within conversation
3. **Mixed files**: Summaries + file-history-snapshots

### Linking to Conversations

The `leafUuid` field links to the last assistant message UUID in a branch:

```
Summary File                    Main Conversation File
─────────────                   ──────────────────────
leafUuid: "abc123"  ──────────► uuid: "abc123" (assistant message)
```

### Multiple Branches

Each branch endpoint gets its own summary entry:

```json
{"type":"summary","summary":"First feature","leafUuid":"branch1-end"}
{"type":"summary","summary":"Bug fix work","leafUuid":"branch2-end"}
{"type":"summary","summary":"Refactoring","leafUuid":"branch3-end"}
```

---

## File History Snapshots

### Purpose

Track file versions for checkpoint/revert functionality. Allows Claude Code to restore files to previous states.

### Backup File Location

Backup files are stored separately (likely in `~/.claude/file-history/` or similar).

Format: `{hash}@v{version}` (e.g., `d95c0fbaebe97e88@v2`)

### Snapshot Lifecycle

1. **Initial**: `backupFileName: null`, `version: 1`
2. **After edit**: `backupFileName: "{hash}@v2"`, `version: 2`
3. **Subsequent edits**: Version increments

### Association with Messages

`messageId` links snapshot to the user message that triggered file tracking:

```
file-history-snapshot.messageId ──► user message.uuid
```

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

**No partial assistant response is saved.**

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

Built-in commands like `/clear` produce a child stdout message:

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
- Content is at top level, not wrapped in `message` object
- Typically used for IDE/workspace commands (e.g., `/add-dir`)

The same parent-child stdout pattern applies to system commands

### Empty Sessions

Files with 0 bytes exist when:
- `claude --resume` or `claude --continue` with no action taken
- Should be filtered from session listings

---

## Implementation Notes

### Filtering for Display

To get "real" conversation content:

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

### Counting Messages

Only count records where:
- `type` is `"user"` or `"assistant"`
- `isMeta` is not `true`
- Content is not interrupt marker or command

### Session Classification

```python
def classify_session_file(filepath):
    records = load_jsonl(filepath)

    if not records:
        return 'empty'

    types = {r.get('type') for r in records}

    if types <= {'summary'}:
        return 'summary-only'

    if types <= {'file-history-snapshot'}:
        return 'file-history-only'

    if types <= {'summary', 'file-history-snapshot'}:
        return 'metadata-only'

    if 'user' in types or 'assistant' in types:
        return 'conversation'

    return 'unknown'
```

### Agent Classification

```python
def classify_agent_file(filepath):
    records = load_jsonl(filepath)

    first_user = next(
        (r for r in records if r.get('type') == 'user'),
        None
    )

    if not first_user:
        return 'incomplete'

    content = first_user.get('message', {}).get('content', '')

    if content == 'Warmup':
        return 'warmup'  # Filter out

    return 'task'  # Include
```

### Getting Latest Summary

```python
def get_best_summary(project_dir, session_id):
    """Get the most recent summary for a session."""
    summaries = []

    for filepath in project_dir.glob('*.jsonl'):
        for record in load_jsonl(filepath):
            if record.get('type') == 'summary':
                summaries.append({
                    'file': filepath,
                    'mtime': filepath.stat().st_mtime,
                    'summary': record.get('summary'),
                    'leafUuid': record.get('leafUuid')
                })

    if not summaries:
        return None

    # Return summary from most recently modified file
    return max(summaries, key=lambda s: s['mtime'])
```

### Reconstructing a Branch for Display

```python
def get_displayable_branch(records, leaf_uuid=None):
    """Get messages for display, following one branch."""

    # Build tree
    nodes = {r['uuid']: r for r in records if 'uuid' in r}
    children = defaultdict(list)

    for uuid, record in nodes.items():
        parent = record.get('parentUuid')
        if parent:
            children[parent].append(uuid)

    # Find leaf (latest message if not specified)
    if not leaf_uuid:
        # Find nodes with no children
        leaves = [u for u in nodes if u not in children or not children[u]]
        if not leaves:
            return []
        # Pick most recent
        leaf_uuid = max(leaves, key=lambda u: nodes[u].get('timestamp', ''))

    # Walk back to root
    path = []
    current = leaf_uuid
    while current and current in nodes:
        record = nodes[current]
        if is_displayable_message(record):
            path.append(record)
        current = record.get('parentUuid')

    return list(reversed(path))
```

---

## Appendix: Known Models

Models observed in session files:

| Model ID | Usage |
|----------|-------|
| `claude-opus-4-5-20251101` | Main conversation, planning agents |
| `claude-sonnet-4-5-20250929` | Task agents (default) |
| `claude-haiku-4-5-20251001` | Warmup agents, lightweight tasks |

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

- **1.0** (2025-12-20): Initial specification based on analysis of Claude Code v2.0.74 session files
