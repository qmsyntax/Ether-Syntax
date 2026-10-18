"""Seamless PBR ground textures for Passage, made from scratch (no source images).

Every field is built so it tiles: noise is synthesised in the frequency domain (an FFT of a
random spectrum is periodic by construction) and cell patterns measure distance on a torus.
Outputs, per material, into game/assets/textures/ground/:
    <name>_albedo.png   sRGB colour
    <name>_normal.png   tangent-space normal (OpenGL convention, +Y up)
    <name>_rough.png    roughness, linear grey
and a manifest row per file in game/assets/MANIFEST.csv.

Usage:  python tools/assets/make_ground_textures.py [--size 1024] [--seed 7]
"""
import argparse
import csv
import datetime
import pathlib

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "textures" / "ground"
MANIFEST = ROOT / "game" / "assets" / "MANIFEST.csv"


# --- tileable building blocks -------------------------------------------------------------

def spectral(n, rng, beta=2.0, lo=1.0, hi=None):
    """Periodic noise with a 1/f^beta power spectrum, band-limited to [lo, hi] cycles per tile.
    Returned in 0..1."""
    fx = np.fft.fftfreq(n) * n
    fy = np.fft.fftfreq(n) * n
    f = np.sqrt(fx[None, :] ** 2 + fy[:, None] ** 2)
    amp = np.zeros_like(f)
    band = f >= lo
    if hi is not None:
        band &= f <= hi
    amp[band] = 1.0 / np.power(f[band], beta / 2.0)
    phase = rng.uniform(0, 2 * np.pi, (n, n))
    field = np.real(np.fft.ifft2(amp * np.exp(1j * phase)))
    field -= field.min()
    return field / max(field.max(), 1e-9)


def worley(n, rng, cells):
    """Periodic cellular noise: returns (F1, F2, id) for `cells` x `cells` jittered points,
    distances in pixels measured on the torus."""
    pts = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells)), -1).reshape(-1, 2)
           + rng.uniform(0.1, 0.9, (cells * cells, 2))) * (n / cells)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), np.inf, np.float32)
    f2 = np.full((n, n), np.inf, np.float32)
    ids = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, n - dx)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, i, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids


def blur(a, radius):
    """Periodic Gaussian blur through the FFT."""
    n = a.shape[0]
    fx = np.fft.fftfreq(n)
    g = np.exp(-2 * (np.pi * radius) ** 2 * (fx[None, :] ** 2 + fx[:, None] ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normal_from_height(h, strength):
    """Tangent-space normal map (OpenGL, +Y up) from a 0..1 height field, wrapping at the edges."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def baked_shade(h, strength=0.22, cavity=0.5):
    """Light from the upper left and darken the hollows, baked into the colour, so small relief
    still reads from far above where the normal map is too fine to resolve."""
    nrm = normal_from_height(h, 14.0) * 2.0 - 1.0
    light = np.array([-0.45, 0.45, 0.77])
    lam = np.clip((nrm * light).sum(-1), 0, 1)
    ao = np.clip((blur(h, 6.0) - h) * 6.0, 0, 1)
    return (1.0 - strength + strength * 1.6 * lam) * (1.0 - cavity * ao)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def save(name, kind, arr, note, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}_{kind}.png"
    if arr.ndim == 2:
        img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
    else:
        img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    img.save(path, optimize=True)
    rows.append([str(path.relative_to(ROOT / "game")).replace("\\", "/"), "generated", "tools/assets/make_ground_textures.py", "own work (no source images)", note])


# --- materials --------------------------------------------------------------------------

def dry_earth(n, rng, rows):
    """Packed dry earth with a crack network, grit and scattered pebbles: the Stubble's floor."""
    broad = spectral(n, rng, beta=2.6, lo=1, hi=24)
    mid = spectral(n, rng, beta=2.0, lo=6, hi=96)
    grain = spectral(n, rng, beta=0.6, lo=96)
    f1, f2, _ = worley(n, rng, 9)
    edge = f2 - f1                                             # 0 on a cell border
    crack = 1.0 - smooth(0.0, 2.2 + 2.0 * mid, edge)          # narrow, a little uneven
    crack *= smooth(0.5, 0.75, spectral(n, rng, beta=2.2, lo=2, hi=20))   # cracks only in places
    # pebbles: small cells, only some of them, raised and rounded
    p1, _, pid = worley(n, rng, 40)
    keep = (np.sin(pid * 12.9898) * 43758.5453 % 1.0) > 0.55
    size = 2.5 + 6.0 * ((np.sin(pid * 78.233) * 12345.678) % 1.0) ** 2
    pebble = np.where(keep, np.clip(1.0 - p1 / size, 0.0, 1.0), 0.0) ** 0.6
    height = 0.55 * broad + 0.25 * mid + 0.06 * grain - 0.35 * crack + 0.45 * pebble
    height = (height - height.min()) / (height.max() - height.min())

    earth_light = np.array([0.47, 0.38, 0.27])
    earth_dark = np.array([0.27, 0.215, 0.165])
    ashen = np.array([0.40, 0.37, 0.33])
    stone = np.array([0.40, 0.37, 0.33])
    base = lerp(np.broadcast_to(earth_dark, (n, n, 3)), np.broadcast_to(earth_light, (n, n, 3)), smooth(0.2, 0.85, broad))
    base = lerp(base, np.broadcast_to(ashen, (n, n, 3)), 0.35 * smooth(0.55, 0.9, spectral(n, rng, beta=2.4, lo=2, hi=16)))
    base *= (0.86 + 0.28 * mid)[..., None]
    base *= (0.92 + 0.16 * grain)[..., None]
    base *= (1.0 - 0.55 * crack)[..., None]
    tint = 0.7 + 0.55 * ((np.sin(pid * 3.17) * 999.1) % 1.0)
    pebble_col = stone[None, None, :] * tint[..., None] * (0.75 + 0.35 * grain)[..., None]
    base = lerp(base, pebble_col, smooth(0.05, 0.3, pebble))
    base *= baked_shade(height)[..., None]
    rough = np.clip(0.9 - 0.18 * pebble + 0.05 * grain, 0, 1)

    save("dry_earth", "albedo", base, "Stubble ground: packed earth, cracks, pebbles", rows)
    save("dry_earth", "normal", normal_from_height(height, 18.0), "", rows)
    save("dry_earth", "rough", rough, "", rows)
    return height


def dry_grass(n, rng, rows):
    """Flattened dead grass and straw lying on earth: thousands of strands drawn with wrap-around,
    so the tile repeats seamlessly. The second ground layer, blended in by the macro mask."""
    k = 3                                                     # draw large, then shrink: soft, even strokes
    big = n * k
    col_img = Image.new("RGB", (big, big), (0, 0, 0))
    hgt_img = Image.new("L", (big, big), 0)
    dc = ImageDraw.Draw(col_img)
    dh = ImageDraw.Draw(hgt_img)
    soil = spectral(n, rng, beta=2.2, lo=2, hi=40)
    lean = rng.uniform(0, np.pi)                              # strands mostly lie one way, flattened by weather
    palette = [(168, 146, 92), (138, 116, 70), (190, 168, 112), (112, 94, 58), (150, 134, 86), (126, 118, 78)]
    for i in range(15000):
        x, y = rng.uniform(0, big, 2)
        ang = lean + rng.normal(0, 0.55)
        length = rng.uniform(18, 70) * k
        bend = rng.normal(0, 0.25)
        c = palette[rng.integers(len(palette))]
        shade = rng.uniform(0.75, 1.15)
        c = tuple(int(min(255, v * shade)) for v in c)
        w = int(rng.choice([2, 3, 3, 4, 5])) * k
        pts = []
        for t in np.linspace(0, 1, 6):
            a2 = ang + bend * t
            pts.append((x + np.cos(a2) * length * t, y + np.sin(a2) * length * t))
        hv = int(120 + 135 * (i / 15000.0))                   # later strands lie on top
        for ox in (-big, 0, big):
            for oy in (-big, 0, big):
                q = [(px + ox, py + oy) for px, py in pts]
                dc.line(q, fill=c, width=w, joint="curve")
                dh.line(q, fill=hv, width=w, joint="curve")
    col = np.asarray(col_img.resize((n, n), Image.LANCZOS)).astype(np.float32) / 255.0
    cover = np.asarray(hgt_img.resize((n, n), Image.LANCZOS)).astype(np.float32) / 255.0
    earth = np.array([0.27, 0.22, 0.165])[None, None, :] * (0.8 + 0.35 * soil)[..., None]
    covered = smooth(0.05, 0.35, cover)
    base = lerp(earth, col, covered)
    height = 0.75 * cover + 0.25 * soil
    base *= baked_shade(height, 0.25, 0.7)[..., None]
    rough = np.clip(0.8 + 0.12 * (1 - covered), 0, 1)
    save("dry_grass", "albedo", base, "Stubble ground: dead grass and straw", rows)
    save("dry_grass", "normal", normal_from_height(blur(height, 0.7), 9.0), "", rows)
    save("dry_grass", "rough", rough, "", rows)


def macro(n, rng, rows):
    """A large, soft variation map (R: tone, G: grass mask, B: damp) laid over many tiles so
    the repeat never shows."""
    r = spectral(n, rng, beta=3.0, lo=1, hi=12)
    g = smooth(0.3, 0.78, spectral(n, rng, beta=2.6, lo=1, hi=16))
    b = smooth(0.6, 0.85, spectral(n, rng, beta=3.0, lo=1, hi=10))
    save("ground_macro", "mask", np.stack([r, g, b], -1), "large-scale variation and grass mask", rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)
    rows = []
    dry_earth(a.size, rng, rows)
    dry_grass(a.size, rng, rows)
    macro(512, rng, rows)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    old = []
    if MANIFEST.exists():
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            old = [r for r in csv.reader(f)][1:]
    made = {r[0] for r in rows}
    stamp = datetime.date.today().isoformat()
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["path", "origin", "made_by", "licence", "note", "date"])
        for r in old:
            if r[0] not in made:
                w.writerow(r)
        for r in rows:
            w.writerow(r + [stamp])
    print("wrote %d files to %s (seed %d, %d px)" % (len(rows), OUT, a.seed, a.size))


if __name__ == "__main__":
    main()
