#!/usr/bin/env python3
"""
extend_loop.py  —  v1.1
Extend an audio file by looping a chosen section until a target length
is reached, keeping the original bit-rate / codec if possible.

1. 0 ➜ loop_start
2. loop_start ➜ loop_end   (repeat until ≥ min_length)
3. loop_end ➜ end
"""

# TODO: 0:18.744 - 1:52.563

import argparse, re, pprint, sys
from pathlib import Path
from pydub import AudioSegment, utils as pd_utils

# ---------------------------------------------------------------------------#
# Time helpers (unchanged from v1.0)                                         #
# ---------------------------------------------------------------------------#
TIME_RE = re.compile(
    r"""^\s*(?:
        (?P<h>\d+)\s*h(?:ours?)? |
        (?P<m>\d+)\s*m(?:in(?:s|utes?)?)? |
        (?P<s>\d+(?:\.\d+)?)\s*s(?:ec(?:s|onds?)?)? |
        (?P<colon>(?:\d+:)?\d+:\d+(?:\.\d{1,6})?)
    )\s*$""",
    re.VERBOSE | re.IGNORECASE,
)


def parse_time(tstr: str) -> float:  # → seconds
    m = TIME_RE.match(tstr)
    if not m:
        raise ValueError(f"Unrecognised time format: '{tstr}'")

    if m["h"]:
        return float(m["h"]) * 3600
    if m["m"]:
        return float(m["m"]) * 60
    if m["s"]:
        return float(m["s"])

    parts = [float(p) for p in m["colon"].split(":")]
    return (
        parts[0] * 3600 + parts[1] * 60 + parts[2]
        if len(parts) == 3
        else parts[0] * 60 + parts[1]
    )


def hhmmss_ms(sec: float) -> str:
    h, rem = divmod(int(sec), 3600)
    m, s = divmod(rem, 60)
    ms = int(round((sec - int(sec)) * 1000))
    return f"{h:d}:{m:02d}:{s:02d}.{ms:03d}"


# ---------------------------------------------------------------------------#
# New: codec / bit-rate discovery                                            #
# ---------------------------------------------------------------------------#
def probe_audio_settings(path: Path) -> dict:
    """
    Return a dict with keys: codec_name, bit_rate (int or None), sample_rate
    Uses pydub.utils.mediainfo ==> ffprobe
    """
    try:
        info = pd_utils.mediainfo(str(path))
        print(f'mediainfo: {pprint.pformat(info)}')

        # Handle both formats: nested with 'streams' key or flat dictionary
        if isinstance(info, dict):
            if "streams" in info:
                # Nested format with streams array
                stream = next(
                    (s for s in info["streams"] if s.get("codec_type") == "audio"), {}
                )
            elif "codec_type" in info and info["codec_type"] == "audio":
                # Flat format - single stream
                stream = info
            else:
                stream = {}
        else:
            stream = {}
    except Exception as e:
        print(f"Warning: Error probing audio settings: {e}")
        return {"codec_name": None, "bit_rate": None, "sample_rate": None}

    def to_int(x):
        try:
            return int(x)
        except Exception:
            return None

    return {
        "codec_name": stream.get("codec_name"),
        "bit_rate": to_int(stream.get("bit_rate")),
        "sample_rate": to_int(stream.get("sample_rate")),
    }


def format_for_export(infile: Path) -> str:
    """
    Guess the ffmpeg format string from the extension.
    .mp3 → "mp3", .m4a → "ipod", .flac → "flac", etc.
    """
    ext = infile.suffix.lower().lstrip(".")
    # ffmpeg format names sometimes differ from extensions; map common ones
    return {"m4a": "ipod", "aac": "adts"}.get(ext, ext)


# ---------------------------------------------------------------------------#
# Main logic                                                                 #
# ---------------------------------------------------------------------------#
def extend_loop(
    infile: Path,
    outfile: Path,
    loop_start_s: float,
    loop_end_s: float,
    min_length_s: float,
):
    orig_info = probe_audio_settings(infile)
    print(f'Extracted info: {pprint.pformat(orig_info)}')
    codec = orig_info["codec_name"]
    bit_rate = orig_info["bit_rate"]

    audio = AudioSegment.from_file(infile)
    dur_s = len(audio) / 1000

    if not 0 <= loop_start_s < loop_end_s < dur_s:
        sys.exit(
            f"Loop points must satisfy 0 ≤ start < end < track length "
            f"({dur_s:.3f}s); got {loop_start_s}s → {loop_end_s}s."
        )

    head = audio[: int(loop_start_s * 1000)]
    loop = audio[int(loop_start_s * 1000) : int(loop_end_s * 1000)]
    tail = audio[int(loop_end_s * 1000) :]

    result = head
    while (len(result) + len(tail)) / 1000 < min_length_s:
        result += loop
    result += tail

    export_kwargs = {}
    if bit_rate:
        export_kwargs["bitrate"] = f"{bit_rate // 1000}k"

    fmt = format_for_export(infile)
    result.export(outfile, format=fmt, **export_kwargs)

    print(
        f"Done ➜ {outfile}\n"
        f"Original length  : {dur_s:.3f}s\n"
        f"Extended length  : {len(result)/1000:.3f}s\n"
        f"Original codec   : {codec or 'unknown'}\n"
        f"Original bitrate : {bit_rate/1000 if bit_rate else 'N/A'} kb/s\n"
        f"Loop section     : {hhmmss_ms(loop_start_s)} → "
        f"{hhmmss_ms(loop_end_s)} ({len(loop)/1000:.3f}s)"
    )


def main():
    ap = argparse.ArgumentParser(description="Extend an audio file by looping a section.")
    ap.add_argument("--input", "-i", required=True, help="Path to input audio")
    ap.add_argument("--output", "-o", help="Path for output file (default: extended_<name>.<ext>)")
    ap.add_argument("--loop-start", required=True, help="Loop start time (e.g. 0:17.758)")
    ap.add_argument("--loop-end", required=True, help="Loop end time (e.g. 1:51.710)")
    ap.add_argument("--min-length", required=True, help="Target minimum length (e.g. 10m, 300s)")
    args = ap.parse_args()

    infile = Path(args.input).expanduser()
    if not infile.exists():
        sys.exit(f"No such file: {infile}")

    outfile = (
        Path(args.output)
        if args.output
        else infile.with_name(f"extended_{infile.stem}{infile.suffix}")
    )

    try:
        loop_start_s = parse_time(args.loop_start)
        loop_end_s = parse_time(args.loop_end)
        min_length_s = parse_time(args.min_length)
    except ValueError as e:
        sys.exit(str(e))

    extend_loop(infile, outfile, loop_start_s, loop_end_s, min_length_s)


if __name__ == "__main__":
    main()