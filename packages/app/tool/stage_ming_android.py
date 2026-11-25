"""Stage verified Ming install-time packs and Snapdragon libraries for a PageStage Android build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

app = Path(__file__).resolve().parents[1]
repo = app.parents[1]
manifest = app / "android/app/src/main/assets/ming/files.json"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(4 << 20), b""):
            value.update(chunk)
    return value.hexdigest()


def stage(src, dst, expected):
    if src.stat().st_size != expected["size"] or digest(src) != expected["sha256"]:
        raise ValueError(f"Model or runtime checksum mismatch: {src.name}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and os.path.samefile(src, dst):
        return
    tmp = dst.with_suffix(dst.suffix + ".partial")
    tmp.unlink(missing_ok=True)
    try:
        os.link(src, tmp)
    except OSError:
        shutil.copyfile(src, tmp)
    tmp.replace(dst)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, default=repo / "experiments/artifacts/models/Ming-0.5B-LiteRT")
    parser.add_argument("--qnn-libs", type=Path, default=repo / "experiments/ming_tts_lab/android/app/src/main/jniLibs/arm64-v8a")
    options = parser.parse_args()
    files = json.loads(manifest.read_text())
    for entry in files["models"]:
        name = entry["name"]
        stage(options.models / name, app / "android" / entry["pack"] / "src/main/assets/ming" / name, entry)
    native = app / "android/app/src/main/jniLibs/arm64-v8a"
    for entry in files["libraries"]:
        stage(options.qnn_libs / entry["name"], native / entry["name"], entry)
    print(f"Verified {len(files['models'])} model files and {len(files['libraries'])} Qualcomm libraries")
