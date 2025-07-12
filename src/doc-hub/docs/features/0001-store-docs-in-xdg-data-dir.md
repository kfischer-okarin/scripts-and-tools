# Store docs in XDG data dir

## Story

**As a** developer
**I want** doc-hub to store downloaded docs in the XDG data dir
**so that** it's easy to find and manage.

## Acceptance Criteria

### AC-1 Respects XDG_DATA_HOME

**Given** `$XDG_DATA_HOME` is set
**When** I run `doc-hub add xdg-spec https://specifications.freedesktop.org/basedir-spec/latest/`
**Then** the Markdown files are stored under `$XDG_DATA_HOME/doc-hub/xdg-spec/`.

### AC-2 Uses default location if XDG_DATA_HOME is not set

**Given** `$XDG_DATA_HOME` is not set
**When** I run `doc-hub add xdg-spec https://specifications.freedesktop.org/basedir-spec/latest/`
**Then** the Markdown files are stored under `~/.local/share/doc-hub/xdg-spec/`.
