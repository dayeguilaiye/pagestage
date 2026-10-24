"""Install the ignored local playback fixture into an installed simulator app."""

import argparse
import pathlib
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["ios", "android"])
    parser.add_argument("--device", help="simulator UUID or adb serial")
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[3]
    fixture = root / ".pagestage/playback-prototype"
    if not (fixture / "fixture.json").is_file():
        parser.error("Run dart run packages/app/tool/prepare_playback.dart first.")
    if args.platform == "ios":
        container = subprocess.check_output([
            "xcrun", "simctl", "get_app_container", args.device or "booted",
            "com.example.pagestageApp", "data",
        ], text=True).strip()
        destination = pathlib.Path(container) / "Library/Application Support/playback-prototype"
        destination.mkdir(parents=True, exist_ok=True)
        for name in ["fixture.json", "chapter.wav"]:
            shutil.copy2(fixture / name, destination / name)
        shutil.copytree(fixture / "clips", destination / "clips", dirs_exist_ok=True)
    else:
        adb = str(pathlib.Path.home() / "Library/Android/sdk/platform-tools/adb")
        command = [adb] + (["-s", args.device] if args.device else [])
        subprocess.run(command + ["push", str(fixture) + "/.",
            "/data/local/tmp/pagestage-playback"], check=True)
        subprocess.run(command + ["shell", "run-as", "com.example.pagestage_app",
            "sh", "-c", "'mkdir -p files/playback-prototype && cp -R "
            "/data/local/tmp/pagestage-playback/. files/playback-prototype/'"], check=True)
    print("Playback fixture installed; no provider requests were made.")


if __name__ == "__main__":
    main()
