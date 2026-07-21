#!/usr/bin/env python3
"""Draw a minimal, deterministic LLMUsageBar app icon with Pillow."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Resources" / "AppIconSource.png"
SCALE = 4
SIZE = 1024
W = SIZE * SCALE


def draw_icon() -> Image.Image:
    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    box = tuple(value * SCALE for value in (72, 72, 952, 952))
    radius = 210 * SCALE

    # One restrained shadow, one solid squircle, one accent color.
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (box[0], box[1] + 18 * SCALE, box[2], box[3] + 18 * SCALE),
        radius=radius,
        fill=(0, 0, 0, 105),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24 * SCALE))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, radius=radius, fill=(242, 247, 246, 255))

    mint = (24, 158, 135, 255)
    bars = [
        (256, 476, 376, 748),
        (452, 286, 572, 748),
        (648, 390, 768, 748),
    ]
    for left, top, right, bottom in bars:
        draw.rounded_rectangle(
            tuple(value * SCALE for value in (left, top, right, bottom)),
            radius=58 * SCALE,
            fill=mint,
        )

    return canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    draw_icon().save(OUTPUT)
    print(OUTPUT)
