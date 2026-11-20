#!/usr/bin/env python3
"""
Imports every PNG in ArtSource/ into App/Assets.xcassets (asset name = file name).

- ArtSource/AppIcon.png becomes the app icon (1024×1024). If it's missing, a placeholder
  icon (red circle + white key) is generated so the build has no asset warnings.
- Every other PNG becomes an image set, e.g. game_chess.png → "game_chess".
- Also writes the AccentColor and LaunchBackground colour sets.

Re-run after adding or replacing images:  python3 Scripts/import_art.py
Pure standard library; no dependencies.
"""
import json
import math
import os
import shutil
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "ArtSource")
XC = os.path.join(ROOT, "App", "Assets.xcassets")
INFO = {"author": "xcode", "version": 1}


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")


def color_set(name, r, g, b):
    write_json(os.path.join(XC, f"{name}.colorset", "Contents.json"), {
        "colors": [{
            "color": {"color-space": "srgb", "components": {
                "alpha": "1.000", "red": f"0x{r:02X}", "green": f"0x{g:02X}", "blue": f"0x{b:02X}"}},
            "idiom": "universal"}],
        "info": INFO})


def png_bytes(width, height, pixel):
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(pixel(x, y))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))


def placeholder_icon(path, size=1024):
    """White background, red (#E8231C) circle, white key tilted 45° (bow top-right, teeth bottom-left)."""
    c = size / 2
    red, white = (0xE8, 0x23, 0x1C), (255, 255, 255)
    cos45 = math.cos(math.radians(45))

    def pixel(x, y):
        dx, dy = x + 0.5 - c, y + 0.5 - c
        if dx * dx + dy * dy > (size * 0.35) ** 2:
            return white
        # Rotate into key space: u along the key (bow at +u), v across.
        u = (dx - dy) * cos45
        v = (dx + dy) * cos45
        s = size / 1024
        bu, rr_out, rr_in = 150 * s, 105 * s, 52 * s
        d2 = (u - bu) ** 2 + v * v
        if rr_in ** 2 <= d2 <= rr_out ** 2:
            return white                         # bow (ring)
        if -230 * s <= u <= bu - 90 * s and abs(v) <= 30 * s:
            return white                         # shaft
        if -230 * s <= u <= -175 * s and 0 <= v <= 95 * s:
            return white                         # tooth 1
        if -140 * s <= u <= -95 * s and 0 <= v <= 70 * s:
            return white                         # tooth 2
        return red

    with open(path, "wb") as f:
        f.write(png_bytes(size, size, pixel))


def main():
    os.makedirs(XC, exist_ok=True)
    write_json(os.path.join(XC, "Contents.json"), {"info": INFO})
    color_set("AccentColor", 0xD3, 0x25, 0x1E)
    color_set("LaunchBackground", 0xF6, 0xF5, 0xF8)

    icon_dir = os.path.join(XC, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    icon_dst = os.path.join(icon_dir, "AppIcon.png")
    icon_src = os.path.join(ART, "AppIcon.png")
    if os.path.exists(icon_src):
        shutil.copyfile(icon_src, icon_dst)
        print("AppIcon: from ArtSource/AppIcon.png")
    elif not os.path.exists(icon_dst):
        placeholder_icon(icon_dst)
        print("AppIcon: generated placeholder (add ArtSource/AppIcon.png and re-run)")
    write_json(os.path.join(icon_dir, "Contents.json"), {
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": INFO})

    if os.path.isdir(ART):
        for name in sorted(os.listdir(ART)):
            if not name.lower().endswith(".png") or name == "AppIcon.png":
                continue
            asset = os.path.splitext(name)[0]
            d = os.path.join(XC, f"{asset}.imageset")
            if os.path.isdir(d):
                shutil.rmtree(d)
            os.makedirs(d)
            shutil.copyfile(os.path.join(ART, name), os.path.join(d, name))
            write_json(os.path.join(d, "Contents.json"), {
                "images": [{"filename": name, "idiom": "universal"}], "info": INFO})
            print(f"Image: {asset}")


if __name__ == "__main__":
    main()
