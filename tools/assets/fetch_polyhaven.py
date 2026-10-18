"""Fetch CC0 models from Poly Haven (https://polyhaven.com, licence CC0) into game/assets/models/.

Brent 2026-10-18: standing OK to download CC0 assets from Poly Haven and ambientCG. Every file
fetched gets a row in tools/assets/MANIFEST.csv with its source URL and licence.

Usage:  python tools/assets/fetch_polyhaven.py --res 1k id [id ...]
Files go first to a staging folder (--stage), are checked (sizes, paths stay inside the asset's
folder), and only then copied into game/assets/models/polyhaven/<id>/.
"""
import argparse
import csv
import datetime
import json
import pathlib
import shutil
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEST = ROOT / "game" / "assets" / "models" / "polyhaven"
MANIFEST = ROOT / "tools" / "assets" / "MANIFEST.csv"
API = "https://api.polyhaven.com"
UA = {"User-Agent": "passage-asset-fetch/1.0"}


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return json.load(r)


def download(url, path, expect_size):
    path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r, open(path, "wb") as f:
        shutil.copyfileobj(r, f)
    got = path.stat().st_size
    if expect_size and got != expect_size:
        raise RuntimeError("%s: %d bytes, expected %d" % (url, got, expect_size))


def safe_rel(rel):
    p = pathlib.PurePosixPath(rel)
    if p.is_absolute() or ".." in p.parts:
        raise RuntimeError("unsafe path in asset: %s" % rel)
    return p


def _merge_alpha(files, res, work):
    """Poly Haven's glTF foliage ships its leaf colour as a JPEG with no transparency; the mask is
    a separate "Alpha" map. Put the mask into the colour texture (as an RGBA PNG), point the glTF
    at it, and mark blended materials as cut-outs (MASK) - leaves are cut out, not see-through."""
    alpha = files.get("Alpha", {}).get(res, {})
    if not alpha:
        return
    entry = alpha.get("png") or next(iter(alpha.values()))
    mask_path = work / "textures" / "_alpha.png"
    download(entry["url"], mask_path, entry.get("size"))
    from PIL import Image
    gltf_path = next(work.glob("*.gltf"))
    g = json.load(open(gltf_path, encoding="utf-8"))
    mask = Image.open(mask_path).convert("L")
    for img in g.get("images", []):
        uri = img.get("uri", "")
        if "_diff_" not in uri:
            continue
        src = work / safe_rel(uri)
        rgba = Image.open(src).convert("RGB")
        m = mask if mask.size == rgba.size else mask.resize(rgba.size)
        rgba.putalpha(m)
        new_uri = uri.rsplit(".", 1)[0] + "_rgba.png"
        rgba.save(work / safe_rel(new_uri))
        img["uri"] = new_uri
        img.pop("mimeType", None)
    for mat in g.get("materials", []):
        if mat.get("alphaMode") == "BLEND":
            mat["alphaMode"] = "MASK"
            mat["alphaCutoff"] = 0.45
    json.dump(g, open(gltf_path, "w", encoding="utf-8"))
    mask_path.unlink()


def fetch(asset_id, res, stage, rows):
    files = get_json("%s/files/%s" % (API, asset_id))
    entry = files["gltf"][res]["gltf"]
    work = stage / asset_id
    if work.exists():
        shutil.rmtree(work)
    gltf_name = pathlib.PurePosixPath(entry["url"]).name
    download(entry["url"], work / gltf_name, entry.get("size"))
    for rel, inc in entry.get("include", {}).items():
        download(inc["url"], work / safe_rel(rel), inc.get("size"))
    _merge_alpha(files, res, work)
    out = DEST / asset_id
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(work, out)
    page = "https://polyhaven.com/a/%s" % asset_id
    for f in sorted(out.rglob("*")):
        if f.is_file():
            rows.append([str(f.relative_to(ROOT / "game")).replace("\\", "/"), "downloaded", page, "CC0 (Poly Haven)", "%s glTF %s" % (asset_id, res)])
    total = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    print("%-28s %6.1f MB" % (asset_id, total / 1e6))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--res", default="1k")
    ap.add_argument("--stage", required=True)
    a = ap.parse_args()
    stage = pathlib.Path(a.stage)
    rows = []
    for asset_id in a.ids:
        fetch(asset_id, a.res, stage, rows)
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


if __name__ == "__main__":
    main()
