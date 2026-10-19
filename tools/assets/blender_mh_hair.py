"""Fit MakeHuman's hair meshes (CC0, system assets) onto a prepared body, inside Blender (headless):

    blender -b --python tools/assets/blender_mh_hair.py -- <prepared body.blend> <makehuman base.obj> \
        <makehuman hair dir> <texture out dir> <style>=<makehuman hair id> [...]

MakeHuman hair is fitted to MakeHuman's base mesh by its .mhclo file (per hair vertex: three base
vertices, weights and an offset). That base mesh is warped onto our body the same way
tools/assets/blender_skin_transfer.py does it (thin-plate spline through matching landmarks, then
snapped onto our surface), and every hair vertex is rebuilt from the warped base the way MakeHuman
itself fits it. Saved into the prepared .blend as "mhhair_<style>" objects (UVs
kept); each style's texture is written as <texture out dir>/<style>.png (1024, alpha kept).
tools/assets/blender_character.py skins them.
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


def warped_base(arm, body, eyes, base_obj):
    """Every vertex of MakeHuman's base mesh (in its file order, helpers included) warped onto our
    body: the landmark spline, then the body's own vertices (the first 13380) snapped onto our skin."""
    new = st.import_makehuman(base_obj)
    mh = new["body"]
    lowest = min((mh.matrix_world @ v.co).z for v in mh.data.vertices)
    for o in new.values():
        o.location.z -= lowest
    bpy.context.view_layer.update()
    src, dst, _ = st.landmarks_mh_to_ours(arm, body, eyes, new)
    for o in list(new.values()):
        bpy.data.objects.remove(o, do_unlink=True)
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=base_obj, use_split_objects=False, use_split_groups=False)
    whole = next(o for o in bpy.data.objects if o not in before)
    raw = np.array([tuple(v.co) for v in whole.data.vertices]) * 0.1      # decimetres, MakeHuman's y up
    pts = np.stack([raw[:, 0], -raw[:, 2], raw[:, 1]], axis=1)             # -> Blender: z up, -y forward
    pts[:, 2] -= lowest
    bpy.data.objects.remove(whole, do_unlink=True)
    warped = st.tps(src, dst, pts)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(body.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    for i in range(min(13380, len(warped))):
        loc, nrm, _, dist = tree.find_nearest(Vector(tuple(warped[i])))
        if loc is not None and dist < 0.08:
            warped[i] = np.array(tuple(loc))
    print("BASE", len(pts), "vertices warped")
    return warped, lowest


def read_mhclo(path):
    """MakeHuman's fitting file: per hair vertex (indices, weights, offset), and the scale references."""
    refs, rows, reading = {}, [], False
    for line in open(path, encoding="utf-8", errors="ignore"):
        w = line.split()
        if not w or w[0].startswith("#"):
            continue
        if w[0] in ("x_scale", "y_scale", "z_scale"):
            refs[w[0][0]] = (int(w[1]), int(w[2]), float(w[3]))
            continue
        if w[0] == "verts":
            reading = True
            continue
        if reading:
            try:
                nums = [float(x) for x in w]
            except ValueError:
                if w[0] == "delete_verts":                # what follows is no longer the vertex list
                    reading = False
                continue                                  # "material ..." and the like may sit in the list
            if len(nums) == 1:
                rows.append(((int(nums[0]), int(nums[0]), int(nums[0])), (1.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
            elif len(nums) >= 9:
                rows.append(((int(nums[0]), int(nums[1]), int(nums[2])), tuple(nums[3:6]), tuple(nums[6:9])))
    return refs, rows


def fit(warped, mhclo, hair):
    """Rebuild every hair vertex from the warped base: weighted base vertices plus the offset, the
    offset scaled per axis by how our body measures between the file's reference vertices.
    MakeHuman axes are x right, y up, z forward; Blender's are x right, z up, -y forward."""
    refs, rows = read_mhclo(mhclo)
    axis = {"x": 0, "y": 2, "z": 1}
    sc = {}
    for k, (a, b, ref) in refs.items():
        sc[k] = abs(warped[a][axis[k]] - warped[b][axis[k]]) / ref if ref else 0.1
    me = hair.data
    if len(rows) != len(me.vertices):
        print("HAIR mismatch", hair.name, len(rows), len(me.vertices))
        return False
    inv = hair.matrix_world.inverted()
    for v, (idx, wts, off) in zip(me.vertices, rows):
        p = wts[0] * warped[idx[0]] + wts[1] * warped[idx[1]] + wts[2] * warped[idx[2]]
        p = p + np.array([off[0] * sc.get("x", 0.1), -off[2] * sc.get("z", 0.1), off[1] * sc.get("y", 0.1)])
        v.co = inv @ Vector(tuple(p))
    return True


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    prepared, base_obj, hair_dir, tex_dir = args[:4]
    styles = [a.split("=", 1) for a in args[4:]]
    bpy.ops.wm.open_mainfile(filepath=prepared)
    arm = bpy.data.objects["Character"]
    arm.data.pose_position = "REST"
    body = bpy.data.objects["body"]
    eyes = bpy.data.objects["eyes"]
    for o in [o for o in bpy.data.objects if o.name.startswith("mhhair_")]:
        bpy.data.objects.remove(o, do_unlink=True)
    warped, lowest = warped_base(arm, body, eyes, base_obj)
    os.makedirs(tex_dir, exist_ok=True)
    for style, hid in styles:
        before = set(bpy.data.objects)
        bpy.ops.wm.obj_import(filepath=os.path.join(hair_dir, hid, hid + ".obj"), use_split_objects=False, use_split_groups=False)
        hair = next(o for o in bpy.data.objects if o not in before and o.type == "MESH")
        if not fit(warped, os.path.join(hair_dir, hid, hid + ".mhclo"), hair):
            bpy.data.objects.remove(hair, do_unlink=True)
            continue
        hair.name = "mhhair_" + style
        hair.data.name = hair.name
        hair.data.materials.clear()
        hair.data.materials.append(bpy.data.materials.new(hair.name))
        # the texture: the diffuse named in its .mhmat, 1024 square, alpha kept
        mat = open(os.path.join(hair_dir, hid, hid + ".mhmat"), encoding="utf-8", errors="ignore").read()
        tex = next(line.split(None, 1)[1].strip() for line in mat.splitlines() if line.startswith("diffuseTexture"))
        img = bpy.data.images.load(os.path.join(hair_dir, hid, os.path.basename(tex)))
        img.scale(1024, 1024)
        img.filepath_raw = os.path.join(tex_dir, style + ".png")
        img.file_format = "PNG"
        img.save()
        print("HAIR", style, "<-", hid, "verts", len(hair.data.vertices), "texture", style + ".png")
    bpy.ops.wm.save_as_mainfile(filepath=prepared)


if __name__ == "__main__":
    main()
