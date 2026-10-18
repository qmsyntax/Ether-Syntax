"""Build a game character from a Mixamo-rigged body and its animations, inside Blender (headless):

    blender -b --python tools/assets/blender_character.py -- <out.glb> <rigged.fbx> name=<anim.fbx> [name=<anim.fbx> ...]

- <rigged.fbx> is a Mixamo download WITH skin (mesh + armature + one action, named "idle");
- every name=<anim.fbx> is a Mixamo download WITHOUT skin on the same rig; its action is kept under
  that name and its armature thrown away;
- each action goes on its own NLA track named after it, so the glTF exporter writes one animation
  per track and Godot imports them by those names;
- the body gets a plain skin material (a real skin texture comes later);
- writes one .glb.
"""
import sys

import bpy


def import_fbx(path):
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    new_objs = [o for o in bpy.data.objects if o not in before]
    new_acts = [a for a in bpy.data.actions if a not in acts_before]
    return new_objs, new_acts


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out, rigged = args[0], args[1]
    anims = [a.split("=", 1) for a in args[2:]]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs, acts = import_fbx(rigged)
    arm = next(o for o in objs if o.type == "ARMATURE")
    body = next(o for o in objs if o.type == "MESH")
    arm.name = "Character"
    tracks = [("idle", acts[0])]
    for name, path in anims:
        o2, a2 = import_fbx(path)
        tracks.append((name, a2[0]))
        for o in o2:
            bpy.data.objects.remove(o, do_unlink=True)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for name, act in tracks:
        act.name = name
        track = ad.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(act.frame_range[0]), act)
        strip.name = name
        track.mute = False
    # a plain skin until a textured one is made
    mat = bpy.data.materials.new("skin")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        # linear values (glTF stores base colour linear): a mid, weathered skin, about sRGB (0.62, 0.46, 0.38)
        bsdf.inputs["Base Color"].default_value = (0.34, 0.18, 0.12, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55
    body.data.materials.clear()
    body.data.materials.append(mat)
    print("CHARACTER tracks=%s bones=%d tris=%d" % ([t[0] for t in tracks], len(arm.data.bones), sum(len(p.vertices) - 2 for p in body.data.polygons)))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS", export_yup=True,
                              export_skins=True, export_animations=True, export_force_sampling=True)


main()
