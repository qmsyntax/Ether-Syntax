"""Make a downloaded model game-ready, inside Blender (headless):

    blender -b --python tools/assets/blender_optimize.py -- <in.gltf> <out.glb> <target_tris> [leaf_share]

- joins every mesh into one object (materials kept), with all transforms applied;
- cuts its solid surfaces down so the whole comes to about <target_tris> triangles (leaf and twig
  cards are left whole - decimating them shreds them);
- puts its origin at the middle of its base, so it stands on the ground where it is placed;
- writes one .glb with its textures inside (PNG where a texture needs transparency - leaves - JPEG otherwise).
Prints one line: OPTIMIZED <in> tris_before tris_after size_xyz.
"""
import sys

import bpy
import mathutils


def tris_of(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, out, target = args[0], args[1], int(args[2])
    card_keep = float(args[3]) if len(args) > 3 else -1.0       # share of leaf clusters to keep; -1 = by budget
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh in " + src)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # anything that is not the mesh (empties left from the hierarchy) goes
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    before = tris_of(obj)
    # Only the solid surfaces are cut down. Leaves and twigs are cards with a cut-out texture;
    # collapsing them shreds them into specks, so they keep every triangle.
    cards = set()
    for i, slot in enumerate(obj.material_slots):
        m = slot.material
        name = (m.name if m else "").lower()
        blended = m is not None and getattr(m, "surface_render_method", "") == "BLENDED"
        if blended or any(w in name for w in ("leaf", "leaves", "twig", "foliage", "grass")):
            cards.add(i)
    card_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons if p.material_index in cards)
    # Too many leaves: thin them by removing whole clusters at random (each loose piece of a card
    # material is a sprig), so what is left is still whole. Cards get up to half the budget.
    card_budget = target * 0.5 if card_keep < 0.0 else card_tris * card_keep
    if card_tris > card_budget:
        import bmesh
        import random
        rnd = random.Random(7)
        keep = card_budget / card_tris
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        seen = set()
        doomed = []
        for f in bm.faces:
            if f.index in seen or f.material_index not in cards:
                continue
            island = []
            stack = [f]
            seen.add(f.index)
            while stack:
                cur = stack.pop()
                island.append(cur)
                for e in cur.edges:
                    for nb in e.link_faces:
                        if nb.index not in seen and nb.material_index in cards:
                            seen.add(nb.index)
                            stack.append(nb)
            if rnd.random() > keep:
                doomed.extend(island)
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
        before_cards = card_tris
        card_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons if p.material_index in cards)
        print("THINNED cards %d -> %d" % (before_cards, card_tris))
    solid_tris = before - card_tris
    solid_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons if p.material_index not in cards)
    if solid_tris + card_tris > target and solid_tris > 0:
        ratio = min(1.0, max(0.05, (target - card_tris) / solid_tris))
        if ratio < 1.0:
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="DESELECT")
            bpy.ops.object.mode_set(mode="OBJECT")
            for p in obj.data.polygons:
                p.select = p.material_index not in cards
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.decimate(ratio=ratio)
            bpy.ops.object.mode_set(mode="OBJECT")
    after = tris_of(obj)
    # origin: middle of the base (Blender is Z up; the glTF exporter turns it to Y up)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    offset = mathutils.Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    obj.data.transform(mathutils.Matrix.Translation(-offset))
    obj.location = (0, 0, 0)
    obj.name = "model"
    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="AUTO",
                              export_jpeg_quality=88, export_yup=True, use_selection=False)
    print("OPTIMIZED %s %d %d %.2f %.2f %.2f" % (src, before, after, size[0], size[2], size[1]))


main()
