# Claude Code History Test Project

**Location**: `~/.claude/projects/-Users-user-project/`
**Date**: 2025-12-20
**Purpose**: Test and document how Claude Code stores conversation history, including branching, checkpoints, reverts, agents, and edge cases.

---

## Overview

This test project was created to understand the internal storage format of Claude Code conversation histories. The user performed a series of deliberate actions to trigger various storage behaviors.

---

## Timeline of Events

### Phase 1: Initial Conversation (Main Session)

**Session ID**: `b3edadab-bca0-4054-9b41-f7ffa6941260`
**Slug**: `giggly-greeting-moler`

1. **User**: "Hello I want to have some test conversation with you create some file for me"

2. **Claude**: Created `test-file.txt` with initial content:
   ```
   This is a test file created by Claude.

   Hello from the conversation!
   ```

3. **User**: "ok edit it and add some content"

4. **Claude**: Added a list and closing line:
   ```
   Here is some additional content:
   - Item one
   - Item two
   - Item three

   This file was edited during our test session.
   ```

### Phase 2: Task Agent Test

5. **User**: "Ok now make a task agent that will add some content too so I can test how those agent threads are handled"

6. **Claude**: Spawned Task agent `a434715`

7. **Task Agent** (in `agent-a434715.jsonl`): Read the file and appended:
   ```
   --- Added by Task Agent ---
   This section was appended by a Task agent during automated processing.
   The Task agent successfully completed its objective of modifying this file.
   Timestamp: 2025-12-20
   Status: Operation completed successfully
   ```

### Phase 3: First Checkpoint Test (Code + Conversation Revert)

8. **User**: "Ok make another addition which I will revert later via the checkpoint feature"

9. **Claude**: Added section ending with "Goodbye soon!":
   ```
   --- This section will be reverted ---
   This content is temporary and will be removed via checkpoint revert.
   Testing the checkpoint/revert functionality.
   Goodbye soon!
   ```

10. **User**: Performed **checkpoint revert** (both code AND conversation)
    - This created **Branch 1** endpoint at the "Goodbye soon!" message
    - Conversation forked back to the state after the Task agent addition
    - File was reverted to remove the "Goodbye soon!" section

### Phase 4: Second Branch (Conversation Revert Test)

11. **User**: "Ok I came from the future where you added and i reverted via checkpoint now add another section where I will only revert the conversation so you will lose knowledge of it only"

12. **Claude**: Added a new section:
    ```
    --- Section for Conversation Revert Test ---
    This section was added to test conversation-level reverts.
    After reverting, Claude will lose knowledge of adding this,
    but the file change may or may not persist depending on the test.
    Added at: 2025-12-20
    ```

13. **User**: Performed **conversation-only revert**
    - This created **Branch 2** endpoint
    - Conversation forked back
    - File changes persisted on disk

### Phase 5: Third Branch (Post Conversation Revert)

14. **User**: "Ok in the future some new content was added look at it"

15. **Claude**: Read the file and observed the "Section for Conversation Revert Test" that it had no memory of adding. Commented: "Interesting test case!"
    - This created **Branch 3** endpoint

### Phase 6: /clear Test

16. **User**: Exited and started new session, said "Hi"

17. **Claude**: "Hey Okarin! What can I help you with?"
    - This extended the main session to **Branch 4**

18. **User**: Ran `/clear` command
    - New session `0d3b22c1-*` was created
    - `/clear` command was logged with `isMeta: true`
    - Original session file preserved (NOT deleted)

### Phase 7: Interrupt Test

19. **User**: Resumed the original session (pre-clear), asked:
    "Ok ultrathink and come up with a chain of cause and effect relationships spanning at least 20 steps that links today to the second world war"

20. **User**: Interrupted the response mid-generation (pressed Escape/Ctrl+C)
    - No partial Claude response was saved
    - Interrupt marker logged: `[Request interrupted by user]`

21. **User**: "Ok ultrathink and try again"

22. **Claude**: Generated a 24-step causal chain from WWII to the current conversation
    - This created **Branch 5** (the latest endpoint)

---

## Resulting File Structure

### Main Conversation Files

| File | Size | Content |
|------|------|---------|
| `b3edadab-*.jsonl` | 75KB | Main conversation with all 5 branches |
| `0d3b22c1-*.jsonl` | 1.7KB | /clear session (command log only) |
| `0f13eeba-*.jsonl` | 0B | Empty (resume with no action) |
| `34d48ba8-*.jsonl` | 0B | Empty (resume with no action) |

### Metadata Files

| File | Content |
|------|---------|
| `be89c3cd-*.jsonl` | Summaries for branches 1, 2, 3 |
| `a751b8dd-*.jsonl` | Summaries + file-history-snapshots |
| `3f6ddfee-*.jsonl` | Summaries including branch 5 (latest) |
| `6d3dc917-*.jsonl` | File-history-snapshots only |
| `b8649630-*.jsonl` | File-history-snapshots only |
| `e9040aa9-*.jsonl` | File-history-snapshots only |

### Agent Files

| File | Type | Content |
|------|------|---------|
| `agent-a434715.jsonl` | **Task Agent** | Real agent that edited the file |
| `agent-a4e24f0.jsonl` | Warmup | Internal system probe |
| `agent-a6e784a.jsonl` | Warmup | Internal system probe |
| `agent-a1fd30c.jsonl` | Warmup | Internal system probe |
| `agent-a4eb314.jsonl` | Warmup | Internal system probe |
| `agent-a0d87c4.jsonl` | Warmup | Internal system probe |
| `agent-a1593bc.jsonl` | Warmup (incomplete) | Only has "Warmup" message |
| `agent-a86dcdc.jsonl` | Warmup (incomplete) | Only has "Warmup" message |
| `agent-a8a15e2.jsonl` | Warmup | Internal system probe |
| `agent-a7b5cd5.jsonl` | Warmup | Internal system probe |
| `agent-aa948db.jsonl` | Warmup | Internal system probe |
| `agent-ac234b8.jsonl` | Warmup | Internal system probe |
| `agent-afb67bf.jsonl` | Warmup | Internal system probe |
| `agent-a2b48bc.jsonl` | Warmup | Created after resume |
| `agent-adfec6b.jsonl` | Warmup | Created after resume |

---

## Conversation Tree Visualization

```
ROOT: "Hello I want to have some test conversation..."
  │
  ├── Created test-file.txt
  │
  ├── "ok edit it and add some content"
  │     └── Added list items
  │
  ├── "Ok now make a task agent..."
  │     └── Task agent a434715 added content
  │
  └── [FORK POINT: After Task agent response]
        │
        ├── BRANCH 1: "Ok make another addition..."
        │     └── Added "Goodbye soon!" section
        │         └── [END - leafUuid: 51be2f36]
        │
        ├── BRANCH 2: "Ok I came from the future..."
        │     └── Added "Conversation Revert Test" section
        │         └── [END - leafUuid: 39a76b25]
        │
        ├── BRANCH 3: "Ok in the future some new content..."
        │     └── Claude observed file, said "Interesting test case!"
        │         └── [END - leafUuid: a625e20b]
        │
        ├── BRANCH 4: "Hi" (after resume)
        │     └── "Hey Okarin! What can I help you with?"
        │         └── [END - leafUuid: feae9236]
        │
        └── BRANCH 5: "Ok ultrathink..." (after interrupt + retry)
              ├── [Interrupted - no response saved]
              └── "Ok ultrathink and try again"
                    └── 24-step WWII chain
                        └── [END - leafUuid: 38842167]
```

---

## Key Observations

### 1. Branching Behavior
- Checkpoint reverts create new branches, not deletions
- All branches remain in the same file
- `parentUuid` links back to the fork point

### 2. /clear Does Not Delete
- Creates a new session file
- Logs the command with `isMeta: true`
- Original session completely preserved

### 3. Interrupt Handling
- No partial response is saved
- Special marker: `[Request interrupted by user]`
- Next message chains from interrupt marker

### 4. Agent Proliferation
- Many "Warmup" agents are created automatically
- Only 1 of 15 agent files was a real user-triggered Task agent
- Warmup agents identifiable by `"content": "Warmup"` as first message

### 5. Summary Distribution
- Summaries stored in separate files
- Updated/regenerated on session events
- Each branch endpoint gets its own summary entry
- Same leafUuid can have slightly different summary text

### 6. File History Tracking
- Snapshots created at each checkpoint
- Track file versions for revert capability
- `backupFileName` format: `{hash}@v{version}`

---

## Test File Final State

The file `test-file.txt` ended up with this content (after all operations):

```
This is a test file created by Claude.

Hello from the conversation!

Here is some additional content:
- Item one
- Item two
- Item three

This file was edited during our test session.

--- Added by Task Agent ---
This section was appended by a Task agent during automated processing.
The Task agent successfully completed its objective of modifying this file.
Timestamp: 2025-12-20
Status: Operation completed successfully

--- Section for Conversation Revert Test ---
This section was added to test conversation-level reverts.
After reverting, Claude will lose knowledge of adding this,
but the file change may or may not persist depending on the test.
Added at: 2025-12-20
```

Note: The "Goodbye soon!" section was reverted and does not appear in the final file, but the "Conversation Revert Test" section persisted because only the conversation was reverted, not the code.

---

## Reproduction Steps

To recreate this test scenario:

1. Create a new directory and `cd` into it
2. Start Claude Code: `claude`
3. Ask Claude to create and edit a file
4. Ask Claude to spawn a Task agent to modify the file
5. Make another edit, then use checkpoint revert (code + conversation)
6. Make another edit, then use conversation-only revert
7. Ask Claude to look at the file
8. Resume the session and send a message
9. Run `/clear`
10. Resume the pre-clear session
11. Send a long-running request and interrupt it
12. Retry the request

Each step will create specific patterns in the session files that can be analyzed.
