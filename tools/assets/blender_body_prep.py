"""Prepare a Mixamo-rigged base body for the game, inside Blender (headless):

    blender -b human_base_meshes_bundle.blend --python tools/assets/blender_body_prep.py -- \
        <rigged idle.fbx> <bundle body object> <out.blend> <texture dir> <prefix> [size]

From the rigged body (a Mixamo download WITH skin) and the same body's sculpted high-res version in
Blender Studio's Human Base Meshes bundle (CC0), this:

- separates the eyes (Mixamo merges them into the body) and paints them with vertex colours;
- repacks the bundle's UDIM layout into one 0..1 texture, giving the head and hands more room;
- tags every vertex with a body region (UV2.x = region id + 0.5) by its strongest bone, so the game
  can hide skin under clothes and a lost forearm;
- adds shape keys: heavy, slight (builds), gaunt, brow (faces);
- bakes, from the multires sculpt: a tangent normal map, ambient occlusion and cavity; and from the
  body's own surface a position map, from which it paints (numpy) a skin tone map and two masks:
    <prefix>_normal.png   tangent normal (OpenGL, +Y)
    <prefix>_detail.png   R tone (0.5 = the chosen skin colour), G ambient occlusion, B cavity
    <prefix>_mask_a.png   R redness, G lips, B brows, A eye shadow
    <prefix>_mask_b.png   R beard area, G scalp, B scar, A unused (1)
- saves the prepared armature + body + eyes (rest pose, idle action kept) as <out.blend>, which
  tools/assets/blender_character.py builds the final .glb from.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# bone name (without "mixamorig:") -> region id. Upper arms are split in two along the bone.
REGION_OF = {
    "Head": 0, "HeadTop_End": 0, "LeftEye": 0, "RightEye": 0, "Neck": 1,
    "Spine": 2, "Spine1": 2, "Spine2": 2, "LeftShoulder": 2, "RightShoulder": 2, "Hips": 3,
    "LeftArm": 4, "RightArm": 5, "LeftForeArm": 6, "RightForeArm": 7,
    "LeftUpLeg": 10, "RightUpLeg": 11, "LeftLeg": 12, "RightLeg": 13,
    "LeftFoot": 14, "LeftToeBase": 14, "LeftToe_End": 14, "RightFoot": 15, "RightToeBase": 15, "RightToe_End": 15,
}
ARM_LOW = {4: 16, 5: 17}          # the elbow half of each upper arm


def region_for(bone):
    b = bone.split(":")[-1]
    if b in REGION_OF:
        return REGION_OF[b]
    if b.startswith("LeftHand"):
        return 8
    if b.startswith("RightHand"):
        return 9
    return 2


def select_only(objs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def import_rigged(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    body = next(o for o in new if o.type == "MESH")
    return arm, body


def high_res(src):
    """The sculpted body at full multires level, unparented, transforms applied, at the origin."""
    if src.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(src)
    src.hide_set(False)
    src.hide_viewport = False
    src.hide_render = False
    select_only([src], src)
    for m in list(src.modifiers):
        if m.type == "MULTIRES":
            m.levels = m.total_levels
            m.render_levels = m.total_levels
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    src.location = (0.0, 0.0, 0.0)
    return src


def world_bbox(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def split_eyes(body):
    """Mixamo merged the two eyes into the body: split them off by loose part."""
    select_only([body], body)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(body.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    parts = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, part = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            part.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        parts.append(part)
    parts.sort(key=len, reverse=True)
    for el in list(bm.verts) + list(bm.edges) + list(bm.faces):
        el.select = False
    for part in parts[1:]:
        for v in part:
            v.select = True
    bm.select_flush(True)
    bmesh.update_edit_mesh(body.data)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    eyes = next(o for o in bpy.context.selected_objects if o is not body)
    eyes.name = "eyes"
    print("EYES parts", len(parts) - 1, "verts", len(eyes.data.vertices))
    return eyes


def paint_eyes(eyes, arm):
    """Vertex colours on each eye ball: sclera, iris, pupil by angle from the eye's forward axis."""
    me = eyes.data
    mw = eyes.matrix_world
    pts = [mw @ v.co for v in me.vertices]
    centres = {}
    for side in (1, -1):
        sel = [p for p in pts if p.x * side > 0]
        c = sum(sel, Vector()) / len(sel)
        centres[side] = c
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, p in enumerate(pts):
        c = centres[1 if p.x > 0 else -1]
        d = (p - c).normalized()
        cos_a = -d.y                              # the body faces -Y
        if cos_a > 0.93:
            rgb = (0.02, 0.015, 0.012)            # pupil
        elif cos_a > 0.80:
            t = (cos_a - 0.80) / 0.13
            rgb = (0.07 + 0.05 * t, 0.045 + 0.03 * t, 0.02)  # iris (linear), a dark hazel
        elif cos_a > 0.77:
            rgb = (0.03, 0.025, 0.02)             # limbal ring
        else:
            rgb = (0.52, 0.48, 0.45)              # sclera (linear)
        col.data[i].color = (*rgb, 1.0)
    return centres


def region_layer(body, arm):
    """UV2 = (region id + 0.5, 0) per loop, from each vertex's strongest bone."""
    me = body.data
    names = {g.index: g.name for g in body.vertex_groups}
    bones = {b.name: b for b in arm.data.bones}
    mw_arm = arm.matrix_world
    vreg = []
    for v in me.vertices:
        best, bw = None, -1.0
        for g in v.groups:
            if g.weight > bw:
                best, bw = names.get(g.group), g.weight
        r = region_for(best or "Spine")
        if r in ARM_LOW and best in bones:
            b = bones[best]
            h, t = mw_arm @ b.head_local, mw_arm @ b.tail_local
            p = body.matrix_world @ v.co
            axis = t - h
            s = (p - h).dot(axis) / max(axis.length_squared, 1e-9)
            if s > 0.5:
                r = ARM_LOW[r]
        vreg.append(r)
    uv2 = me.uv_layers.new(name="regions", do_init=False)
    me.uv_layers[0].active_render = True
    me.uv_layers.active = me.uv_layers[0]
    for loop in me.loops:
        uv2.data[loop.index].uv = (vreg[loop.vertex_index] + 0.5, 0.0)
    counts = {}
    for r in vreg:
        counts[r] = counts.get(r, 0) + 1
    print("REGIONS", sorted(counts.items()))
    return vreg


def repack_uvs(body):
    """All UDIM tiles into 0..1; the head x1.8 and the hands x1.3 before packing."""
    me = body.data
    me.uv_layers.active = me.uv_layers[0]
    uv = me.uv_layers[0].data
    mw = body.matrix_world
    height = max((mw @ v.co).z for v in me.vertices)
    tiles = {}
    for p in me.polygons:
        u = sum(uv[li].uv.x for li in p.loop_indices) / p.loop_total
        v = sum(uv[li].uv.y for li in p.loop_indices) / p.loop_total
        key = (math.floor(u), math.floor(v))
        tiles.setdefault(key, []).append(p)
    for key, polys in tiles.items():
        zs = sorted((mw @ p.center).z for p in polys)
        zmed = zs[len(zs) // 2]
        scale = 1.8 if zmed > 0.84 * height else 1.0
        if scale == 1.0:
            xs = sorted(abs((mw @ p.center).x) for p in polys)
            if xs[len(xs) // 2] > 0.55 * 0.5 * height and zmed < 0.6 * height:
                scale = 1.3                       # hands hang wide of the hips
        for p in polys:
            for li in p.loop_indices:
                x, y = uv[li].uv
                x, y = x - key[0], y - key[1]
                # scaled about the tile centre, the tiles kept apart (two of them mirror each other)
                uv[li].uv = (key[0] * 2.0 + 0.5 + (x - 0.5) * scale, key[1] * 2.0 + 0.5 + (y - 0.5) * scale)
    select_only([body], body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, scale=True, margin=0.004, merge_overlap=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = me.uv_layers[0].data
    u0 = math.floor(min(d.uv.x for d in uv) + 1e-4)
    v0 = math.floor(min(d.uv.y for d in uv) + 1e-4)
    for d in uv:
        d.uv = (d.uv.x - u0, d.uv.y - v0)
    me.uv_layers[0].active_render = True
    us = [d.uv.x for d in uv]
    vs = [d.uv.y for d in uv]
    print("UV packed", round(min(us), 3), round(max(us), 3), round(min(vs), 3), round(max(vs), 3))


def landmarks(body, eyes_centres):
    mw = body.matrix_world
    pts = np.array([tuple(mw @ v.co) for v in body.data.vertices])
    el, er = eyes_centres[1], eyes_centres[-1]
    eye = (el + er) * 0.5
    s = (el - er).length / 0.063
    near = pts[(np.abs(pts[:, 0]) < 0.006 * s) & (pts[:, 2] < eye.z - 0.01 * s) & (pts[:, 2] > eye.z - 0.07 * s)]
    nose = near[np.argmin(near[:, 1])]
    top = pts[:, 2].max()
    head = pts[pts[:, 2] > eye.z - 0.12 * s]
    lm = {
        "eye_l": np.array(el), "eye_r": np.array(er), "eye": np.array(eye), "s": s, "nose": nose, "top": top,
        "mouth_z": nose[2] - 0.034 * s, "chin_z": nose[2] - 0.085 * s,
        "head_c": np.array([0.0, head[:, 1].mean(), eye.z + 0.01 * s]),
        "height": top,
    }
    print("LANDMARKS eye", [round(x, 3) for x in eye], "ipd", round((el - er).length, 4), "nose", [round(x, 3) for x in nose], "top", round(top, 3))
    return lm


def gauss(d2, r):
    return np.exp(-d2 / (r * r))


def shape_keys(body, vreg, lm):
    me = body.data
    mw = body.matrix_world
    if me.shape_keys is None:
        body.shape_key_add(name="Basis", from_mix=False)
    n = len(me.vertices)
    co = np.array([tuple(mw @ v.co) for v in me.vertices])
    nr = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in me.vertices])
    reg = np.array(vreg)
    s, H = lm["s"], lm["height"]
    trunk = np.isin(reg, [2, 3])
    limbs_up = np.isin(reg, [4, 5, 10, 11, 16, 17])
    limbs_lo = np.isin(reg, [6, 7, 12, 13])
    neck = reg == 1
    headm = reg == 0
    front = np.clip(-nr[:, 1], 0.0, 1.0)
    belly = gauss((co[:, 2] - 0.57 * H) ** 2, 0.10 * H) * (0.35 + 0.65 * front)
    rel = co - lm["eye"]
    cheeks = sum(gauss((rel[:, 0] - sx * 0.042 * s) ** 2 + (rel[:, 2] + 0.035 * s) ** 2, 0.022 * s) for sx in (1, -1))
    jaw = gauss((rel[:, 2] + 0.075 * s) ** 2, 0.025 * s) * (np.abs(rel[:, 0]) > 0.02 * s)
    heavy = np.where(trunk, 0.008 + 0.026 * belly, 0.0) + np.where(limbs_up, 0.009, 0.0) + np.where(limbs_lo, 0.004, 0.0) \
        + np.where(neck, 0.007, 0.0) + np.where(headm, 0.005 * cheeks + 0.004 * jaw, 0.0)
    slight = -(np.where(trunk, 0.005 + 0.010 * belly, 0.0) + np.where(limbs_up, 0.005, 0.0) + np.where(limbs_lo, 0.002, 0.0)
               + np.where(neck, 0.003, 0.0))
    gaunt = -np.where(headm, 0.0055 * cheeks + 0.002 * gauss(rel[:, 2] ** 2 + (np.abs(rel[:, 0]) - 0.06 * s) ** 2, 0.02 * s), 0.0)
    brow = gauss((np.abs(rel[:, 0]) - 0.03 * s) ** 2 * 0.5 + (rel[:, 2] - 0.022 * s) ** 2, 0.016 * s) * front * headm
    inv = mw.inverted().to_3x3()
    for name, amount, along in (("heavy", heavy, None), ("slight", slight, None), ("gaunt", gaunt, None), ("brow", brow * 0.005, np.array([0.0, -1.0, 0.0]))):
        key = body.shape_key_add(name=name, from_mix=False)
        for i in range(n):
            d = (along if along is not None else nr[i]) * amount[i]
            if amount[i] != 0.0:
                key.data[i].co = me.vertices[i].co + inv @ Vector(d)
    print("SHAPEKEYS", [k.name for k in me.shape_keys.key_blocks])


def bake_setup(size):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.margin = 12
    sc.render.bake.use_clear = True


def bake_image(body, name, size, float_buf=False, colorspace="Non-Color"):
    img = bpy.data.images.new(name, size, size, alpha=True, float_buffer=float_buf)
    img.generated_color = (0.0, 0.0, 0.0, 0.0)
    img.colorspace_settings.name = colorspace
    mat = body.data.materials[0]
    nodes = mat.node_tree.nodes
    for nd in nodes:
        nd.select = False
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.select = True
    nodes.active = tex
    return img, tex


def ensure_material(o, name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    o.data.materials.clear()
    o.data.materials.append(mat)
    return mat


def emission_material(o, name, build):
    """A material whose surface emits build(nodes, links) - for baking a field off a surface."""
    mat = ensure_material(o, name)
    nt = mat.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    sock = build(nt.nodes, nt.links)
    nt.links.new(sock, em.inputs[0])
    return mat


def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def save_png(arr, path, colorspace="Non-Color"):
    """Save a float RGBA array as PNG. Alpha here is data, never transparency: it is kept at least
    1/255, because importers (Godot's "fix alpha border") rewrite the colour of fully clear texels."""
    arr = np.array(arr, dtype=np.float32)
    if arr.ndim == 3 and arr.shape[2] == 4:
        arr[..., 3] = np.maximum(arr[..., 3], 1.0 / 255.0)
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("SAVED", path)


def value_noise(p, freq, seed):
    """Smooth 3D value noise in -1..1 at points p (N,3)."""
    q = p * freq
    i0 = np.floor(q).astype(np.int64)
    f = q - i0
    f = f * f * (3 - 2 * f)
    out = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                h = (i0[:, 0] + dx) * 73856093 ^ (i0[:, 1] + dy) * 19349663 ^ (i0[:, 2] + dz) * 83492791 ^ seed * 2654435761
                h = (h ^ (h >> 13)) * 1274126177
                r = ((h ^ (h >> 16)) & 0xFFFF) / 32767.5 - 1.0
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += r * w
    return out


def fbm(p, freq, seed, octaves=4):
    out, amp, tot = np.zeros(len(p)), 1.0, 0.0
    for o in range(octaves):
        out += amp * value_noise(p, freq * (2 ** o), seed + o)
        tot += amp
        amp *= 0.5
    return out / tot


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def paint(pos, reg, valid, ao, cavity, lm):
    """Tone, redness, lips, brows, eye shadow, beard area, scalp and scar from the position map."""
    p = pos[valid]
    r = reg[valid]
    s = lm["s"]
    rel = p - lm["eye"]
    ax = np.abs(rel[:, 0])
    head = r == 0
    hc = p - lm["head_c"]
    radial = np.sqrt(hc[:, 0] ** 2 + hc[:, 1] ** 2) + 1e-6
    frontness = np.clip(-hc[:, 1] / radial, -1.0, 1.0)      # 1 straight ahead, -1 the back of the head
    frontal = (rel[:, 1] < 0.03 * s)

    mott = fbm(p, 18.0, 3) * 0.06 + fbm(p, 95.0, 9, 3) * 0.035 + fbm(p, 420.0, 21, 2) * 0.02
    tone = 0.5 + mott
    # darker towards the extremities' undersides and creases (AO carries most of it)
    tone *= 0.82 + 0.18 * ao[valid]

    red = np.zeros(len(p))
    red += head * (0.55 * sum(gauss((rel[:, 0] - sx * 0.042 * s) ** 2 + (rel[:, 2] + 0.03 * s) ** 2 + 0.3 * (rel[:, 1] + 0.06 * s) ** 2, 0.024 * s) for sx in (1, -1)))
    red += head * 0.7 * gauss(np.sum((p - lm["nose"]) ** 2, axis=1), 0.016 * s)
    ear = head & (ax > 0.066 * s) & (rel[:, 2] > -0.05 * s) & (rel[:, 2] < 0.028 * s) & (rel[:, 1] > 0.005 * s) & (rel[:, 1] < 0.065 * s)
    red += ear * 0.5
    hands = np.isin(r, [8, 9])
    red += hands * (0.25 + 0.25 * (fbm(p, 60.0, 5, 2) > 0.1))
    feet = np.isin(r, [14, 15])
    red += feet * 0.3
    knees = np.isin(r, [12, 13]) & (p[:, 2] > 0.26 * lm["height"]) & (p[:, 2] < 0.31 * lm["height"])
    red += knees * 0.3
    elbows = np.isin(r, [6, 7, 16, 17])
    red += elbows * 0.12
    red *= 0.75 + 0.25 * fbm(p, 40.0, 7, 2)

    mouth = np.array([0.0, lm["nose"][1], lm["mouth_z"]])
    dm = p - mouth
    lips = head & frontal & (((dm[:, 0] / (0.026 * s)) ** 2 + (dm[:, 2] / (0.011 * s)) ** 2) < 1.0)
    lips_soft = head * frontal * smooth(1.0 - ((dm[:, 0] / (0.027 * s)) ** 2 + (dm[:, 2] / (0.0125 * s)) ** 2), 0.0, 0.35)

    brow = np.zeros(len(p))
    for sx in (1, -1):
        bx = (rel[:, 0] * sx) / s                   # 0 at the nose bridge, + outward
        arch = 0.019 + 0.007 * np.cos(np.clip((bx - 0.032) / 0.03, -1.5, 1.5)) - 0.004 * np.clip((bx - 0.045) / 0.02, 0, 1)
        dz = rel[:, 2] / s - arch
        thick = 0.0042 - 0.0015 * np.clip((bx - 0.03) / 0.03, 0, 1)
        on = (bx > 0.008) & (bx < 0.062)
        hair = 0.75 + 0.25 * fbm(p * np.array([1.0, 1.0, 4.0]), 380.0, 11, 2)
        brow = np.maximum(brow, head * frontal * on * smooth(1.0 - np.abs(dz) / thick, 0.0, 0.6) * hair)

    shadow = np.zeros(len(p))
    for key in ("eye_l", "eye_r"):
        e = lm[key]
        de = p - e
        shadow += head * gauss(de[:, 0] ** 2 + (de[:, 2] * 1.4) ** 2 + 0.2 * de[:, 1] ** 2, 0.022 * s)
    shadow = np.clip(shadow, 0, 1)

    # beard area: the lower face and jaw, under the cheekbones, down onto the throat
    below_nose = smooth(-(p[:, 2] - (lm["nose"][2] - 0.008 * s)), 0.0, 0.008 * s)
    cheek_line = smooth(-(rel[:, 2] + 0.022 * s + 0.25 * np.maximum(0.0, 0.05 * s - ax)), 0.0, 0.012 * s)
    side_burn = smooth(-(np.abs(rel[:, 1] - 0.04 * s) - 0.012 * s), 0.0, 0.006 * s) * smooth(-(rel[:, 2] - 0.01 * s), 0.0, 0.01 * s) * (ax > 0.055 * s)
    neck_cut = smooth(p[:, 2] - (lm["chin_z"] - 0.03 * s), 0.0, 0.02 * s)
    beard = np.where(np.isin(r, [0, 1]), np.clip(np.maximum(below_nose * cheek_line, side_burn), 0, 1) * neck_cut, 0.0)
    beard *= (frontness > -0.25)
    beard *= 1.0 - lips_soft * 0.85
    beard *= 0.7 + 0.3 * fbm(p, 200.0, 13, 2)

    # scalp: above a hairline that is high at the brow and low at the nape
    f = frontness
    hairline = np.interp(f, [-1.0, -0.2, 0.35, 0.75, 1.0], [-0.095, -0.03, 0.035, 0.05, 0.056]) * s
    scalp = head * smooth(rel[:, 2] - hairline, -0.004 * s, 0.01 * s)
    scalp *= 1.0 - (ear * 1.0)

    # a scar: a slant across the left brow and cheek
    a = np.array([0.050, 0.040]) * s
    b = np.array([0.020, -0.050]) * s
    q = np.stack([rel[:, 0], rel[:, 2]], axis=1)
    ab = b - a
    t = np.clip(((q - a) @ ab) / (ab @ ab), 0, 1)
    d = np.linalg.norm(q - (a + t[:, None] * ab), axis=1)
    w = 0.0022 * s * (1.0 - 0.6 * np.abs(t - 0.5) * 2)
    scar = head * frontal * smooth(1.0 - d / np.maximum(w, 1e-5), 0.0, 0.5) * (rel[:, 0] > 0)

    return tone, np.clip(red, 0, 1), lips_soft, brow, shadow, beard, scalp, scar


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    rig_path, src_name, out_blend, tex_dir, prefix = args[:5]
    size = int(args[5]) if len(args) > 5 else 2048
    os.makedirs(tex_dir, exist_ok=True)
    src = bpy.data.objects[src_name]
    for o in list(bpy.data.objects):
        if o is not src:
            bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    arm, body = import_rigged(rig_path)
    arm.data.pose_position = "REST"
    arm.name = "Character"
    body.name = "body"
    hi = high_res(src)
    hi.name = "high"
    bpy.context.view_layer.update()
    lo_b, hi_b = world_bbox(body), world_bbox(hi)
    off = ((lo_b[0] + lo_b[1]) - (hi_b[0] + hi_b[1])) * 0.5
    print("BBOX rigged", [round(x, 3) for x in lo_b[0]], [round(x, 3) for x in lo_b[1]], "high", [round(x, 3) for x in hi_b[0]], [round(x, 3) for x in hi_b[1]], "offset", [round(x, 4) for x in off])
    if off.length > 0.002:
        hi.location = off

    eyes = split_eyes(body)
    centres = paint_eyes(eyes, arm)
    vreg = region_layer(body, arm)
    repack_uvs(body)
    lm = landmarks(body, centres)
    shape_keys(body, vreg, lm)

    bake_setup(size)
    sc = bpy.context.scene
    # 1. tangent normals from the sculpt
    ensure_material(body, "skin")
    ensure_material(hi, "high")
    img_n, _ = bake_image(body, prefix + "_normal", size)
    img_n.generated_color = (0.5, 0.5, 1.0, 1.0)      # a ray that misses leaves the surface flat, not black
    select_only([hi, body], body)
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.01
    sc.render.bake.max_ray_distance = 0.03
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    nrm = pixels(img_n)
    # 2. ambient occlusion, from the sculpt
    img_ao, _ = bake_image(body, prefix + "_ao", size)
    sc.cycles.samples = 48
    bpy.ops.object.bake(type="AO")
    ao = pixels(img_ao)[..., 0]
    # 3. cavity: the sculpt's pointiness
    def cav(nodes, links):
        g = nodes.new("ShaderNodeNewGeometry")
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.44
        mr.inputs["From Max"].default_value = 0.56
        links.new(g.outputs["Pointiness"], mr.inputs["Value"])
        return mr.outputs["Result"]
    emission_material(hi, "high_cavity", cav)
    img_c, _ = bake_image(body, prefix + "_cavity", size)
    sc.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT")
    cavity = pixels(img_c)[..., 0]
    # 4. position + region maps off the low body itself
    sc.render.bake.use_selected_to_active = False
    select_only([body], body)
    lo, hi_c = world_bbox(body)
    rng = hi_c - lo

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
    emission_material(body, "posmap", posmap)
    img_p, _ = bake_image(body, prefix + "_pos", size, float_buf=True)
    sc.render.bake.margin = 0
    bpy.ops.object.bake(type="EMIT")
    pm = pixels(img_p)
    pos = pm[..., :3] * np.array(rng) + np.array(lo)
    valid = pm[..., :3].max(axis=-1) > 1e-6        # unbaked texels stay exactly zero

    def regmap(nodes, links):
        a = nodes.new("ShaderNodeUVMap")
        a.uv_map = "regions"
        sep = nodes.new("ShaderNodeSeparateXYZ")
        mul = nodes.new("ShaderNodeMath")
        mul.operation = "DIVIDE"
        mul.inputs[1].default_value = 32.0
        links.new(a.outputs[0], sep.inputs[0])
        links.new(sep.outputs[0], mul.inputs[0])
        comb = nodes.new("ShaderNodeCombineXYZ")
        links.new(mul.outputs[0], comb.inputs[0])
        links.new(mul.outputs[0], comb.inputs[1])
        links.new(mul.outputs[0], comb.inputs[2])
        return comb.outputs[0]
    emission_material(body, "regmap", regmap)
    img_r, _ = bake_image(body, prefix + "_reg", size, float_buf=True)
    sc.render.bake.margin = 0
    bpy.ops.object.bake(type="EMIT")
    reg = np.floor(pixels(img_r)[..., 0] * 32.0).astype(np.int32)

    tone, red, lips, brow, shadow, beard, scalp, scar = paint(pos, reg, valid, ao, cavity, lm)

    def full(vals, fill):
        out = np.full(valid.shape, fill, dtype=np.float32)
        out[valid] = vals
        return out
    # dilate painted values into the bake margin by repeated neighbour fill
    def dilate(img, mask, steps=10):
        img = img.copy()
        m = mask.copy()
        for _ in range(steps):
            grow = np.zeros_like(m)
            acc = np.zeros_like(img)
            cnt = np.zeros(m.shape, dtype=np.float32)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sm = np.roll(np.roll(m, dy, 0), dx, 1)
                si = np.roll(np.roll(img, dy, 0), dx, 1)
                acc += si * sm[..., None] if img.ndim == 3 else si * sm
                cnt += sm
            new = (~m) & (cnt > 0)
            if img.ndim == 3:
                img[new] = acc[new] / cnt[new][:, None]
            else:
                img[new] = acc[new] / cnt[new]
            m = m | new
        return img
    detail = np.stack([full(tone, 0.5), ao, cavity, np.ones(valid.shape, np.float32)], axis=-1)
    detail[..., :3] = dilate(detail[..., :3], valid)
    mask_a = np.stack([full(red, 0), full(lips, 0), full(brow, 0), full(shadow, 0)], axis=-1)
    mask_a = dilate(mask_a, valid)
    mask_b = np.stack([full(beard, 0), full(scalp, 0), full(scar, 0), np.ones(valid.shape, np.float32)], axis=-1)
    mask_b[..., :3] = dilate(mask_b[..., :3], valid)
    save_png(nrm, os.path.join(tex_dir, prefix + "_normal.png"))
    save_png(detail, os.path.join(tex_dir, prefix + "_detail.png"))
    save_png(mask_a, os.path.join(tex_dir, prefix + "_mask_a.png"))
    save_png(mask_b, os.path.join(tex_dir, prefix + "_mask_b.png"))

    # tidy up: drop the sculpt and the bake materials, keep body + eyes + armature
    bpy.data.objects.remove(hi, do_unlink=True)
    ensure_material(body, "skin")
    ensure_material(eyes, "eyes")
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    print("PREP done", out_blend, "valid texels", int(valid.sum()))


if __name__ == "__main__":
    main()
