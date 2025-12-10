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

## `hammerspoon-spoons/`

Custom Hammerspoon Spoons for macOS automation.
