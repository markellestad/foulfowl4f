#!/usr/bin/env python
"""Import open audio assets using ffmpeg according to open_manifest.json."""
import json
import os
import pathlib
import subprocess
import sys

FORBIDDEN_PACKS = [
    "SCI-FI_UI_SFX_PACK",
    "Sci-Fi Combat Systems",
    "Explosion SFX Pack",
    "Shapeforms",
]

def check_source_path(source_path: str) -> bool:
    for forbidden in FORBIDDEN_PACKS:
        if forbidden.lower() in source_path.replace("\\", "/").lower():
            return False
    return True

def main():
    root = pathlib.Path(__file__).resolve().parent.parent.parent
    manifest_path = root / "tools" / "audio" / "open_manifest.json"
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    source_root_env = manifest.get("source_root_env", "FOULFOWL_SOUND_ASSETS")
    source_root = os.environ.get(source_root_env, "")
    if not source_root:
        local_cfg = root / "tools" / "audio" / "sound_root.local"
        if local_cfg.exists():
            source_root = local_cfg.read_text(encoding="utf-8").strip()
    if not source_root:
        source_root = manifest.get("source_root_default", "")
    if not source_root:
        print(f"No sound source folder: set {source_root_env} or write the path into tools/audio/sound_root.local (gitignored). Skipping.")
        return 0
    source_root_path = pathlib.Path(source_root)

    total_sfx_size = 0
    total_music_size = 0

    for item in manifest.get("items", []):
        slot = item["slot"]
        rel_src = item["source"]
        target = root / item["target"]
        kind = item.get("kind", "sfx")

        if not check_source_path(rel_src):
            print(f"ERROR: Refused source {rel_src} containing licensed pack name")
            return 1

        src = source_root_path / rel_src
        if not src.exists():
            print(f"ERROR: Source file missing: {src}")
            return 1

        target.parent.mkdir(parents=True, exist_ok=True)

        if kind == "music":
            trim_s = item.get("trim_s", 120)
            fade_start = trim_s - 3
            cmd = [
                "ffmpeg", "-y", "-i", str(src),
                "-t", str(trim_s),
                "-af", f"afade=t=out:st={fade_start}:d=3",
                "-ac", "2", "-ar", "44100",
                "-c:a", "libvorbis", "-q:a", "1",
                str(target)
            ]
        else:
            cmd = [
                "ffmpeg", "-y", "-i", str(src),
                "-ac", "1", "-ar", "44100",
                "-c:a", "libvorbis", "-q:a", "3",
                str(target)
            ]

        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"ERROR: ffmpeg failed for {slot}:\n{res.stderr}")
            return 1

        size = target.stat().st_size
        print(f"Imported {slot} ({kind}) -> {target.relative_to(root)} ({size} bytes)")
        if kind == "music":
            total_music_size += size
        else:
            total_sfx_size += size

    print(f"Total open SFX: {total_sfx_size} bytes (budget: 1572864 bytes)")
    print(f"Total open Music: {total_music_size} bytes (budget: 7340032 bytes)")

    if total_sfx_size > 1572864:
        print("WARNING: Total open SFX exceeds 1.5 MB!")
    if total_music_size > 7340032:
        print("WARNING: Total open music exceeds 7 MB!")

    return 0

if __name__ == "__main__":
    sys.exit(main())
