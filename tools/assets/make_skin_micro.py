"""A seamless tile of skin micro-relief - pores and fine crossing wrinkles - as a tangent normal map,
made from scratch (no source images):

    python tools/assets/make_skin_micro.py [--size 512] [--seed 11]

-> game/assets/characters/textures/skin/skin_micro_normal.png (OpenGL convention, +Y up). The skin
shader repeats it finely over the body's layout on top of the sculpted normals.
"""
import argparse
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "characters" / "textures" / "skin" / "skin_micro_normal.png"


def spectral(n, rng, beta, lo, hi):
    """Periodic noise with a 1/f^beta spectrum, band-limited to [lo, hi] cycles per tile, 0..1."""
    k = np.fft.fftfreq(n) * n
    kx, ky = np.meshgrid(k, k)
    r = np.sqrt(kx ** 2 + ky ** 2)
    r[0, 0] = 1
    amp = r ** (-beta / 2)
    amp[(r < lo) | (r > hi)] = 0
    f = np.real(np.fft.ifft2(amp * np.exp(2j * np.pi * rng.random((n, n)))))
    f -= f.min()
    return f / f.max()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--seed", type=int, default=11)
    a = ap.parse_args()
    n, rng = a.size, np.random.default_rng(a.seed)
    h = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    for px, py in rng.random((int(2600 * (n / 512) ** 2), 2)) * n:     # pores: little dips, wrapped round
        dx = (xx - px + n / 2) % n - n / 2
        dy = (yy - py + n / 2) % n - n / 2
        r2 = dx * dx + dy * dy
        m = r2 < 36
        h[m] -= np.exp(-r2[m] / (2 * 1.3 ** 2)) * (0.6 + 0.4 * rng.random())
    k = np.fft.fftfreq(n) * n
    kx, ky = np.meshgrid(k, k)
    band = ((np.abs(kx) < 2) | (np.abs(ky) < 2) | (np.abs(kx - ky) < 2)) & (np.sqrt(kx ** 2 + ky ** 2) > 25)
    lines = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * band))   # creases on three slants
    lines = (lines - lines.min()) / (lines.max() - lines.min())
    h = h + (spectral(n, rng, 1.0, 20, 120) - 0.5) * 0.5 - np.abs(lines - 0.5) * 0.4
    h = (h - h.min()) / (h.max() - h.min())
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 6
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 6
    nrm = np.dstack([-gx, gy, np.ones_like(h)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT)
    print("SKIN MICRO", OUT)


if __name__ == "__main__":
    main()
