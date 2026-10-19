"""Add anatomy (genitals) to a prepared body, inside Blender (headless):

    blender -b --python tools/assets/blender_anatomy.py -- <prepared body.blend> <makehuman base.obj> \
        <makehuman topology with anatomy .obj> <makehuman skin painted for it .png> <out texture.png>

Our base body (Blender Studio's) is smooth between the legs. MakeHuman community topologies (CC0)
model the anatomy on MakeHuman's base-mesh space: one is warped onto our body by the same landmark
fit as tools/assets/blender_skin_transfer.py, the groin is cut out of it, the parts that lie on our
skin are snapped onto it, and the piece is saved into the prepared .blend as "anatomy" - with its
own small texture cropped from a MakeHuman skin painted for it (as variation around the average
skin, like the photo skins) and a vertex-colour alpha that fades it out towards its edge, so it
melts into the body. tools/assets/blender_character.py skins it to the hips.
"""
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_body_prep as prep  # noqa: E402
import blender_skin_transfer as st  # noqa: E402


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    prepared, base_obj, topo_obj, skin_png, out_png = args[:5]
    bpy.ops.wm.open_mainfile(filepath=prepared)
    arm = bpy.data.objects["Character"]
    arm.data.pose_position = "REST"
    body = bpy.data.objects["body"]
    eyes = bpy.data.objects["eyes"]
    for o in [o for o in bpy.data.objects if o.name.startswith("anatomy")]:
        bpy.data.objects.remove(o, do_unlink=True)
    new = st.import_makehuman(base_obj)
    mh = new["body"]
    lowest = min((mh.matrix_world @ v.co).z for v in mh.data.vertices)
    topo_parts = st.import_makehuman(topo_obj)
    topo = max(topo_parts.values(), key=lambda o: len(o.data.vertices))
    for o in new.values():
        o.location.z -= lowest
    # MakeHuman files are decimetres about the hips; MPFB (MakeHuman for Blender) saves metres
    # standing on the ground - the same space the base mesh is now in
    tz = [(topo.matrix_world @ v.co).z for v in topo.data.vertices]
    metric = max(tz) - min(tz) < 0.5                  # scaled by 0.1 on import, so a 1.7 m body reads 0.17
    for o in topo_parts.values():
        if metric:
            o.scale = (1.0, 1.0, 1.0)
        else:
            o.location.z -= lowest
    bpy.context.view_layer.update()
    print("TOPOLOGY", topo.name, "metres" if metric else "decimetres")
    src, dst, _ = st.landmarks_mh_to_ours(arm, body, eyes, new)
    pts = np.array([tuple(topo.matrix_world @ v.co) for v in topo.data.vertices])
    warped = st.tps(src, dst, pts)

    # the groin of our body: between the hip joints, from below the navel to under the crotch
    bones = arm.data.bones
    hl = np.array(tuple(arm.matrix_world @ bones["mixamorig:LeftUpLeg"].head_local))
    hr = np.array(tuple(arm.matrix_world @ bones["mixamorig:RightUpLeg"].head_local))
    hip = (hl + hr) * 0.5
    half = abs(hl[0] - hr[0]) * 0.5
    ours = np.array([tuple(body.matrix_world @ v.co) for v in body.data.vertices])
    crotch_z = ours[(np.abs(ours[:, 0]) < 0.01) & (np.abs(ours[:, 2] - hip[2]) < 0.15)][:, 2].min()
    keep = (np.abs(warped[:, 0]) < half * 0.95) & (warped[:, 2] > crotch_z - 0.05) & (warped[:, 2] < hip[2] + 0.025) \
        & (warped[:, 1] < hip[1] + 0.02)
    me = topo.data
    inv = topo.matrix_world.inverted()
    for i, v in enumerate(me.vertices):
        v.co = inv @ Vector(tuple(warped[i]))
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # snap what lies on the skin onto ours (a hair outside it), leave what stands off it
    bb = bmesh.new()
    bb.from_mesh(body.data)
    bb.transform(body.matrix_world)
    tree = BVHTree.FromBMesh(bb)
    bb.free()
    mw = topo.matrix_world
    for v in bm.verts:
        p = mw @ v.co
        loc, nrm, _, dist = tree.find_nearest(p)
        if loc is not None and dist < 0.006:
            v.co = inv @ (loc + nrm * 0.0012)
    # fade towards the edge: alpha = geodesic distance from the boundary / 3 cm
    bm.verts.ensure_lookup_table()
    dist = {v.index: 0.0 for v in bm.verts if v.is_boundary}
    front = list(dist)
    while front:
        nxt = []
        for i in front:
            v = bm.verts[i]
            for e in v.link_edges:
                u = e.other_vert(v)
                d = dist[i] + ((mw @ u.co) - (mw @ v.co)).length
                if d < 0.03 and d < dist.get(u.index, 9.0):
                    dist[u.index] = d
                    nxt.append(u.index)
        front = nxt
    bm.to_mesh(me)
    bm.free()
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for v in me.vertices:
        a = min(1.0, dist.get(v.index, 0.03) / 0.03)
        col.data[v.index].color = (1.0, 1.0, 1.0, a * a * (3 - 2 * a))
    # crop the skin texture to the piece's UVs and remap them
    uv = me.uv_layers[0].data
    us = np.array([d.uv.x for d in uv])
    vs = np.array([d.uv.y for d in uv])
    u0, u1, v0, v1 = us.min(), us.max(), vs.min(), vs.max()
    img = bpy.data.images.load(skin_png)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    x0, x1 = int(u0 * w) - 8, int(u1 * w) + 8
    y0, y1 = int(v0 * h) - 8, int(v1 * h) + 8
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(w, x1), min(h, y1)
    crop = px[y0:y1, x0:x1].copy()
    for d in uv:
        d.uv = ((d.uv.x * w - x0) / (x1 - x0), (d.uv.y * h - y0) / (y1 - y0))
    # sRGB -> linear, then as variation around the average skin of the crop
    lin = np.where(crop[..., :3] <= 0.04045, crop[..., :3] / 12.92, ((crop[..., :3] + 0.055) / 1.055) ** 2.4)
    lum = lin.mean(axis=-1)
    good = (lum > np.percentile(lum, 30)) & (lum < np.percentile(lum, 85))
    mean = np.median(lin[good], axis=0)
    ratio = np.clip(lin / mean * 0.5, 0, 1)
    side = max(ratio.shape[0], ratio.shape[1])
    outp = np.ones((ratio.shape[0], ratio.shape[1], 4), np.float32)
    outp[..., :3] = ratio
    prep.save_png(outp, out_png)
    topo.name = "anatomy"
    topo.data.name = "anatomy"
    for o in list(new.values()) + [o for o in topo_parts.values() if o is not topo]:
        bpy.data.objects.remove(o, do_unlink=True)
    topo.data.materials.clear()
    topo.data.materials.append(bpy.data.materials.new("anatomy"))
    bpy.ops.wm.save_as_mainfile(filepath=prepared)
    print("ANATOMY verts", len(me.vertices), "faces", len(me.polygons), "crop", (x1 - x0, y1 - y0), "mean", [round(float(x), 3) for x in mean])


if __name__ == "__main__":
    main()
