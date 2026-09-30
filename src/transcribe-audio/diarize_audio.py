import argparse
import os
import pathlib
import re
import subprocess
import sys
import time
from collections import Counter, defaultdict

import numpy as np
import torch
from pyannote.audio import Pipeline
from pyannote.audio.pipelines.utils.hook import ProgressHook

MODEL = "pyannote/speaker-diarization-community-1"
SAMPLE_RATE = 16000

# A cue whose main speaker has less of its speech than this is labelled as shared
MIXED_BELOW = 0.8
# Speakers with less of a shared cue's speech than this are left out of its label
LISTED_FROM = 0.1
# Zoom prefixes every cue with "Name: "
SPEAKER_PREFIX = re.compile(r"([^\n:]{1,40}): (.*)", re.DOTALL)

START = time.monotonic()


def log(msg):
    elapsed = time.monotonic() - START
    print(f"[{elapsed:6.1f}s] {msg}", file=sys.stderr, flush=True)


def main():
    args = parse_args()
    log(f"input: {args.file}")
    annotation = run_diarization(load_audio(args.file), args)
    write_rttm(annotation, args.file)
    if args.vtt:
        write_diarized_vtt(annotation, args.vtt)
    log("done")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Speaker diarization with pyannote.audio. "
        "Writes the speaker timestamp ranges as an .rttm file next to the input."
    )
    parser.add_argument("file", help="Path to the audio file")
    parser.add_argument("--num-speakers", type=int, help="Exact number of speakers, if known")
    parser.add_argument("--min-speakers", type=int, help="Minimum number of speakers")
    parser.add_argument("--max-speakers", type=int, help="Maximum number of speakers")
    parser.add_argument(
        "--vtt",
        help="Transcript of the same recording. Writes a copy next to it, <name>.diarized.vtt, "
        "with each cue labelled by the speakers heard during it",
    )
    return parser.parse_args()


def run_diarization(audio, args):
    pipeline = load_pipeline()
    log("running diarization (segmentation → embeddings → clustering)")
    with ProgressHook() as hook:
        output = pipeline(audio, hook=hook, **speaker_hints(args))
    # The variant without overlapping turns, meant for aligning with transcripts
    return output.exclusive_speaker_diarization


def load_audio(input_path):
    """Decode with the ffmpeg CLI and hand pyannote the waveform in memory.

    Given a file, pyannote decodes it through torchcodec chunk by chunk, which
    was ~30% slower on an hour-long meeting, and fails whenever torchcodec
    can't load the installed FFmpeg (e.g. after Homebrew moves to a new major).
    """
    log("decoding audio with ffmpeg")
    pcm = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", input_path,
         "-vn", "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "s16le", "-"],
        check=True,
        capture_output=True,
    ).stdout
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768
    log(f"audio decoded ({len(samples) / SAMPLE_RATE / 60:.1f} min)")
    return {"waveform": torch.from_numpy(samples).unsqueeze(0), "sample_rate": SAMPLE_RATE}


def load_pipeline():
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")
    if not token:
        sys.exit(
            "Set HF_TOKEN (or HUGGINGFACE_TOKEN) to a HuggingFace read token. "
            f"Also accept the model license at https://huggingface.co/{MODEL}"
        )
    log(f"loading pipeline {MODEL} (first run downloads weights to ~/.cache/huggingface)")
    pipeline = Pipeline.from_pretrained(MODEL, token=token)
    device = best_device()
    log(f"moving pipeline to device={device}")
    pipeline.to(torch.device(device))
    return pipeline


def best_device():
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def speaker_hints(args):
    hints = {}
    if args.num_speakers is not None:
        hints["num_speakers"] = args.num_speakers
    if args.min_speakers is not None:
        hints["min_speakers"] = args.min_speakers
    if args.max_speakers is not None:
        hints["max_speakers"] = args.max_speakers
    return hints


def write_rttm(annotation, audio_path):
    rttm_path = pathlib.Path(audio_path).with_suffix(".rttm")
    with open(rttm_path, "w") as f:
        annotation.write_rttm(f)
    log(f"wrote {rttm_path}")


def write_diarized_vtt(annotation, vtt_path):
    turns = [(seg.start, seg.end, speaker) for seg, _, speaker in annotation.itertracks(yield_label=True)]
    cues = [{**cue, "speakers": speaker_seconds(cue, turns)} for cue in parse_vtt(vtt_path)]
    path = pathlib.Path(vtt_path)
    out_path = path.with_name(f"{path.stem}.diarized.vtt")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("WEBVTT\n\n")
        f.write(summary_note(cues))
        for cue in cues:
            f.write("\n".join(cue["header"]) + "\n")
            f.write(f"{cue_label(cue)}: {cue['text']}\n\n")
    log(f"wrote {out_path}")


def parse_vtt(path):
    cues = []
    for block in pathlib.Path(path).read_text(encoding="utf-8").split("\n\n"):
        lines = block.strip("\n").splitlines()
        timing = next((i for i, line in enumerate(lines) if "-->" in line), None)
        if timing is None:
            continue  # the WEBVTT header, NOTE and STYLE blocks
        start, _, end = lines[timing].split()[:3]
        name, text = split_speaker("\n".join(lines[timing + 1:]))
        cues.append({
            "header": lines[:timing + 1],
            "start": vtt_seconds(start),
            "end": vtt_seconds(end),
            "name": name,
            "text": text,
        })
    return cues


def vtt_seconds(timestamp):
    parts = reversed(timestamp.split(":"))
    return sum(float(part) * 60**i for i, part in enumerate(parts))


def split_speaker(text):
    match = SPEAKER_PREFIX.fullmatch(text)
    return (match[1], match[2]) if match else (None, text)


def speaker_seconds(cue, turns):
    seconds = Counter()
    for start, end, speaker in turns:
        shared = min(end, cue["end"]) - max(start, cue["start"])
        if shared > 0:
            seconds[speaker] += shared
    return seconds


def summary_note(cues):
    """How the diarized speakers spread over the transcript's own speaker names,
    the evidence for deciding who each SPEAKER_nn is."""
    by_name = defaultdict(Counter)
    for cue in cues:
        by_name[cue["name"] or "(unnamed)"].update(cue["speakers"])
    lines = [
        "NOTE",
        f"Speakers diarized with {MODEL}.",
        "A label with percentages marks a cue shared by several speakers,",
        "with each one's share of its speech.",
        "Seconds of each speaker inside the cues of each original speaker:",
    ]
    for name, seconds in by_name.items():
        lines.append(f"{name}: " + ", ".join(f"{sp} {s:.0f}s" for sp, s in seconds.most_common()))
    return "\n".join(lines) + "\n\n"


def cue_label(cue):
    seconds = cue["speakers"]
    total = sum(seconds.values())
    if not total:
        return "UNKNOWN"
    shares = [(speaker, s / total) for speaker, s in seconds.most_common()]
    if shares[0][1] >= MIXED_BELOW:
        return shares[0][0]
    return " / ".join(f"{speaker} {share:.0%}" for speaker, share in shares if share >= LISTED_FROM)


if __name__ == "__main__":
    main()
