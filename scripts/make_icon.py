#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ICON = ROOT / "Resources" / "AppIconSource.png"
ICONSET = ROOT / ".build" / "AppIcon.iconset"
ICONSET.mkdir(parents=True, exist_ok=True)


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    bg = (18, 20, 26, 255)
    panel = (28, 32, 42, 255)
    teal = (57, 194, 177, 255)
    teal_dark = (27, 133, 124, 255)
    white = (245, 247, 250, 255)

    # Rounded background
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22), fill=bg)

    # Soft panel
    inset = int(size * 0.12)
    draw.rounded_rectangle((inset, inset, size - inset, size - inset), radius=int(size * 0.19), fill=panel)

    # Base bars
    bar_w = max(2, int(size * 0.09))
    gap = int(size * 0.08)
    start_x = int(size * 0.30)
    base_y = int(size * 0.74)
    heights = [0.28, 0.42, 0.60]
    colors = [white, teal, teal_dark]
    for i, (h, color) in enumerate(zip(heights, colors)):
        x = start_x + i * (bar_w + gap)
        top = int(size * (0.74 - h))
        draw.rounded_rectangle((x, top, x + bar_w, base_y), radius=max(2, bar_w // 2), fill=color)

    # Accent line
    line_y = int(size * 0.52)
    draw.rounded_rectangle((int(size * 0.22), line_y, int(size * 0.78), line_y + max(2, size // 32)), radius=max(1, size // 64), fill=teal)

    # Status dot
    dot_r = max(3, size // 16)
    cx = int(size * 0.72)
    cy = int(size * 0.30)
    draw.ellipse((cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r), fill=teal)

    return img


sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

for name, size in sizes.items():
    if SOURCE_ICON.exists():
        img = Image.open(SOURCE_ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    else:
        img = draw_icon(size)
    img.save(ICONSET / name)
