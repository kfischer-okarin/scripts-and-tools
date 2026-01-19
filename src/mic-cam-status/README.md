# mic-cam-status

Swift utilities to check if the microphone or camera is currently in use on macOS.

## Commands

- `is-mic-on` - Check if microphone is in use (exit 0 if in use, 1 if not)
- `is-camera-on` - Check if camera is in use (exit 0 if in use, 1 if not)

Both support `-q` / `--quiet` for exit-code-only mode.

## Building

Run `./build.sh` to compile. Binaries are output to `output/` (gitignored).

The bin wrappers build automatically on first run.
