#!/usr/bin/env python3
"""Generate one 1920x1080 glassy wallpaper per Simorgh theme.

Each wallpaper is a smooth dark vertical gradient in the theme's accent
hue, with a soft radial glow and a whisper of grain — the same calm,
minimal look the glassy themes use on the desktop.

Run from the repo root:  python3 wallpapers/generate.py
Requires: Pillow, numpy.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1920, 1080

THEMES = {
    "teal-glass":   {"accent": (45, 212, 191),  "bg_top": (16, 28, 33),  "bg_bottom": (8, 13, 16)},
    "violet-glass": {"accent": (167, 139, 250), "bg_top": (24, 18, 38),  "bg_bottom": (10, 8, 18)},
    "forest-glass": {"accent": (74, 222, 128),  "bg_top": (17, 32, 22),  "bg_bottom": (8, 15, 10)},
    "ocean-glass":  {"accent": (56, 189, 248),  "bg_top": (14, 28, 42),  "bg_bottom": (7, 13, 20)},
    "rose-glass":   {"accent": (251, 113, 133), "bg_top": (36, 20, 26),  "bg_bottom": (16, 9, 12)},
    "ember-glass":  {"accent": (251, 146, 60),  "bg_top": (36, 24, 14),  "bg_bottom": (17, 11, 7)},
}


def make_wallpaper(accent, top, bottom):
    # Vertical gradient (numpy, fast and smooth)
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top_a = np.array(top, dtype=np.float32)
    bot_a = np.array(bottom, dtype=np.float32)
    grad = top_a * (1 - t) + bot_a * t
    grad = np.repeat(grad, W, axis=1)
    img = Image.fromarray(grad.astype(np.uint8), "RGB")

    # Soft radial glow in the accent hue, upper-center
    glow = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(glow)
    cx, cy, r = W // 2, int(H * 0.38), 620
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(180))
    tint = Image.new("RGB", (W, H), accent)
    img = Image.composite(tint, img, glow)

    # A second, fainter glow low on the right for depth
    glow2 = Image.new("L", (W, H), 0)
    d2 = ImageDraw.Draw(glow2)
    cx2, cy2, r2 = int(W * 0.82), int(H * 0.85), 420
    d2.ellipse([cx2 - r2, cy2 - r2, cx2 + r2, cy2 + r2], fill=55)
    glow2 = glow2.filter(ImageFilter.GaussianBlur(150))
    img = Image.composite(tint, img, glow2)

    # Subtle grain so the gradient never bands
    rng = np.random.default_rng(42)
    noise = rng.normal(0, 2.2, (H, W, 1)).astype(np.float32)
    arr = np.asarray(img, dtype=np.float32) + noise
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    return img


def main():
    for name, spec in THEMES.items():
        img = make_wallpaper(spec["accent"], spec["bg_top"], spec["bg_bottom"])
        out = os.path.join(HERE, f"{name}.png")
        img.save(out, "PNG")
        print(f"wrote {out} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
