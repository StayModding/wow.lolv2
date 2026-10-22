#!/usr/bin/env python3
"""Generates demo MP4 wallpaper packs with ffmpeg.

    python tools/make_samples.py --dry-run     # print the commands only
    python tools/make_samples.py               # write server/library/<pack>/{video.mp4,preview.jpg,pack.json}

Requires ffmpeg on PATH. The clips are 1080x1920, four seconds, H.264, and loop
cleanly so AVPlayerLooper has no visible seam.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "server" / "library"

CLIPS = [
    ("aurora-loop", "Aurora Loop", "0x0b1f1e", "0x6cf0c8", 0.03),
    ("neon-loop", "Neon Loop", "0x160018", "0xf05ab4", 0.05),
    ("solar-loop", "Solar Loop", "0x1c0a04", "0xffb45a", 0.04),
]


def commands_for(slug: str, title: str, c0: str, c1: str, speed: float) -> list[tuple[list[str], Path]]:
    folder = LIBRARY / slug
    video = folder / "video.mp4"
    preview = folder / "preview.jpg"
    gen_video = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-f", "lavfi",
        "-i", f"gradients=s=1080x1920:d=4:speed={speed}:c0={c0}:c1={c1}:type=radial",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an",
        str(video),
    ]
    gen_preview = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(video), "-frames:v", "1", "-q:v", "3", str(preview),
    ]
    return [(gen_video, folder), (gen_preview, folder)]


def write_meta(slug: str, title: str) -> None:
    folder = LIBRARY / slug
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "pack.json").write_text(
        json.dumps(
            {
                "title": title,
                "kind": "video",
                "author": "wow-ios samples",
                "tags": ["mp4", "loop", "demo"],
                "allowDownload": True,
                "hd": True,
                "trimStart": 0.0,
                "trimEnd": 3.5,
            },
            indent=2,
        )
        + "\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate demo MP4 wallpaper packs")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not args.dry_run and ffmpeg is None:
        print("ffmpeg is not on PATH. Install it, or use --dry-run to see the commands.")
        return 1

    for slug, title, c0, c1, speed in CLIPS:
        write_meta(slug, title)
        for argv, cwd in commands_for(slug, title, c0, c1, speed):
            cwd.mkdir(parents=True, exist_ok=True)
            print(" ".join(argv))
            if not args.dry_run:
                subprocess.run(argv, check=True, cwd=cwd)
        print(f"  -> {LIBRARY / slug}")

    print("\ndone" if not args.dry_run else "\ndry run: nothing written except pack.json files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
