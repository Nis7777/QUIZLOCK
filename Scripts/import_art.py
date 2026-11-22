#!/usr/bin/env python3
"""
Imports every PNG in ArtSource/ into App/Assets.xcassets (asset name = file name).

- ArtSource/AppIcon.png becomes the app icon: resized to exactly 1024×1024 and flattened onto
  white (no transparency). A copy also goes into the shield extension as `shield_icon`.
  If it's missing, a placeholder icon is generated so the build has no asset warnings.
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
import subprocess
import zlib

ROOT = os.environ.get("LOCKIE_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "ArtSource")
XC = os.path.join(ROOT, "App", "Assets.xcassets")
SHIELD_XC = os.path.join(ROOT, "Extensions", "ShieldConfigurationExt", "Assets.xcassets")
ICON_SIZE = 1024
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


# --- Minimal PNG reader (8-bit, non-interlaced: grey, RGB, palette, grey+alpha, RGBA) ---

def read_png(path):
    """Returns (width, height, rows) where rows[y] is a list of (r, g, b, a) tuples."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, palette, trns = 8, bytearray(), None, None
    width = height = depth = ctype = interlace = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif tag == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
    if depth != 8 or interlace != 0 or ctype not in (0, 2, 3, 4, 6):
        raise ValueError(f"unsupported PNG (depth {depth}, colour type {ctype}, interlace {interlace})")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = width * channels
    raw = zlib.decompress(bytes(idat))
    prev = bytearray(stride)
    rows = []
    i = 0
    for _ in range(height):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        bpp = channels
        if ftype == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 0xFF
        elif ftype == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 0xFF
        elif ftype == 3:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 0xFF
        elif ftype == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 0xFF
        prev = line
        if ctype == 6:
            px = [tuple(line[x:x + 4]) for x in range(0, stride, 4)]
        elif ctype == 2:
            px = [(line[x], line[x + 1], line[x + 2], 255) for x in range(0, stride, 3)]
        elif ctype == 4:
            px = [(line[x], line[x], line[x], line[x + 1]) for x in range(0, stride, 2)]
        elif ctype == 0:
            px = [(v, v, v, 255) for v in line]
        else:
            px = [palette[v] + ((trns[v] if trns and v < len(trns) else 255),) for v in line]
        rows.append(px)
    return width, height, rows


def flatten_and_resize(src, dst, size=ICON_SIZE, background=(255, 255, 255)):
    """Composites onto `background` (removes alpha) and resizes to size×size (area averaging)."""
    w, h, rows = read_png(src)
    flat = []
    for row in rows:
        out = []
        for r, g, b, a in row:
            if a == 255:
                out.append((r, g, b))
            else:
                k = a / 255.0
                out.append(tuple(int(round(c * k + bg * (1 - k))) for c, bg in zip((r, g, b), background)))
        flat.append(out)
    sx, sy = w / size, h / size

    def pixel(x, y):
        x0, x1 = x * sx, (x + 1) * sx
        y0, y1 = y * sy, (y + 1) * sy
        acc = [0.0, 0.0, 0.0]
        total = 0.0
        yy = int(y0)
        while yy < y1 and yy < h:
            wy = min(y1, yy + 1) - max(y0, yy)
            xx = int(x0)
            while xx < x1 and xx < w:
                wx = min(x1, xx + 1) - max(x0, xx)
                wgt = wx * wy
                p = flat[yy][xx]
                acc[0] += p[0] * wgt
                acc[1] += p[1] * wgt
                acc[2] += p[2] * wgt
                total += wgt
                xx += 1
            yy += 1
        return bytes(int(round(c / total)) for c in acc)

    with open(dst, "wb") as f:
        f.write(png_bytes(size, size, pixel))
    return w, h


def prepare_icon(src, dst):
    """Resize to 1024×1024 and strip alpha. Falls back to macOS `sips` for unusual PNGs."""
    try:
        w, h, rows = read_png(src)
        if (w, h) == (ICON_SIZE, ICON_SIZE) and all(px[3] == 255 for row in rows for px in row):
            shutil.copyfile(src, dst)
            print(f"AppIcon: already {ICON_SIZE}×{ICON_SIZE} with no transparency, copied as-is")
            return
        w, h = flatten_and_resize(src, dst)
        print(f"AppIcon: {w}×{h} → {ICON_SIZE}×{ICON_SIZE}, alpha removed")
        return
    except ValueError as e:
        if not shutil.which("sips"):
            raise SystemExit(f"Can't process {src}: {e}. Re-save it as an 8-bit PNG and try again.")
        print(f"AppIcon: {e}; using sips instead")
    tmp = dst + ".tmp.jpg"
    subprocess.run(["sips", "-z", str(ICON_SIZE), str(ICON_SIZE), "-s", "format", "jpeg", src, "--out", tmp],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["sips", "-s", "format", "png", tmp, "--out", dst], check=True, stdout=subprocess.DEVNULL)
    os.remove(tmp)


def placeholder_icon(path, size=1024):
    """Fallback only (used when ArtSource/AppIcon.png is missing): white background, coral circle, white key shape."""
    c = size / 2
    red, white = (0xFF, 0x5A, 0x36), (255, 255, 255)
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
    color_set("AccentColor", 0xFF, 0x5A, 0x36)
    color_set("LaunchBackground", 0xFF, 0xF1, 0xEC)  # peach, matches the splash

    icon_dir = os.path.join(XC, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    icon_dst = os.path.join(icon_dir, "AppIcon.png")
    icon_src = os.path.join(ART, "AppIcon.png")
    if os.path.exists(icon_src):
        prepare_icon(icon_src, icon_dst)
        # A copy for the shield (block screen) extension.
        write_json(os.path.join(SHIELD_XC, "Contents.json"), {"info": INFO})
        shield_dir = os.path.join(SHIELD_XC, "shield_icon.imageset")
        os.makedirs(shield_dir, exist_ok=True)
        shutil.copyfile(icon_dst, os.path.join(shield_dir, "shield_icon.png"))
        write_json(os.path.join(shield_dir, "Contents.json"), {
            "images": [{"filename": "shield_icon.png", "idiom": "universal"}], "info": INFO})
        print("shield_icon: copied into ShieldConfigurationExt")
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
            dst = os.path.join(d, name)
            how = downscale(os.path.join(ART, name), dst, max_dimension(asset))
            write_json(os.path.join(d, "Contents.json"), {
                "images": [{"filename": name, "idiom": "universal"}], "info": INFO})
            print(f"Image: {asset} ({how})")


def max_dimension(asset):
    """Display-size caps (MOTION.md performance), @3x: mascots ≤ ~260pt, square game icons ≤ 200pt."""
    if asset.startswith("mascot_"):
        return 780
    if asset.startswith("game_"):
        return 600
    return None


def downscale(src, dst, max_dim):
    """Copies src to dst, shrinking so the longest side is ≤ max_dim (Pillow, else macOS sips, else as-is)."""
    if max_dim:
        try:
            from PIL import Image  # optional
            with Image.open(src) as im:
                if max(im.size) > max_dim:
                    im.thumbnail((max_dim, max_dim), Image.LANCZOS)
                    im.save(dst, optimize=True)
                    return f"resized to {im.size[0]}×{im.size[1]}"
        except ImportError:
            if shutil.which("sips"):
                shutil.copyfile(src, dst)
                subprocess.run(["sips", "-Z", str(max_dim), dst], check=True, stdout=subprocess.DEVNULL)
                return f"resized to ≤{max_dim}px (sips)"
    shutil.copyfile(src, dst)
    return "copied"


if __name__ == "__main__":
    main()
