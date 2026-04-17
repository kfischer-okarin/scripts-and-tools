import argparse
import pathlib

import mlx_whisper
from mlx_whisper.writers import get_writer

JAPANESE_MODEL = "kaiinui/kotoba-whisper-v2.0-mlx"
DEFAULT_MODEL = "mlx-community/whisper-large-v3-turbo"


def main():
    args = parse_args()
    result = mlx_whisper.transcribe(
        args.file,
        path_or_hf_repo=pick_model(args.lang),
        language=args.lang,
        verbose=True,
    )
    write_outputs(result, args.file)


def parse_args():
    parser = argparse.ArgumentParser(description="Transcribe an audio file with mlx-whisper.")
    parser.add_argument("file", help="Path to the audio file")
    parser.add_argument("--lang", required=True, help="Language code (e.g. en, ja, de)")
    return parser.parse_args()


def pick_model(lang):
    if lang == "ja":
        return JAPANESE_MODEL
    return DEFAULT_MODEL


def write_outputs(result, audio_path):
    path = pathlib.Path(audio_path)
    output_dir = str(path.parent) if str(path.parent) else "."
    writer = get_writer("all", output_dir)
    writer(result, path.stem)


if __name__ == "__main__":
    main()
