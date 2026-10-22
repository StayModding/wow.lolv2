#!/usr/bin/env python3
"""Generates the wow.tok app icon (1024x1024 PNG) without any image libraries."""
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "WowTok/Assets.xcassets/AppIcon.appiconset/icon-1024.png"


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(3))


def glow(x, y, cx, cy, radius):
    d = math.hypot(x - cx, y - cy)
    if d >= radius:
        return 0.0
    return (1.0 - d / radius) ** 2.2


def segment_distance(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    length_sq = vx * vx + vy * vy
    t = 0.0 if length_sq == 0 else max(0.0, min(1.0, (wx * vx + wy * vy) / length_sq))
    dx = px - (ax + t * vx)
    dy = py - (ay + t * vy)
    return math.hypot(dx, dy)


def build():
    bg = (11, 11, 15)
    violet = (171, 135, 255)
    mint = (107, 240, 199)
    points = [(248, 392), (368, 690), (512, 486), (656, 690), (776, 392)]
    thickness = 58

    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            base = bg
            g1 = glow(x, y, 330, 300, 760) * 0.62
            g2 = glow(x, y, 742, 720, 720) * 0.55
            color = mix(base, violet, g1)
            color = mix(color, mint, g2)

            # white "w" stroke
            dist = min(
                segment_distance(x, y, *points[i], *points[i + 1])
                for i in range(len(points) - 1)
            )
            if dist < thickness:
                alpha = 1.0 if dist < thickness - 6 else max(0.0, (thickness - dist) / 6.0)
                white = (255, 252, 250)
                color = mix(color, white, alpha)

            row.extend(int(max(0, min(255, round(c)))) for c in color)
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    return len(png)


if __name__ == "__main__":
    rows = build()
    size = write_png(OUT, rows)
    print(f"wrote {OUT} ({size} bytes)")
