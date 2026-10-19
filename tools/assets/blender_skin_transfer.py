"""Bake a MakeHuman skin texture (CC0) onto our body's own layout, inside Blender (headless):

    blender -b --python tools/assets/blender_skin_transfer.py -- <prepared body.blend> <makehuman base.obj> \
        <makehuman diffuse.png> <out.png> [size]

MakeHuman's base mesh is warped onto our body - a thin-plate spline through matching landmarks
(eye centres, nose tip, lips, chin, ears, crown, back of the head, and the joints of the arms,
legs and neck against our skeleton's bones), then snapped onto our surface - and its texture is
baked across by ray from our body. Written as variation around the average skin colour (RGB 0.5 =
average, so the game can still choose the skin colour); alpha is where the bake landed.
"""
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

JOINTS = [  # (makehuman joint marker, mixamo bone) - the left side; the right is mirrored by name
    ("joint-l-clavicle", "LeftShoulder"), ("joint-l-shoulder", "LeftArm"), ("joint-l-elbow", "LeftForeArm"),
    ("joint-l-hand", "LeftHand"), ("joint-l-upper-leg", "LeftUpLeg"), ("joint-l-knee", "LeftLeg"),
    ("joint-l-ankle", "LeftFoot"), ("joint-l-toe-3-1", "LeftToeBase"),
] + [("joint-l-finger-%d-%d" % (f, k), "LeftHand%s%d" % (name, k))
     for f, name in ((1, "Thumb"), (2, "Index"), (3, "Middle"), (4, "Ring"), (5, "Pinky")) for k in (1, 2, 3, 4)]


def face_marks(pts, eye_l, eye_r):
    """Landmarks found the same way on both meshes: nose tip, upper and lower lip, chin, crown,
    back of the head, the ears."""
    eye = (eye_l + eye_r) * 0.5
    s = np.linalg.norm(eye_l - eye_r) / 0.063
    mid = pts[np.abs(pts[:, 0]) < 0.004 * s]
    band = lambda lo, hi: mid[(mid[:, 2] > eye[2] + lo * s) & (mid[:, 2] < eye[2] + hi * s)]
    nose = band(-0.07, -0.01)
    nose = nose[np.argmin(nose[:, 1])]
    nz = (nose[2] - eye[2]) / s
    up = band(nz - 0.03, nz - 0.012)
    up = up[np.argmin(up[:, 1])]
    lo = band(nz - 0.052, nz - 0.033)
    lo = lo[np.argmin(lo[:, 1])]
    chin_b = band(nz - 0.11, nz - 0.055)
    chin_b = chin_b[chin_b[:, 1] < eye[1] + 0.03 * s]
    chin = chin_b[np.argmin(chin_b[:, 2])]
    head = pts[pts[:, 2] > eye[2] - 0.12 * s]
    crown = head[np.argmax(head[:, 2])]
    back_b = band(-0.01, 0.02)
    back = back_b[np.argmax(back_b[:, 1])]
    ring = head[(head[:, 2] > eye[2] - 0.04 * s) & (head[:, 2] < eye[2] + 0.01 * s)]
    ear_l = ring[np.argmax(ring[:, 0])]
    ear_r = ring[np.argmin(ring[:, 0])]
    return [eye_l, eye_r, nose, up, lo, chin, crown, back, ear_l, ear_r]


def tps(src, dst, pts):
    """Thin-plate spline (3D, phi(r) = r) taking src landmarks to dst, applied to pts."""
    n = len(src)
    K = np.linalg.norm(src[:, None, :] - src[None, :, :], axis=2)
    P = np.hstack([np.ones((n, 1)), src])
    A = np.zeros((n + 4, n + 4))
    A[:n, :n] = K + np.eye(n) * 1e-6
    A[:n, n:] = P
    A[n:, :n] = P.T
    b = np.zeros((n + 4, 3))
    b[:n] = dst
    sol = np.linalg.solve(A, b)
    w, a = sol[:n], sol[n:]
    out = np.empty_like(pts)
    for i in range(0, len(pts), 4096):
        chunk = pts[i:i + 4096]
        Kp = np.linalg.norm(chunk[:, None, :] - src[None, :, :], axis=2)
        out[i:i + 4096] = Kp @ w + np.hstack([np.ones((len(chunk), 1)), chunk]) @ a
    return out


def centre(o):
    vs = np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])
    return vs.mean(axis=0)


def import_makehuman(path):
    """Import a MakeHuman-space OBJ split by groups: {group name: object}, in metres, unscaled origin."""
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, use_split_groups=True)
    new = {}
    for o in bpy.data.objects:
        if o not in before:                     # "body" clashes with ours and comes in as "body.001"
            base = o.name.rsplit(".", 1)[0] if o.name.rsplit(".", 1)[-1].isdigit() else o.name
            new.setdefault(base, o)
    for o in new.values():                      # MakeHuman works in decimetres
        o.scale = (0.1, 0.1, 0.1)
    bpy.context.view_layer.update()
    return new


def landmarks_mh_to_ours(arm, body, eyes, new):
    """Matching landmark sets: (MakeHuman base mesh points, our body's points)."""
    mh = new["body"]
    ours = np.array([tuple(body.matrix_world @ v.co) for v in body.data.vertices])
    theirs = np.array([tuple(mh.matrix_world @ v.co) for v in mh.data.vertices])
    ept = np.array([tuple(eyes.matrix_world @ v.co) for v in eyes.data.vertices])
    o_el, o_er = ept[ept[:, 0] > 0].mean(axis=0), ept[ept[:, 0] < 0].mean(axis=0)
    t_el, t_er = centre(new["helper-l-eye"]), centre(new["helper-r-eye"])
    src = face_marks(theirs, t_el, t_er)
    dst = face_marks(ours, o_el, o_er)
    bones = arm.data.bones
    for jl, bl in JOINTS:
        for side in ("l", "r"):
            j = jl.replace("-l-", "-%s-" % side)
            b = "mixamorig:" + (bl if side == "l" else bl.replace("Left", "Right"))
            if j in new and b in bones:
                src.append(centre(new[j]))
                dst.append(np.array(tuple(arm.matrix_world @ bones[b].head_local)))
    for j, b in (("joint-neck", "Neck"), ("joint-head", "Head"), ("joint-pelvis", "Hips")):
        if j in new and "mixamorig:" + b in bones:
            src.append(centre(new[j]))
            dst.append(np.array(tuple(arm.matrix_world @ bones["mixamorig:" + b].head_local)))
    # the navel: on the belly's centre line, the point sunk deepest below the line through the
    # profile 2 cm above and below it (a dimple, not just where the belly curves away)
    def navel(pts, hips_z, height):
        mid = pts[(np.abs(pts[:, 0]) < 0.006) & (pts[:, 2] > hips_z) & (pts[:, 2] < hips_z + 0.3) & (pts[:, 1] < 0)]
        best, depth = mid[0], -1.0
        for p in mid:
            if p[2] < hips_z + 0.05 or p[2] > hips_z + 0.25:
                continue
            above = mid[np.abs(mid[:, 2] - (p[2] + 0.02)) < 0.006]
            below = mid[np.abs(mid[:, 2] - (p[2] - 0.02)) < 0.006]
            if len(above) == 0 or len(below) == 0:
                continue
            d = p[1] - 0.5 * (above[:, 1].min() + below[:, 1].min())
            if d > depth:
                best, depth = p, d
        return best
    if "joint-pelvis" in new:
        hz_t = centre(new["joint-pelvis"])[2]
        hz_o = (arm.matrix_world @ bones["mixamorig:Hips"].head_local).z
        src.append(navel(theirs, hz_t, theirs[:, 2].max()))
        dst.append(navel(ours, hz_o, ours[:, 2].max()))
    return np.array(src), np.array(dst), (o_el, o_er)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    prepared, base_obj, diffuse, out = args[:4]
    size = int(args[4]) if len(args) > 4 else 2048
    bpy.ops.wm.open_mainfile(filepath=prepared)
    arm = bpy.data.objects["Character"]
    arm.data.pose_position = "REST"
    body = bpy.data.objects["body"]
    eyes = bpy.data.objects["eyes"]
    new = import_makehuman(base_obj)
    mh = new["body"]
    lowest = min((mh.matrix_world @ v.co).z for v in mh.data.vertices)
    for o in new.values():                      # stand it on the ground
        o.location.z -= lowest
    bpy.context.view_layer.update()
    theirs = np.array([tuple(mh.matrix_world @ v.co) for v in mh.data.vertices])
    src, dst, (o_el, o_er) = landmarks_mh_to_ours(arm, body, eyes, new)
    mouth = (dst[3] + dst[4]) * 0.5                  # between the lips (face_marks order)
    print("LANDMARKS", len(src), "mean move %.3f m" % np.linalg.norm(dst - src, axis=1).mean())
    print("NAVEL theirs", np.round(src[-1], 3), "ours", np.round(dst[-1], 3), "pelvis", np.round(src[-2], 3), np.round(dst[-2], 3))
    warped = tps(src, dst, theirs)
    # snap onto our surface where close
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(body.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    inv = mh.matrix_world.inverted()
    snapped = 0
    for i, v in enumerate(mh.data.vertices):
        p = Vector(tuple(warped[i]))
        loc, nrm, _, dist = tree.find_nearest(p)
        if loc is not None and dist < 0.08:      # the whole body is wanted, so snap far too
            p = loc + nrm * 0.0005
            snapped += 1
        v.co = inv @ p
    print("SNAPPED %d of %d" % (snapped, len(mh.data.vertices)))
    for o in new.values():
        if o is not mh:
            bpy.data.objects.remove(o, do_unlink=True)

    # bake MakeHuman's texture across, as emission
    # MakeHuman's texture is black between its islands: bleed the islands outward first, or every
    # seam of its layout shows as a dark line on our body
    src_img = bpy.data.images.load(diffuse)
    w, h = src_img.size
    px0 = np.empty(w * h * 4, dtype=np.float32)
    src_img.pixels.foreach_get(px0)
    px0 = px0.reshape(h, w, 4)
    m = (px0[..., 3] > 0.5) & (px0[..., :3].max(axis=-1) > 0.03)
    for _ in range(24):
        acc = np.zeros_like(px0[..., :3])
        cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1)
            acc += np.roll(np.roll(px0[..., :3], dy, 0), dx, 1) * sm[..., None]
            cnt += sm
        grow = (~m) & (cnt > 0)
        px0[grow, :3] = acc[grow] / cnt[grow][:, None]
        m = m | grow
    px0[..., 3] = 1.0
    src_img.pixels.foreach_set(px0.ravel())

    def tex(nodes, links):
        t = nodes.new("ShaderNodeTexImage")
        t.image = src_img
        return t.outputs["Color"]
    prep.emission_material(mh, "mh_skin", tex)
    prep.ensure_material(body, "skin_bake")
    prep.bake_setup(size)
    sc = bpy.context.scene
    sc.render.bake.margin = 0
    img, _ = prep.bake_image(body, "mh_bake", size, float_buf=True)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.hide_render = ob not in (mh, body)
    prep.select_only([mh, body], body)
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.01
    sc.render.bake.max_ray_distance = 0.05
    bpy.ops.object.bake(type="EMIT")
    px = prep.pixels(img)
    landed = px[..., :3].max(axis=-1) > 1e-5          # a ray that missed leaves exact black (alpha is no guide)
    # where each texel sits on the body, to keep the photo out of the eye sockets (the eyes never
    # line up closely enough; the painted skin is better there)
    sc.render.bake.use_selected_to_active = False
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
    prep.emission_material(body, "posmap", posmap)
    img_p, _ = prep.bake_image(body, "pos", size, float_buf=True)
    bpy.ops.object.bake(type="EMIT")
    pos = prep.pixels(img_p)[..., :3] * np.array(rng) + np.array(lo)
    s_eye = np.linalg.norm(o_el - o_er) / 0.063
    keep_out = np.ones(landed.shape, np.float32)
    for e in (o_el, o_er):
        d = np.linalg.norm(pos - e, axis=-1)
        d = np.where(landed, d, 1.0)
        keep_out = np.minimum(keep_out, prep.smooth(d, 0.024 * s_eye, 0.034 * s_eye))
    # and out of the mouth (lips and teeth never line up either)
    dm = pos - mouth
    em = np.sqrt((dm[..., 0] / (0.032 * s_eye)) ** 2 + (dm[..., 2] / (0.016 * s_eye)) ** 2 + (np.maximum(dm[..., 1], 0) / (0.03 * s_eye)) ** 2)
    em = np.where(landed, em, 9.0)
    keep_out = np.minimum(keep_out, prep.smooth(em, 0.8, 1.35))
    rgb = px[..., :3]
    # the average skin: the median of what landed, ignoring very dark and very red texels
    lum = rgb.mean(axis=-1)
    good = landed & (lum > np.percentile(lum[landed], 20)) & (lum < np.percentile(lum[landed], 90))
    mean = np.median(rgb[good], axis=0)
    ratio = np.clip(rgb / mean * 0.5, 0.0, 1.0)
    outp = np.concatenate([ratio, landed[..., None].astype(np.float32)], axis=-1)
    keep_out_full = keep_out
    # bleed into the gaps so seams do not show, far enough for the small mipmaps, then neutral
    for _ in range(40):
        m = outp[..., 3] > 0.5
        acc = np.zeros_like(outp[..., :3])
        cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1)
            acc += np.roll(np.roll(outp[..., :3], dy, 0), dx, 1) * sm[..., None]
            cnt += sm
        grow = (~m) & (cnt > 0)
        outp[grow, :3] = acc[grow] / cnt[grow][:, None]
        outp[grow, 3] = 1.0                      # good data: the photo must run right to the island edge
    rest = outp[..., 3] < 0.5
    outp[rest, :3] = 0.5
    outp[..., 3] = keep_out_full
    prep.save_png(outp, out)
    print("MH SKIN mean", [round(float(x), 3) for x in mean], "landed", round(float(landed.mean()), 3))


if __name__ == "__main__":
    main()
