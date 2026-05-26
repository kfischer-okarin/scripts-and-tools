import argparse
import contextlib
import os
import pathlib
import subprocess
import sys
import tempfile
import time

import torch
from pyannote.audio import Pipeline
from pyannote.audio.pipelines.utils.hook import ProgressHook

MODEL = "pyannote/speaker-diarization-community-1"

START = time.monotonic()


def log(msg):
    elapsed = time.monotonic() - START
    print(f"[{elapsed:6.1f}s] {msg}", file=sys.stderr, flush=True)


def main():
    args = parse_args()
    log(f"input: {args.file}")
    with as_wav(args.file) as wav_path:
        annotation = run_diarization(wav_path, args)
    log("writing outputs")
    print_segments(annotation)
    write_rttm(annotation, args.file)
    log("done")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Speaker diarization with pyannote.audio. "
        "Prints speaker timestamp ranges to stdout and writes an .rttm file next to the input."
    )
    parser.add_argument("file", help="Path to the audio file")
    parser.add_argument(
        "--device",
        default="cpu",
        help="Torch device: cpu, mps, or cuda (default: cpu)",
    )
    parser.add_argument("--num-speakers", type=int, help="Exact number of speakers, if known")
    parser.add_argument("--min-speakers", type=int, help="Minimum number of speakers")
    parser.add_argument("--max-speakers", type=int, help="Maximum number of speakers")
    return parser.parse_args()


def run_diarization(audio_path, args):
    pipeline = load_pipeline(args.device)
    log("running diarization (segmentation → embeddings → clustering)")
    with ProgressHook() as hook:
        return pipeline(audio_path, hook=hook, **speaker_hints(args))


@contextlib.contextmanager
def as_wav(input_path):
    if pathlib.Path(input_path).suffix.lower() == ".wav":
        yield input_path
        return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        log(f"extracting audio with ffmpeg → {tmp.name}")
        extract_audio(input_path, tmp.name)
        log("audio extracted")
        yield tmp.name


def extract_audio(input_path, output_path):
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", input_path,
         "-vn", "-ac", "1", "-ar", "16000", output_path],
        check=True,
    )


def load_pipeline(device):
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")
    if not token:
        sys.exit(
            "Set HF_TOKEN (or HUGGINGFACE_TOKEN) to a HuggingFace read token. "
            f"Also accept the model license at https://huggingface.co/{MODEL}"
        )
    log(f"loading pipeline {MODEL} (first run downloads weights to ~/.cache/huggingface)")
    pipeline = Pipeline.from_pretrained(MODEL, token=token)
    log(f"moving pipeline to device={device}")
    pipeline.to(torch.device(device))
    return pipeline


def speaker_hints(args):
    hints = {}
    if args.num_speakers is not None:
        hints["num_speakers"] = args.num_speakers
    if args.min_speakers is not None:
        hints["min_speakers"] = args.min_speakers
    if args.max_speakers is not None:
        hints["max_speakers"] = args.max_speakers
    return hints


def print_segments(annotation):
    for segment, _, speaker in annotation.itertracks(yield_label=True):
        print(f"{segment.start:7.2f}  {segment.end:7.2f}  {speaker}")


def write_rttm(annotation, audio_path):
    rttm_path = pathlib.Path(audio_path).with_suffix(".rttm")
    with open(rttm_path, "w") as f:
        annotation.write_rttm(f)


if __name__ == "__main__":
    main()
