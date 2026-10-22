#!/usr/bin/env python3
"""
wow.tok dev wallpaper server.

Serves a pack manifest and raw media over HTTP so the wow.tok iOS app can pull
wallpapers through whatever local VPN tunnel you have running.

    python server/devserver.py --port 8787
    python server/devserver.py --port 8787 --demo     # writes demo PNG packs first

Library layout (one folder per pack):

    library/
      aurora-drift/
        pack.json        optional metadata
        preview.jpg      required, used for the grid thumbnail
        video.mp4        optional, the master clip (never watermarked)
        still.jpg        optional, paired still for a live photo pack

Files are served byte for byte from disk, so the app exports exactly what you
put in the folder.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import socket
import struct
import sys
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent
LIBRARY = ROOT / "library"

VIDEO_EXT = {".mp4", ".mov", ".m4v"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".heic", ".webp"}
PREVIEW_NAMES = ("preview.jpg", "preview.jpeg", "preview.png")


# ---------------------------------------------------------------- demo assets


def _png(width: int, height: int, pixels: bytearray) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + bytes(pixels[y * width * 3 : (y + 1) * width * 3]) for y in range(height))
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


def write_demo_preview(path: Path, top: tuple, bottom: tuple, width: int = 540, height: int = 960) -> None:
    pixels = bytearray()
    for y in range(height):
        t = y / (height - 1)
        # diagonal sweep so the gradient does not look flat
        for x in range(width):
            u = (x / (width - 1)) * 0.25
            mix = min(1.0, t * 0.85 + u)
            for i in range(3):
                pixels.append(int(top[i] + (bottom[i] - top[i]) * mix))
    path.write_bytes(_png(width, height, pixels))


DEMO_PACKS = [
    ("aurora-drift", "Aurora Drift", (18, 60, 58), (108, 240, 200)),
    ("neon-tokyo", "Neon Tokyo", (60, 8, 52), (240, 90, 190)),
    ("mint-horizon", "Mint Horizon", (8, 40, 44), (150, 250, 220)),
    ("solar-bloom", "Solar Bloom", (70, 18, 6), (255, 190, 90)),
]


def seed_demo() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    for slug, title, top, bottom in DEMO_PACKS:
        folder = LIBRARY / slug
        folder.mkdir(parents=True, exist_ok=True)
        preview = folder / "preview.jpg"
        png = folder / "preview.png"
        if not preview.exists() and not png.exists():
            write_demo_preview(png, top, bottom)
        meta_path = folder / "pack.json"
        if not meta_path.exists():
            meta_path.write_text(
                json.dumps(
                    {
                        "title": title,
                        "kind": "photo",
                        "author": "wow.tok demo",
                        "tags": ["gradient", "demo"],
                        "allowDownload": True,
                        "hd": True,
                    },
                    indent=2,
                )
                + "\n"
            )
    print(f"demo packs written to {LIBRARY}")


# ------------------------------------------------------------------- manifest


def first_image(folder: Path) -> Path | None:
    for name in PREVIEW_NAMES:
        candidate = folder / name
        if candidate.exists():
            return candidate
    for child in sorted(folder.iterdir()):
        if child.suffix.lower() in IMAGE_EXT:
            return child
    return None


def first_video(folder: Path) -> Path | None:
    for child in sorted(folder.iterdir()):
        if child.suffix.lower() in VIDEO_EXT and child.name.lower() != "still":
            return child
    return None


def still_image(folder: Path) -> Path | None:
    for child in sorted(folder.iterdir()):
        if child.suffix.lower() in IMAGE_EXT and child.name.lower().startswith("still"):
            return child
    return None


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "pack"


def build_pack(folder: Path) -> dict | None:
    preview = first_image(folder)
    if preview is None:
        return None
    video = first_video(folder)
    meta: dict = {}
    meta_path = folder / "pack.json"
    if meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text())
        except json.JSONDecodeError:
            print(f"warning: {meta_path} is not valid JSON, ignoring", file=sys.stderr)

    kind = meta.get("kind")
    if not kind:
        kind = "video" if video else "photo"

    pack_id = meta.get("id") or slugify(folder.name)
    base = f"/files/{folder.name}"
    still = still_image(folder)

    pack = {
        "id": pack_id,
        "title": meta.get("title") or folder.name.replace("-", " ").title(),
        "kind": kind,
        "preview": f"{base}/{preview.name}",
        "hd": meta.get("hd", True),
        "allowDownload": meta.get("allowDownload", True),
    }
    if meta.get("author"):
        pack["author"] = meta["author"]
    if meta.get("tags"):
        pack["tags"] = meta["tags"]
    if video is not None:
        pack["video"] = f"{base}/{video.name}"
    if still is not None:
        pack["still"] = f"{base}/{still.name}"
    elif kind == "live":
        pack["still"] = f"{base}/{preview.name}"
    if "trimStart" in meta:
        pack["trimStart"] = meta["trimStart"]
    if "trimEnd" in meta:
        pack["trimEnd"] = meta["trimEnd"]
    if "duration" in meta:
        pack["duration"] = meta["duration"]
    return pack


def manifest() -> dict:
    packs = []
    if LIBRARY.exists():
        for folder in sorted(p for p in LIBRARY.iterdir() if p.is_dir()):
            pack = build_pack(folder)
            if pack:
                packs.append(pack)
    return {
        "version": 1,
        "name": f"{socket.gethostname()} · {os.name}",
        "packs": packs,
    }


# --------------------------------------------------------------------- server


class Handler(BaseHTTPRequestHandler):
    server_version = "wowtok-dev/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        print(f"{self.address_string()} {fmt % args}")

    def _json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _not_found(self, message: str) -> None:
        self._json({"error": message}, status=404)

    def do_GET(self) -> None:  # noqa: N802
        path = unquote(urlparse(self.path).path)

        if path in ("/", "/api"):
            self._json(
                {
                    "app": "wow.tok dev server",
                    "endpoints": ["/api/health", "/api/manifest", "/files/<pack>/<file>"],
                    "library": str(LIBRARY),
                }
            )
            return

        if path == "/api/health":
            data = manifest()
            self._json({"ok": True, "packs": len(data["packs"]), "name": data["name"]})
            return

        if path == "/api/manifest":
            self._json(manifest())
            return

        if path.startswith("/files/"):
            self._serve_file(path[len("/files/") :])
            return

        self._not_found(f"no route for {path}")

    def _serve_file(self, relative: str) -> None:
        parts = [part for part in relative.split("/") if part not in ("", ".", "..")]
        if len(parts) < 2:
            self._not_found("expected /files/<pack>/<file>")
            return
        target = (LIBRARY.joinpath(*parts)).resolve()
        try:
            target.relative_to(LIBRARY.resolve())
        except ValueError:
            self._not_found("path escapes the library")
            return
        if not target.is_file():
            self._not_found(f"missing {relative}")
            return

        size = target.stat().st_size
        content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        start, end = 0, size - 1
        status = 200

        range_header = self.headers.get("Range")
        if range_header:
            match = re.match(r"bytes=(\d*)-(\d*)", range_header.strip())
            if match:
                raw_start, raw_end = match.groups()
                if raw_start:
                    start = int(raw_start)
                if raw_end:
                    end = min(int(raw_end), size - 1)
                elif not raw_start:
                    length = int(raw_end or 0)
                    start = max(0, size - length)
                if start > end or start >= size:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                status = 206

        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Access-Control-Allow-Origin", "*")
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()

        with target.open("rb") as handle:
            handle.seek(start)
            remaining = length
            while remaining > 0:
                chunk = handle.read(min(256 * 1024, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return
                remaining -= len(chunk)

    def do_HEAD(self) -> None:  # noqa: N802
        path = unquote(urlparse(self.path).path)
        if path.startswith("/files/"):
            parts = [p for p in path[len("/files/") :].split("/") if p]
            target = LIBRARY.joinpath(*parts)
            if target.is_file():
                self.send_response(200)
                self.send_header("Content-Type", mimetypes.guess_type(str(target))[0] or "application/octet-stream")
                self.send_header("Content-Length", str(target.stat().st_size))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()
                return
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()


def main() -> int:
    global LIBRARY
    parser = argparse.ArgumentParser(description="wow.tok local wallpaper server")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--library", type=Path, default=LIBRARY)
    parser.add_argument("--demo", action="store_true", help="seed demo gradient packs and exit-safe")
    args = parser.parse_args()

    LIBRARY = args.library
    LIBRARY.mkdir(parents=True, exist_ok=True)

    if args.demo:
        seed_demo()

    packs = manifest()["packs"]
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.daemon_threads = True

    print(f"wow.tok dev server on http://{args.host}:{args.port}")
    print(f"library: {LIBRARY} ({len(packs)} packs)")
    for pack in packs:
        print(f"  · {pack['id']:<18} {pack['kind']:<6} {pack['preview']}")
    print("point the app at <this-machine-ip>:%d behind your VPN, or forward the port" % args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
