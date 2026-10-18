"""Export one body from Blender Studio's Human Base Meshes bundle (CC0) as an FBX for Mixamo's auto-rigger:

    blender -b human_base_meshes_bundle.blend --python tools/assets/blender_export_body.py -- GEO-body_male_realistic body_male.fbx

Keeps the body and its eyes, at the base subdivision level (about 23k triangles), centred on the origin.
"""
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
name, out = args[0], args[1]
body = bpy.data.objects[name]
keep = [body] + [c for c in body.children if c.type == "MESH"]
for o in list(bpy.data.objects):
    if o not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in keep:
    bpy.context.scene.collection.objects.link(o) if o.name not in bpy.context.scene.collection.objects else None
    o.hide_set(False); o.hide_viewport = False
    o.select_set(True)
bpy.context.view_layer.objects.active = body
for o in keep:
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        if m.type == "MULTIRES":
            m.levels = 0
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = body
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
o.location = (0.0, 0.0, 0.0)
print("BODY", o.name, "tris", sum(len(p.vertices)-2 for p in o.data.polygons), "dims", tuple(round(x,3) for x in o.dimensions), "loc", tuple(round(x,3) for x in o.location))
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, apply_unit_scale=True, add_leaf_bones=False, mesh_smooth_type="FACE")
print("EXPORTED", out)
