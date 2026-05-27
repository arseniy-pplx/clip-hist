#!/usr/bin/env python3
"""Generate a DMG installer background showing 'drag app → Applications' hint."""
from __future__ import annotations
from PIL import Image, ImageDraw, ImageFont
import os
import sys

W, H = 540, 380
OUT = os.path.join(os.path.dirname(__file__), "build", "dmg-background.png")
OUT2X = os.path.join(os.path.dirname(__file__), "build", "dmg-background@2x.png")

def gradient(top, bot, w, h):
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return img.resize((w, h))

def find_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()

def render(scale: int = 1) -> Image.Image:
    w, h = W * scale, H * scale
    bg = gradient((242, 246, 252), (220, 228, 244), w, h).convert("RGBA")
    d = ImageDraw.Draw(bg)

    title_font = find_font(22 * scale)
    sub_font = find_font(13 * scale)

    # Title
    title = "Install ClipHist"
    tw = d.textlength(title, font=title_font)
    d.text(((w - tw) / 2, 22 * scale), title, fill=(40, 60, 100, 255), font=title_font)

    # Subtitle
    sub = "Drag ClipHist into the Applications folder."
    sw = d.textlength(sub, font=sub_font)
    d.text(((w - sw) / 2, 56 * scale), sub, fill=(80, 95, 130, 255), font=sub_font)

    # Arrow between the two icon positions.
    # create-dmg places icons at (140, 200) and (400, 200) by default in our config.
    # In a 540x380 image those Y coords are roughly center.
    cy = 230 * scale
    ax0 = 220 * scale
    ax1 = 320 * scale
    arrow_color = (140, 160, 200, 220)
    d.line([(ax0, cy), (ax1, cy)], fill=arrow_color, width=4 * scale)
    # Arrowhead
    d.polygon(
        [(ax1, cy), (ax1 - 14 * scale, cy - 8 * scale), (ax1 - 14 * scale, cy + 8 * scale)],
        fill=arrow_color,
    )

    # Footer
    foot = "After installing, launch ClipHist and grant Accessibility permission."
    fw = d.textlength(foot, font=sub_font)
    d.text(((w - fw) / 2, h - 36 * scale), foot, fill=(110, 125, 160, 255), font=sub_font)

    return bg

os.makedirs(os.path.dirname(OUT), exist_ok=True)
render(1).save(OUT, "PNG")
render(2).save(OUT2X, "PNG")
print(f"  wrote {OUT}")
print(f"  wrote {OUT2X}")
