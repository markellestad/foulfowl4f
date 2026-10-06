#!/usr/bin/env python
"""Fetch and convert licensed audio assets into assets/audio/licensed/."""
import json
import os
import pathlib
import subprocess
import sys

def main():
    root = pathlib.Path(__file__).resolve().parent.parent
    # Check ffmpeg availability
    try:
        p = subprocess.run(["ffmpeg", "-version"], capture_output=True)
        if p.returncode != 0:
            print("ERROR: ffmpeg returned non-zero")
            return 2
    except Exception as e:
        print(f"ERROR: ffmpeg missing: {e}")
        return 2

    manifest_path = root / "tools" / "audio" / "licensed_manifest.json"
    if not manifest_path.exists():
        print("SKIP: licensed_manifest.json not found")
        return 0

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    source_root_env = manifest.get("source_root_env", "FOULFOWL_SOUND_ASSETS")
    source_root = os.environ.get(source_root_env, manifest.get("source_root_default", ""))
    source_root_path = pathlib.Path(source_root)

    dest_dir = root / "assets" / "audio" / "licensed"
    dest_dir.mkdir(parents=True, exist_ok=True)

    built_slots = []

    for item in manifest.get("items", []):
        slot = item["slot"]
        rel_src = item["source"]
        target = root / item["target"]

        src = source_root_path / rel_src
        if not src.exists():
            print(f"SKIP {slot} (source missing)")
            continue

        cmd = [
            "ffmpeg", "-y", "-i", str(src),
            "-ac", "1", "-ar", "44100",
            "-c:a", "libvorbis", "-q:a", "3",
            str(target)
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"ERROR: ffmpeg failed for {slot}:\n{res.stderr}")
            continue

        print(f"BUILT {slot} -> {target.relative_to(root)}")
        built_slots.append(slot)

    built_txt = dest_dir / "BUILT.txt"
    built_txt.write_text("\n".join(built_slots) + "\n", encoding="utf-8")
    return 0

if __name__ == "__main__":
    sys.exit(main())
