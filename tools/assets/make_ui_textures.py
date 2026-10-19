"""Interface frames for Passage, made from scratch (no source images).

Nine-patch textures for the interface's panels, buttons and slots: dark worn fill, a bevelled
bronze edge, small corner brackets. Drawn at 4x and reduced, so edges are smooth. Panels tile
their centre and edges (the grain is periodic), buttons and slots stretch (they have no grain).
Outputs into game/assets/ui/ and a manifest row per file in tools/assets/MANIFEST.csv. The
margins each file is cut at are the constants in game/scripts/ui/ui_theme.gd (UiTheme.FRAMES).

Usage:  python tools/assets/make_ui_textures.py [--seed 3]
"""
import argparse
import csv
import datetime
import pathlib

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "ui"
MANIFEST = ROOT / "tools" / "assets" / "MANIFEST.csv"
SS = 4    # supersampling


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def periodic_grain(n, period, rng, amount):
    """Grain that repeats every `period` pixels: an FFT of a random spectrum is periodic."""
    f = np.fft.fftfreq(period) * period
    r = np.sqrt(f[None, :] ** 2 + f[:, None] ** 2)
    amp = np.zeros_like(r)
    amp[r >= 1.0] = 1.0 / np.power(r[r >= 1.0], 0.6)
    field = np.real(np.fft.ifft2(amp * np.exp(1j * rng.uniform(0, 2 * np.pi, (period, period)))))
    field = (field - field.mean()) / (field.std() + 1e-9)
    reps = int(np.ceil(n / period))
    return np.tile(field, (reps, reps))[:n, :n] * amount


def bevel(draw, box, light, dark, width):
    """A frame `width` thick inside `box`: light on the top and left, dark on the bottom and right."""
    x0, y0, x1, y1 = box
    for i in range(width):
        t = i / max(1, width - 1)
        lc = tuple(int(light[k] * (1 - 0.35 * t) + dark[k] * 0.35 * t) for k in range(3)) + (light[3],)
        dc = tuple(int(dark[k]) for k in range(3)) + (dark[3],)
        draw.line([(x0 + i, y1 - i), (x0 + i, y0 + i), (x1 - i, y0 + i)], fill=lc, width=1)
        draw.line([(x1 - i, y0 + i), (x1 - i, y1 - i), (x0 + i, y1 - i)], fill=dc, width=1)


def corner_brackets(draw, n, inset, length, thick, color, rivet):
    """An L of bronze in each corner, with a small diamond rivet where the arms meet."""
    for cx, cy, sx, sy in [(inset, inset, 1, 1), (n - 1 - inset, inset, -1, 1), (inset, n - 1 - inset, 1, -1), (n - 1 - inset, n - 1 - inset, -1, -1)]:
        draw.line([(cx, cy + sy * length), (cx, cy), (cx + sx * length, cy)], fill=color, width=thick, joint="curve")
        r = rivet
        draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=hexc("e0bd6a"))


def make_panel(rng, fill_hex, edge_light, edge_dark, bracket, size=96, margin=24):
    n = size * SS
    base = np.zeros((size, size, 4), np.float32)
    fill = np.array(hexc(fill_hex), np.float32)
    grain = periodic_grain(size, size - 2 * margin, rng, 3.2)
    base[..., :3] = fill[:3] + grain[..., None]
    base[..., 3] = 255
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGBA").resize((n, n), Image.NEAREST)
    d = ImageDraw.Draw(img)
    # outer dark line, the bronze bevel, a dark line inside it, a faint inner highlight
    d.rectangle([0, 0, n - 1, n - 1], outline=(4, 3, 2, 255), width=1 * SS)
    bevel(d, (1 * SS, 1 * SS, n - 1 - 1 * SS, n - 1 - 1 * SS), hexc(edge_light), hexc(edge_dark), 2 * SS)
    d.rectangle([3 * SS, 3 * SS, n - 1 - 3 * SS, n - 1 - 3 * SS], outline=(8, 6, 4, 255), width=1 * SS)
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rectangle([4 * SS, 4 * SS, n - 1 - 4 * SS, n - 1 - 4 * SS], outline=hexc(edge_dark, 90), width=1 * SS)
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    if bracket:
        corner_brackets(d, n, 9 * SS, 11 * SS, 2 * SS, hexc(edge_light), int(2.6 * SS))
    return img.resize((size, size), Image.LANCZOS)


def make_button(top_hex, bottom_hex, border_hex, highlight_a, size=48):
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top, bottom = hexc(top_hex), hexc(bottom_hex)
    for y in range(n):
        t = y / (n - 1)
        d.line([(0, y), (n - 1, y)], fill=tuple(int(top[k] * (1 - t) + bottom[k] * t) for k in range(3)) + (255,))
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=3 * SS, outline=(4, 3, 2, 255), width=1 * SS)
    d.rounded_rectangle([1 * SS, 1 * SS, n - 1 - 1 * SS, n - 1 - 1 * SS], radius=2 * SS, outline=hexc(border_hex), width=1 * SS)
    if highlight_a > 0:
        shine = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ImageDraw.Draw(shine).line([(3 * SS, 2 * SS + SS // 2), (n - 1 - 3 * SS, 2 * SS + SS // 2)], fill=(255, 240, 200, highlight_a), width=SS)
        img = Image.alpha_composite(img, shine)
    return img.resize((size, size), Image.LANCZOS)


def make_slot(size=64):
    """A well sunk into the surface: dark, shadowed toward the rim, a thin bronze lip."""
    n = size * SS
    a = np.zeros((n, n, 4), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    edge = np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy)) / SS
    shade = np.clip(edge / 9.0, 0.0, 1.0) ** 0.7
    inner = np.array(hexc("15120f"), np.float32)
    rim = np.array(hexc("050403"), np.float32)
    a[..., :3] = rim[:3] + (inner[:3] - rim[:3]) * shade[..., None]
    a[..., 3] = 255
    img = Image.fromarray(a.astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, n - 1, n - 1], outline=(0, 0, 0, 255), width=SS)
    bevel(d, (1 * SS, 1 * SS, n - 1 - 1 * SS, n - 1 - 1 * SS), hexc("3c2f1e"), hexc("6e5634"), 2 * SS)   # lit from below: a sunken lip
    return img.resize((size, size), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=3)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)
    OUT.mkdir(parents=True, exist_ok=True)
    made = {
        "panel.png": (make_panel(rng, "1c1814", "9c7c4a", "4a381f", True), "panel frame: grain fill, bronze bevel, corner brackets"),
        "panel_plain.png": (make_panel(rng, "171410", "6f5a38", "3a2c1a", False), "inner panel / tooltip frame, no brackets"),
        "panel_nether.png": (make_panel(rng, "15101f", "8a6fd0", "3a2a66", True), "the Netherecho's panel frame"),
        "button.png": (make_button("2e271f", "211c16", "5a4629", 34), "button, normal"),
        "button_hover.png": (make_button("3d3326", "2a231b", "d2ab52", 52), "button, hovered"),
        "button_pressed.png": (make_button("15120e", "201a14", "d2ab52", 0), "button, pressed / selected"),
        "button_disabled.png": (make_button("1b1815", "171411", "2f2820", 0), "button, disabled"),
        "slot.png": (make_slot(), "sunken slot well (hotbar, pack cells, equipment slots)"),
    }
    rows = []
    for name, (img, note) in made.items():
        img.save(OUT / name)
        rows.append(["assets/ui/" + name, "generated", "tools/assets/make_ui_textures.py", "own work (no source images)", note])

    old = []
    if MANIFEST.exists():
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            old = [r for r in csv.reader(f)][1:]
    done = {r[0] for r in rows}
    stamp = datetime.date.today().isoformat()
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["path", "origin", "made_by", "licence", "note", "date"])
        for r in old:
            if r[0] not in done:
                w.writerow(r)
        for r in rows:
            w.writerow(r + [stamp])
    print("wrote %d files to %s (seed %d)" % (len(rows), OUT, a.seed))


if __name__ == "__main__":
    main()
