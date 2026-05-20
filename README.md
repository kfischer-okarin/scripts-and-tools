# Scripts and Tools

Collection of tools and scripts made for personal use

## `extend-loop`

A Python script for extending audio files by looping a specific section until a
target duration is reached. Perfect for creating hour-long ambient music from
shorter tracks.

The script takes an audio file and:

1. Plays the beginning up to the loop start point
2. Repeatedly loops a specified section until the minimum length is reached
3. Plays the remainder of the original file after the loop end point

Preserves the original codec and bitrate when possible. Supports flexible time
formats (e.g., `1:30.5`, `90s`, `1h`).

**Usage:**

```bash
./bin/extend-loop -i input.mp3 --loop-start 0:18.744 --loop-end 1:52.563 --min-length 1h --output extended.mp3
```

## `transcribe-audio`

Transcribes an audio file using `mlx-whisper` on Apple Silicon. Uses
`kaiinui/kotoba-whisper-v2.0-mlx` for Japanese and
`mlx-community/whisper-large-v3-turbo` for everything else. Live-prints each
segment with timestamps as it decodes, and writes `.txt`, `.vtt`, `.srt`,
`.tsv`, and `.json` files next to the input.

**Usage:**

```bash
transcribe-audio path/to/audio.mp3 --lang en
transcribe-audio path/to/audio.mp3 --lang ja
```

## `is-mic-on` / `is-camera-on`

Swift utilities to check if the microphone or camera is currently in use on
macOS. Returns exit code 0 if in use, 1 if not. Use `-q` for quiet mode (exit
code only).

## `claude-history`

A Ruby CLI tool for searching and displaying Claude Code conversation histories
from `~/.claude/projects/`. Parses JSONL session files into structured data,
browse sessions by project, view full transcripts with timestamps, and search
activity by date.

**Usage:**

```bash
claude-history projects                              # List all projects
claude-history sessions --project myproject           # List sessions in a project
claude-history show-session SESSION_ID --project myproject  # Display a transcript
claude-history sessions-updated-on 2025-04-12         # Find sessions by date
```

## `format-md`

Formats markdown files in-place. Wraps prose paragraphs and list items at 80
columns (preserving list continuation indent), leaves fenced and indented code
blocks alone, and never splits inline backtick spans. Pads table columns to
uniform width, wraps wide tables in `<!-- markdownlint-disable MD013 -->`
comments, and removes the wrapper from tables that no longer need it. All width
calculations are Unicode display-width aware (CJK and emoji count as 2 columns).
Finally runs `markdownlint-cli2 --fix` for general cleanup. Tables that fail to
parse are left untouched.

**Usage:**

```bash
format-md file1.md file2.md
```

## `joplin`

A Ruby CLI for the Joplin note-taking app that communicates with Joplin's REST
API. Supports listing notebooks/notes, searching, creating and managing
notes/folders, adding and removing tags, and updating note content and metadata.

**Usage:**

```bash
export JOPLIN_TOKEN=your_token_from_joplin_settings
joplin folders                              # List all notebooks
joplin search "query"                       # Search notes
joplin create-note <folder-id> "Title" "Body"  # Create note
```

## `with-secure-env`

A CLI tool for launching processes with encrypted environment variables. Stores
secrets securely in the macOS Keychain and prompts for approval before
injection, preventing plain-text `.env` files from being scattered around the
filesystem. Available in both Go and Ruby implementations.

**Usage:**

```bash
with-secure-env init                      # Generate and store encryption key
with-secure-env edit /path/to/app         # Edit envs for an application
with-secure-env launch /path/to/app args  # Launch with injected envs
```

## `worktime`

Command-line tool for tracking work sessions, breaks, and lunch to generate
timesheet data for employer reporting. Records start/stop events and
automatically calculates daily and monthly work hours with overtime tracking.

**Usage:**

```bash
worktime start              # Start a work session
worktime stop               # End work
worktime lunch              # Toggle lunch break
worktime status [DATE]      # Show current status
worktime month [MONTH]      # Show monthly overview with overtime
```

## `hammerspoon-spoons/`

Custom Hammerspoon Spoons for macOS automation.
