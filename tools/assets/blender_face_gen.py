"""A generated face, projected onto the body's own texture, inside Blender (headless). Two steps:

    blender -b --python tools/assets/blender_face_gen.py -- depth <prepared body.blend> <out dir>
        writes <out dir>/depth.png (the head from the front, near = white) and camera.json

    (tools/assets/comfy_face.py sends depth.png to ComfyUI: FLUX with a depth ControlNet paints a
     photographic, fictional face on exactly that shape -> face.png)

    blender -b --python tools/assets/blender_face_gen.py -- project <prepared body.blend> <out dir> \
        <base skin png> <out png> [size]
        [size] [face file]
        projects <out dir>/face.png (or the face file named) from the same camera onto every texel of the body that faces it
        and is not hidden, fading out as the surface turns away, over <base skin png> (a photo skin
        in the same form: variation around the average, 0.5 = average), and writes <out png>.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_body_prep as prep  # noqa: E402

RES = 1024


def setup(prepared):
    bpy.ops.wm.open_mainfile(filepath=prepared)
    arm = bpy.data.objects["Character"]
    arm.data.pose_position = "REST"
    body = bpy.data.objects["body"]
    eyes = bpy.data.objects["eyes"]
    bpy.context.view_layer.update()
    return arm, body, eyes


def camera_for(body, eyes):
    """A portrait camera straight in front of the face: position, look target, vertical field of view."""
    ept = np.array([tuple(eyes.matrix_world @ v.co) for v in eyes.data.vertices])
    eye = ept.mean(axis=0)
    target = eye + np.array([0.0, 0.0, -0.035])           # the middle of the face, a little below the eyes
    pos = target + np.array([0.0, -0.75, 0.0])           # the body faces -Y
    fov = math.radians(26.0)                              # head and a little of the neck
    return pos, target, fov


def basis(pos, target):
    fwd = target - pos
    fwd = fwd / np.linalg.norm(fwd)
    right = np.cross(fwd, np.array([0.0, 0.0, 1.0]))
    right = right / np.linalg.norm(right)
    up = np.cross(right, fwd)
    return fwd, right, up


def tree_of(objs):
    bm = bmesh.new()
    for o in objs:
        t = bmesh.new()
        t.from_mesh(o.data)
        t.transform(o.matrix_world)
        me = bpy.data.meshes.new("tmp")
        t.to_mesh(me)
        t.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def depth_map(tree, pos, target, fov, res=RES):
    fwd, right, up = basis(pos, target)
    half = math.tan(fov * 0.5)
    depth = np.full((res, res), np.inf, dtype=np.float32)
    origin = Vector(tuple(pos))
    for y in range(res):
        sy = (1.0 - (y + 0.5) / res * 2.0) * half
        for x in range(res):
            sx = ((x + 0.5) / res * 2.0 - 1.0) * half
            d = fwd + right * sx + up * sy
            d = d / np.linalg.norm(d)
            hit = tree.ray_cast(origin, Vector(tuple(d)), 3.0)
            if hit[0] is not None:
                depth[y, x] = float(np.dot(np.array(tuple(hit[0])) - pos, fwd))
    return depth


def do_depth(prepared, out_dir):
    arm, body, eyes = setup(prepared)
    pos, target, fov = camera_for(body, eyes)
    tree = tree_of([body, eyes])
    depth = depth_map(tree, pos, target, fov)
    hit = np.isfinite(depth)
    near, far = depth[hit].min(), depth[hit].min() + 0.20
    img = np.zeros((RES, RES, 4), np.float32)
    v = np.clip((far - depth) / (far - near), 0.0, 1.0) ** 1.3
    v[~hit] = 0.0
    img[..., 0] = img[..., 1] = img[..., 2] = v
    img[..., 3] = 1.0
    os.makedirs(out_dir, exist_ok=True)
    prep.save_png(img[::-1], os.path.join(out_dir, "depth.png"))     # Blender images are bottom-up
    np.save(os.path.join(out_dir, "depth.npy"), depth)
    json.dump({"pos": pos.tolist(), "target": target.tolist(), "fov": fov, "res": RES}, open(os.path.join(out_dir, "camera.json"), "w"))
    print("DEPTH written, near %.3f m, %d%% of the frame is body" % (near, 100 * hit.mean()))


def load_image(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)[::-1]                     # top-down, like the depth map


def sample(img, u, v):
    """Bilinear sample of img (H, W, C) at pixel coordinates u (x), v (y)."""
    h, w = img.shape[:2]
    u = np.clip(u, 0, w - 1.001)
    v = np.clip(v, 0, h - 1.001)
    x0, y0 = np.floor(u).astype(int), np.floor(v).astype(int)
    fx, fy = (u - x0)[..., None], (v - y0)[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
    b = img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def blur(img, r):
    """A cheap wide blur: box filters along each axis, three passes (close to a gaussian)."""
    out = img.copy()
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(out, [(r + 1, r) if a == axis else (0, 0) for a in range(out.ndim)], mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def delight(img):
    """Take most of the photo's broad light and shade out (the game lights the face itself), keeping
    the small detail: divide by a wide blur of its brightness."""
    lum = img.mean(axis=-1)
    broad = blur(lum, max(4, img.shape[0] // 40))
    ref = np.median(broad[lum > np.percentile(lum, 40)])
    return np.clip(img * (ref / np.maximum(broad, 1e-3))[..., None] ** 0.75, 0.0, 1.0)


def do_project(prepared, out_dir, base_png, out_png, size, face_file="face.png"):
    arm, body, eyes = setup(prepared)
    cam = json.load(open(os.path.join(out_dir, "camera.json")))
    pos, target, fov = np.array(cam["pos"]), np.array(cam["target"]), cam["fov"]
    fwd, right, up = basis(pos, target)
    half = math.tan(fov * 0.5)
    depth = np.load(os.path.join(out_dir, "depth.npy"))
    face = load_image(os.path.join(out_dir, face_file))[..., :3]
    face = np.where(face <= 0.04045, face / 12.92, ((face + 0.055) / 1.055) ** 2.4)    # sRGB -> linear
    face = delight(face)
    res = face.shape[0]
    if depth.shape[0] != res:                              # the generator may return another size
        idx = (np.arange(res) * depth.shape[0] / res).astype(int)
        depth = depth[idx][:, idx]
    # where every texel is, and which way it faces
    prep.bake_setup(size)
    sc = bpy.context.scene
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 0
    prep.select_only([body], body)
    lo, hi = prep.world_bbox(body)
    rng = hi - lo

    def posmap(nodes, links):
        g = nodes.new("ShaderNodeNewGeometry")
        sub = nodes.new("ShaderNodeVectorMath")
        sub.operation = "SUBTRACT"
        sub.inputs[1].default_value = tuple(lo)
        div = nodes.new("ShaderNodeVectorMath")
        div.operation = "DIVIDE"
        div.inputs[1].default_value = tuple(rng)
        links.new(g.outputs["Position"], sub.inputs[0])
        links.new(sub.outputs[0], div.inputs[0])
        return div.outputs[0]

    def nrmmap(nodes, links):
        g = nodes.new("ShaderNodeNewGeometry")
        m = nodes.new("ShaderNodeVectorMath")
        m.operation = "MULTIPLY_ADD"
        m.inputs[1].default_value = (0.5, 0.5, 0.5)
        m.inputs[2].default_value = (0.5, 0.5, 0.5)
        links.new(g.outputs["Normal"], m.inputs[0])
        return m.outputs[0]
    prep.emission_material(body, "posmap", posmap)
    img_p, _ = prep.bake_image(body, "pos", size, float_buf=True)
    bpy.ops.object.bake(type="EMIT")
    pm = prep.pixels(img_p)
    valid = pm[..., :3].max(axis=-1) > 1e-6
    p = pm[..., :3] * np.array(rng) + np.array(lo)
    prep.emission_material(body, "nrm", nrmmap)
    img_n, _ = prep.bake_image(body, "nrm", size, float_buf=True)
    bpy.ops.object.bake(type="EMIT")
    n = prep.pixels(img_n)[..., :3] * 2.0 - 1.0
    # into the camera
    rel = p - pos
    z = rel @ fwd
    sx = (rel @ right) / np.maximum(z, 1e-4) / half
    sy = (rel @ up) / np.maximum(z, 1e-4) / half
    u = (sx + 1.0) * 0.5 * res - 0.5
    v = (1.0 - sy) * 0.5 * res - 0.5
    inside = valid & (np.abs(sx) < 0.98) & (np.abs(sy) < 0.98) & (z > 0)
    seen = sample(depth[..., None], u, v)[..., 0]
    visible = inside & (z <= seen + 0.004)
    view = -(rel / np.linalg.norm(rel, axis=-1, keepdims=True))
    facing = np.sum(n * view, axis=-1)
    w = np.where(visible, prep.smooth(facing, 0.3, 0.7), 0.0)
    col = sample(face, u, v)
    # as variation around the face's own average skin (the cheeks and forehead)
    skin = visible & (facing > 0.6)
    lum = col[skin].mean(axis=-1)
    keep = (lum > np.percentile(lum, 25)) & (lum < np.percentile(lum, 85))
    mean = np.median(col[skin][keep], axis=0)
    gen = np.clip(col / mean * 0.5, 0.0, 1.0)
    base = load_image(base_png)[::-1]                    # back to Blender's bottom-up order, like the bakes
    if base.shape[0] != size:
        idx = (np.arange(size) * base.shape[0] / size).astype(int)
        base = base[idx][:, idx]
    out = base.copy()
    out[..., :3] = base[..., :3] * (1.0 - w[..., None]) + gen * w[..., None]
    out[..., 3] = np.maximum(base[..., 3], w)            # the generated eyes and lips fit the shape: keep them
    # carry the blend over the islands' edges, or the old skin in the gaps draws a seam
    m = valid.copy()
    for _ in range(40):
        acc = np.zeros_like(out[..., :3])
        cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1)
            acc += np.roll(np.roll(out[..., :3], dy, 0), dx, 1) * sm[..., None]
            cnt += sm
        grow = (~m) & (cnt > 0)
        out[grow, :3] = acc[grow] / cnt[grow][:, None]
        m = m | grow
    prep.save_png(out, out_png)
    print("PROJECTED onto %d texels, face mean" % int((w > 0.5).sum()), [round(float(x), 3) for x in mean])


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    if args[0] == "depth":
        do_depth(args[1], args[2])
    else:
        do_project(args[1], args[2], args[3], args[4], int(args[5]) if len(args) > 5 else 2048, args[6] if len(args) > 6 else "face.png")


if __name__ == "__main__":
    main()
