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

Transcribes an audio file using `mlx-whisper` on Apple Silicon, with
`mlx-community/whisper-large-v3-turbo`. Live-prints each segment with
timestamps as it decodes, and writes `.txt`, `.vtt`, `.srt`, `.tsv`, and
`.json` files next to the input.

**Usage:**

```bash
transcribe-audio path/to/audio.mp3 --lang en
transcribe-audio path/to/audio.mp3 --lang ja
```

## `diarize-audio`

Speaker diarization with `pyannote.audio` 4.x
(`pyannote/speaker-diarization-community-1`). Prints `start  end  speaker`
ranges to stdout and writes an `.rttm` file next to the input. Optional
`--num-speakers` / `--min-speakers` / `--max-speakers` hints improve quality
when the count is known. Requires accepting the model license on HuggingFace
once and setting `HF_TOKEN` (or `HUGGINGFACE_TOKEN`) to a read token.

**Usage:**

```bash
export HF_TOKEN=hf_xxxxxxxxxxxx
diarize-audio path/to/audio.mp3
diarize-audio path/to/audio.mp3 --num-speakers 2
```

## `is-mic-on` / `is-camera-on`

Swift utilities to check if the microphone or camera is currently in use on
macOS. Returns exit code 0 if in use, 1 if not. Use `-q` for quiet mode (exit
code only).

## `claude-history`

A Ruby CLI tool for browsing Claude Code conversation histories from
`~/.claude/projects/`. A session is one JSONL file: the tool resolves a session
id to that file and prints it as a readable transcript, in the order Claude Code
wrote it, so the output matches the file line for line — where a session was
reverted and continued, the abandoned attempt and the retry both appear. Lines
Claude Code writes for its own bookkeeping are counted rather than printed, and
any line the tool cannot read is reported under the transcript.

**Usage:**

```bash
claude-history projects                              # List all projects
claude-history sessions --project myproject          # List a project's session files
claude-history show-session SESSION_ID               # Print a transcript
claude-history show-session SESSION_ID --verbose     # …with thinking, full tool output, metadata
claude-history sessions-updated-on 2026-04-12        # Find sessions by date
claude-history check-format                          # Report format drift across all files
```

A session id is matched by prefix, and searched across all projects unless
`--project` narrows it. `sessions --agents` includes `agent-*.jsonl` subagent
transcripts.

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

## `claude-chat-pdf-export`

Exports a Claude.ai conversation as a printable PDF. Two pieces:

- A **Chrome extension** that adds a floating "PDF" button to any
  `claude.ai/chat/*` page. Clicking it opens a print-ready tab; pick
  *Save as PDF* from Chrome's print dialog.
- A **Node CLI** (`render.mjs`) that turns a conversation JSON into a
  standalone HTML file, ready to feed into `chrome --headless
  --print-to-pdf` for unattended export.

Both share the same renderer, which lays out `text`, `thinking`,
`tool_use`, and `tool_result` blocks with print-friendly CSS.

**Usage (extension):**

```bash
cd src/claude-chat-pdf-export && npm install && npm run build
# then chrome://extensions → Developer mode → Load unpacked →
#   src/claude-chat-pdf-export/extension
```

**Usage (CLI):**

```bash
cd src/claude-chat-pdf-export && npm install
node render.mjs path/to/conv.json path/to/out.html
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=out.pdf "file://$PWD/out.html"
```

## `md-render`

A single-page Markdown renderer. Split view: paste/edit Markdown on the left,
see it rendered with GitHub-style typography on the right. Each pane scrolls
independently. Pick from a few themes (GitHub Light, GitHub Dark, a serif
*Reading* theme, Solarized Light) and use the browser's print dialog to save
the rendered side as PDF. Content and theme persist in `localStorage` so the
page survives reloads. Runs from a single HTML file with CDN-loaded
[`marked`](https://marked.js.org/), [`highlight.js`](https://highlightjs.org/),
and [`github-markdown-css`](https://github.com/sindresorhus/github-markdown-css).

**Usage:**

```bash
md-render            # opens src/md-render/index.html in your default browser
```

## `hammerspoon-spoons/`

Custom Hammerspoon Spoons for macOS automation.
