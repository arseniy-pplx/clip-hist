#!/usr/bin/env python3
"""Generate ClipHist app icon as PNG files at every macOS-required size.

We draw a rounded-corner squircle with a gradient fill, then layer a stylised
clipboard glyph on top. Output goes to scripts/build/AppIcon.iconset/.
The accompanying make-icon.sh script then runs `iconutil` (macOS only) to
turn it into AppIcon.icns.
"""
from __future__ import annotations
from PIL import Image, ImageDraw, ImageFilter
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(__file__), "build", "AppIcon.iconset")
os.makedirs(OUT_DIR, exist_ok=True)

# macOS .icns requires these (size, scale) pairs.
SPECS = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask

def render(size: int) -> Image.Image:
    # Render at 4x for AA, then downsample.
    SCALE = 4
    s = size * SCALE
    radius = int(s * 0.225)

    # Gradient background — Apple-style blue squircle.
    top = (88, 138, 240)   # #588AF0
    bot = (47, 88, 204)    # #2F58CC
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gradient = Image.new("RGB", (1, s))
    g_pix = gradient.load()
    for y in range(s):
        g_pix[0, y] = lerp(top, bot, y / max(1, s - 1))
    gradient = gradient.resize((s, s))
    bg.paste(gradient, (0, 0))

    # Apply rounded mask.
    bg.putalpha(rounded_mask(s, radius))

    # Subtle inner highlight along the top.
    highlight = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(highlight)
    d.rounded_rectangle(
        (int(s * 0.08), int(s * 0.06), int(s * 0.92), int(s * 0.55)),
        radius=int(s * 0.18),
        fill=(255, 255, 255, 50),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(s * 0.04))
    bg = Image.alpha_composite(bg, highlight)

    # Clipboard glyph — board + clip + content lines.
    glyph = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    g = ImageDraw.Draw(glyph)

    # Outer board (rounded rectangle).
    bx0, by0 = int(s * 0.27), int(s * 0.22)
    bx1, by1 = int(s * 0.73), int(s * 0.82)
    g.rounded_rectangle((bx0, by0, bx1, by1), radius=int(s * 0.045), fill=(255, 255, 255, 245))

    # Top clip — rounded rect overlapping the board's top edge.
    cw = int((bx1 - bx0) * 0.42)
    ch = int(s * 0.10)
    cx0 = (bx0 + bx1 - cw) // 2
    cy0 = by0 - ch // 2
    g.rounded_rectangle(
        (cx0, cy0, cx0 + cw, cy0 + ch),
        radius=int(ch * 0.40),
        fill=(60, 80, 160, 255),
    )
    # Clip top notch
    nw = int(cw * 0.35)
    nh = int(ch * 0.30)
    nx0 = cx0 + (cw - nw) // 2
    ny0 = cy0 - nh + 2
    g.rounded_rectangle(
        (nx0, ny0, nx0 + nw, ny0 + nh + 4),
        radius=int(nh * 0.4),
        fill=(60, 80, 160, 255),
    )

    # Content lines on the board.
    line_color = (90, 120, 180, 220)
    inner_left = bx0 + int(s * 0.035)
    inner_right = bx1 - int(s * 0.035)
    line_h = int(s * 0.025)
    y_cursor = by0 + int(s * 0.18)
    line_widths = [1.0, 0.85, 1.0, 0.65, 0.95]
    for w in line_widths:
        right = inner_left + int((inner_right - inner_left) * w)
        g.rounded_rectangle(
            (inner_left, y_cursor, right, y_cursor + line_h),
            radius=int(line_h / 2),
            fill=line_color,
        )
        y_cursor += int(s * 0.075)

    bg = Image.alpha_composite(bg, glyph)

    # Downsample to target size.
    return bg.resize((size, size), Image.LANCZOS)


def main():
    for (base, scale) in SPECS:
        px = base * scale
        img = render(px)
        suffix = "" if scale == 1 else "@2x"
        name = f"icon_{base}x{base}{suffix}.png"
        out = os.path.join(OUT_DIR, name)
        img.save(out, "PNG")
        print(f"  wrote {name} ({px}x{px})")
    # Also drop a 1024 PNG for the DMG background / README.
    img1024 = render(1024)
    img1024.save(os.path.join(os.path.dirname(__file__), "build", "AppIcon-1024.png"), "PNG")
    print("  wrote AppIcon-1024.png (1024x1024)")


if __name__ == "__main__":
    main()
