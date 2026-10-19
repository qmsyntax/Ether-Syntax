"""Build a game character .glb inside Blender (headless):

    blender -b --python tools/assets/blender_character.py -- <out.glb> <prepared body.blend> <animation dir> [<garment texture dir>]

- <prepared body.blend> comes from tools/assets/blender_body_prep.py: the Mixamo-rigged body (rest
  pose, idle action, shape keys, UV2 region ids) and its eyes;
- every <name>.fbx in <animation dir> other than idle.fbx is a Mixamo download WITHOUT skin on the
  same rig: its action is kept under <name>, its armature thrown away; each action gets its own NLA
  track so the glTF exporter writes one animation per track and Godot imports them by name;
- clothes, hair and beards are made here from the body itself: a garment is the body's own faces for
  the parts it covers, pushed out along the normals, so it keeps the body's skinning, region ids and
  build shape keys. Loose parts (coat skirts, collars, belts, packs, the topknot's bun, the braid)
  are lofted rings or simple solids that copy their skinning and shape keys from the nearest body
  vertex. Hair and beards are cards grown over the scalp (see build_hair);
- one-off clips are pinned in place (the game moves the body) and over-long ones trimmed (TRIM);
- each piece is its own mesh (body, eyes, hair_<style>_cards, hair_topknot_bun, hair_braid_tail,
  beard, beard_cards, cloth_<id>, stump_r); the game shows and colours them by the look and the
  equipment (game/data/wardrobe.json).
Prints the native ground speed of the walk, run and sprint loops (metres a second) for wardrobe.json.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_body_prep as prep  # noqa: E402

R_HEAD, R_NECK, R_TORSO, R_HIPS = 0, 1, 2, 3
R_UARM = (4, 5, 16, 17)
R_FARM = (6, 7)
R_HAND = (8, 9)
R_THIGH = (10, 11)
R_SHIN = (12, 13)
R_FOOT = (14, 15)


class Body:
    """Rest-pose facts about the body, per vertex, that the garment builders share."""

    def __init__(self, arm, body, eyes):
        self.arm, self.obj, self.eyes = arm, body, eyes
        me = body.data
        mw = body.matrix_world
        self.n = len(me.vertices)
        self.co = np.array([tuple(mw @ v.co) for v in me.vertices])
        self.nr = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in me.vertices])
        reg = np.zeros(self.n, dtype=np.int32)
        uv2 = me.uv_layers["regions"].data
        for loop in me.loops:
            reg[loop.vertex_index] = int(uv2[loop.index].uv.x)
        self.reg = reg
        centres = {}
        ept = [eyes.matrix_world @ v.co for v in eyes.data.vertices]
        for side in (1, -1):
            sel = [p for p in ept if p.x * side > 0]
            centres[side] = sum(sel, Vector()) / len(sel)
        self.lm = prep.landmarks(body, centres)
        self.H = self.lm["height"]
        valid = np.ones(self.n, dtype=bool)
        _, _, _, _, _, beard, scalp, _ = prep.paint(self.co, reg, valid, np.ones(self.n), np.full(self.n, 0.5), self.lm)
        self.beard, self.scalp = beard, scalp
        keys = me.shape_keys.key_blocks
        self.key_names = [k.name for k in keys]
        basis = np.array([tuple(d.co) for d in keys[0].data])
        self.key_delta = {k.name: np.array([tuple(d.co) for d in k.data]) - basis for k in keys[1:]}
        self.groups = {g.index: g.name for g in body.vertex_groups}
        self.weights = [[(self.groups[g.group], g.weight) for g in v.groups] for v in me.vertices]
        self.kd = KDTree(self.n)
        for i, p in enumerate(self.co):
            self.kd.insert(Vector(p), i)
        self.kd.balance()
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.transform(mw)
        self.bvh = BVHTree.FromBMesh(bm)
        bm.free()
        hc = self.co - self.lm["head_c"]
        rad = np.sqrt(hc[:, 0] ** 2 + hc[:, 1] ** 2) + 1e-6
        self.front = np.clip(-hc[:, 1] / rad, -1, 1)
        self.zw = self.co[self.reg == R_HIPS][:, 2].max()          # top of the hips region (waist)
        self.zc = self.co[self.reg == R_HIPS][:, 2].min()          # the crotch
        self.zneck = self.co[self.reg == R_NECK][:, 2].min()

    def bone_head(self, name):
        b = self.arm.data.bones["mixamorig:" + name]
        return np.array(tuple(self.arm.matrix_world @ b.head_local))

    def nearest(self, p, regions=None):
        if regions is None:
            return self.kd.find(Vector(p))[1]
        for co, i, d in self.kd.find_n(Vector(p), 64):
            if self.reg[i] in regions:
                return i
        return self.kd.find(Vector(p))[1]


def finish(o, uv_metres=0.35, smart=True):
    """Clean normals, smooth shading and, if asked, a fresh texture layout at uv_metres per tile."""
    me = o.data
    if me.has_custom_normals:
        prep.select_only([o], o)
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for p in me.polygons:
        p.use_smooth = True
    if smart:
        prep.select_only([o], o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        me.uv_layers.active = me.uv_layers[0]
        bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.01, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        uv = me.uv_layers[0].data
        a3 = sum(p.area for p in me.polygons)
        a2 = 0.0
        for p in me.polygons:
            pts = [uv[li].uv for li in p.loop_indices]
            for k in range(1, len(pts) - 1):
                a2 += abs((pts[k].x - pts[0].x) * (pts[k + 1].y - pts[0].y) - (pts[k + 1].x - pts[0].x) * (pts[k].y - pts[0].y)) * 0.5
        f = math.sqrt(a3 / max(a2, 1e-9)) / uv_metres
        for d in uv:
            d.uv = (d.uv.x * f, d.uv.y * f)
    me.uv_layers[0].active_render = True
    print("PIECE", o.name, "tris", sum(len(p.vertices) - 2 for p in me.polygons))
    return o


def from_body(B, name, material, keep_vert, offset, uv_metres=0.35, smooth=0, smooth_where=None, shoe=0.0):
    """A garment cut from the body: faces whose vertices all pass keep_vert(i), pushed out by
    offset(i) metres along the normal in every shape key; then `smooth` rounds of relaxing (open
    edges stay put; smooth_where(world position) limits it); `shoe` fills each foot out to its
    convex hull first, which turns toes into a toe box."""
    me = B.obj.data.copy()
    me.name = name
    off = np.array([offset(i) for i in range(B.n)])
    keep = np.array([keep_vert(i) for i in range(B.n)], dtype=bool)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    layers = [bm.verts.layers.shape[k] for k in bm.verts.layers.shape.keys()]
    inv = B.obj.matrix_world.inverted().to_3x3()
    for v in bm.verts:
        d = inv @ Vector(B.nr[v.index] * off[v.index])
        v.co += d
        for L in layers:
            v[L] += d
    drop = [f for f in bm.faces if not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    if shoe > 0.0:
        fill_feet(bm, layers, B.obj.matrix_world, shoe)
    if smooth:
        mw = B.obj.matrix_world
        relax(bm, layers, smooth, (lambda v: smooth_where(mw @ v.co)) if smooth_where else None)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = B.arm
    o.matrix_world = B.obj.matrix_world
    for g in B.obj.vertex_groups:
        o.vertex_groups.new(name=g.name)
    # vertex group weights travel with the mesh data copy
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = B.arm
    me.materials.clear()
    me.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    return finish(o, uv_metres)


def fill_feet(bm, layers, mw, out, below=0.07):
    """Footwear: every vertex of each foot below `below` metres goes out to that foot's convex hull
    (plus `out`), so the toes merge into one rounded toe box."""
    inv = mw.inverted()
    for side in (1, -1):
        vs = [v for v in bm.verts if (mw @ v.co).z < below and (mw @ v.co).x * side > 0]
        if len(vs) < 8:
            continue
        hb = bmesh.new()
        for v in vs:
            hb.verts.new(mw @ v.co)
        bmesh.ops.convex_hull(hb, input=hb.verts[:])
        for v in [v for v in hb.verts if not v.link_faces]:
            hb.verts.remove(v)
        hb.normal_update()
        tree = BVHTree.FromBMesh(hb)
        centre = sum((mw @ v.co for v in vs), Vector()) / len(vs)
        for v in vs:
            p = mw @ v.co
            loc, nrm, _, _ = tree.find_nearest(p)
            if loc is None:
                continue
            if nrm.dot(loc - centre) < 0:
                nrm = -nrm
            new = inv @ (loc + nrm * out)
            d = new - v.co
            v.co = new
            for L in layers:
                v[L] += d
        hb.free()


DRAPE = {
    # garment: (top band pinned (m), slack pushed out first (m), widen the hem (fraction),
    #           growth while the openings are held (fraction: the excess buckles into folds))
    "cloth_tunic": (0.10, 0.006, 0.0, 0.07), "cloth_tunic_skirt": (0.03, 0.004, 0.18, 0.0),
    "cloth_trousers": (0.05, 0.005, 0.0, 0.10),
    "cloth_coat": (0.12, 0.006, 0.0, 0.06), "cloth_coat_skirt": (0.03, 0.006, 0.22, 0.0),
    "cloth_padded": (0.12, 0.004, 0.0, 0.04), "cloth_padded_skirt": (0.03, 0.004, 0.12, 0.0),
    "cloth_hide": (0.12, 0.004, 0.0, 0.03), "cloth_hide_skirt": (0.03, 0.004, 0.10, 0.0),
    "cloth_robe": (0.12, 0.006, 0.0, 0.06), "cloth_robe_skirt": (0.03, 0.006, 0.2, 0.0),
}


def drape(B, o, frames=36):
    """A loose, finer copy of garment o (rest pose) dropped onto the body by Blender's cloth
    simulation: the top band is pinned, the rest is pushed out by some slack (and the hem widened)
    and falls under gravity against the body, which makes folds. Returns the settled copy,
    "<name>_draped", for baking; o itself is untouched."""
    band, slack, widen, grow = DRAPE.get(o.name, (0.08, 0.006, 0.0, 0.05))
    h = o.copy()
    h.data = o.data.copy()
    h.name = o.name + "_draped"
    bpy.context.scene.collection.objects.link(h)
    h.parent = None
    h.matrix_world = o.matrix_world.copy()
    h.shape_key_clear()
    for m in list(h.modifiers):
        h.modifiers.remove(m)
    prep.select_only([h], h)
    sub = h.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    bpy.ops.object.modifier_apply(modifier=sub.name)
    mw = h.matrix_world
    inv = mw.inverted()
    pts = [mw @ v.co for v in h.data.vertices]
    ztop = max(p.z for p in pts)
    zbot = min(p.z for p in pts)
    cx = sum(p.x for p in pts) / len(pts)
    cy = sum(p.y for p in pts) / len(pts)
    pin = h.vertex_groups.new(name="pin")
    for v, p in zip(h.data.vertices, pts):
        n = (mw.to_3x3() @ v.normal).normalized()
        t = (ztop - p.z) / max(ztop - zbot, 1e-4)
        q = p + n * slack * min(1.0, t * 4.0)
        if widen > 0.0:
            q = Vector((cx + (q.x - cx) * (1.0 + widen * t), cy + (q.y - cy) * (1.0 + widen * t), q.z))
        v.co = inv @ q
        if p.z > ztop - band:
            pin.add([v.index], 1.0, "REPLACE")
    keep = h.vertex_groups.new(name="keep_length")
    if grow > 0.0:
        # hold every opening (cuffs, hems, the neck) and let a 3 cm band beside it keep its length,
        # so the growth buckles the cloth between them instead of frilling the edges
        bm = bmesh.new()
        bm.from_mesh(h.data)
        bm.verts.ensure_lookup_table()
        edge = [v for v in bm.verts if v.is_boundary]
        pin.add([v.index for v in edge], 1.0, "REPLACE")
        dist = {v.index: 0.0 for v in edge}
        front = list(edge)
        while front:
            nxt = []
            for v in front:
                for e in v.link_edges:
                    u = e.other_vert(v)
                    d = dist[v.index] + e.calc_length() * mw.to_scale().x
                    if d < 0.03 and d < dist.get(u.index, 9.0):
                        dist[u.index] = d
                        nxt.append(u)
            front = nxt
        bm.free()
        for i, d in dist.items():
            keep.add([i], 1.0 - d / 0.03, "REPLACE")
    if not any(m.type == "COLLISION" for m in B.obj.modifiers):
        B.obj.modifiers.new("Collision", "COLLISION")
        B.obj.collision.thickness_outer = 0.004
        B.obj.collision.cloth_friction = 8.0
    cl = h.modifiers.new("Cloth", "CLOTH")
    s = cl.settings
    s.quality = 6
    s.mass = 0.2
    s.tension_stiffness = 10.0
    s.compression_stiffness = 10.0
    s.shear_stiffness = 4.0
    s.bending_stiffness = 0.4
    s.shrink_min = -grow                             # weight 0 in keep_length: grows by `grow`
    s.shrink_max = 0.0                               # weight 1: keeps its length
    s.vertex_group_shrink = "keep_length"
    s.air_damping = 2.0
    s.vertex_group_mass = "pin"
    cl.collision_settings.distance_min = 0.004
    cl.collision_settings.use_self_collision = False
    cl.point_cache.frame_start = 1
    cl.point_cache.frame_end = frames
    sc = bpy.context.scene
    for f in range(1, frames + 1):
        sc.frame_set(f)
    prep.select_only([h], h)
    bpy.ops.object.modifier_apply(modifier=cl.name)
    sc.frame_set(1)
    return h


def relax(bm, layers, rounds, where=None):
    """Laplacian relaxing of the base shape and every shape-key layer alike; boundary verts fixed."""
    bm.verts.ensure_lookup_table()
    movable = [v for v in bm.verts if not v.is_boundary and (where is None or where(v))]
    for _ in range(rounds):
        new_co = {}
        for v in movable:
            nb = [e.other_vert(v) for e in v.link_edges]
            avg = sum((u.co for u in nb), Vector()) / len(nb)
            new_co[v] = v.co + (avg - v.co) * 0.5
            for L in layers:
                a2 = sum((u[L] for u in nb), Vector()) / len(nb)
                v[L] = v[L] + (a2 - v[L]) * 0.5
        for v, c in new_co.items():
            v.co = c


def new_piece(B, name, material, verts, faces, region, weights_from=None, rigid=None, uv=None, loop_uv=None):
    """A loose piece: verts (world, rest pose), faces; skinning copied from the nearest body vertex
    (or all on one bone if rigid), shape-key deltas likewise; UV2 = region."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = B.arm
    o.matrix_parent_inverse = B.arm.matrix_world.inverted()
    near = [B.nearest(v, weights_from) for v in verts]
    if rigid:
        g = o.vertex_groups.new(name="mixamorig:" + rigid)
        g.add(list(range(len(verts))), 1.0, "REPLACE")
    else:
        groups = {}
        for vi, bi in enumerate(near):
            for gname, w in B.weights[bi]:
                if gname not in groups:
                    groups[gname] = o.vertex_groups.new(name=gname)
                groups[gname].add([vi], w, "REPLACE")
    o.shape_key_add(name="Basis", from_mix=False)
    for kname in B.key_names[1:]:
        k = o.shape_key_add(name=kname, from_mix=False)
        delta = B.key_delta[kname]
        for vi, bi in enumerate(near):
            k.data[vi].co = Vector(verts[vi]) + Vector(delta[bi])
    reg = me.uv_layers.new(name="UVMap")
    r2 = me.uv_layers.new(name="regions")
    for loop in me.loops:
        r2.data[loop.index].uv = (region + 0.5, 0.0)
        if uv is not None:
            reg.data[loop.index].uv = uv[loop.vertex_index]
        elif loop_uv is not None:
            reg.data[loop.index].uv = loop_uv[loop.index]
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = B.arm
    me.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    return finish(o, smart=uv is None and loop_uv is None)


def ring_radii(B, z, regions, centre, n, band=0.025):
    """The body's outline at height z: for n directions round centre, the farthest body vertex."""
    sel = np.isin(B.reg, regions) & (np.abs(B.co[:, 2] - z) < band)
    pts = B.co[sel][:, :2] - centre
    ang = np.arctan2(pts[:, 1], pts[:, 0])
    dist = np.linalg.norm(pts, axis=1)
    r = np.zeros(n)
    for j in range(n):
        a = -math.pi + 2 * math.pi * j / n
        d = np.abs((ang - a + math.pi) % (2 * math.pi) - math.pi)
        m = d < (2 * math.pi / n) * 1.6
        r[j] = dist[m].max() if m.any() else 0.0
    for j in range(n):                       # fill gaps from neighbours, then smooth
        if r[j] == 0.0:
            r[j] = max(r[(j - 1) % n], r[(j + 1) % n])
    for _ in range(3):
        r = (np.roll(r, 1) + 2 * r + np.roll(r, -1)) / 4
    return r


def loft(B, name, material, rows, n, region, weights_from, gap=None, cap_top=False, uv_metres=0.35):
    """A tube through rings: rows is a list of (z, radii array, centre xy). gap(row_t, angle) -> True
    leaves that face out (a coat's opening)."""
    verts, faces, uvs = [], [], []
    for (z, r, c) in rows:
        for j in range(n + 1):
            a = -math.pi + 2 * math.pi * j / n
            verts.append((c[0] + r[j % n] * math.cos(a), c[1] + r[j % n] * math.sin(a), z))
    for i in range(len(rows) - 1):
        t = i / max(1, len(rows) - 2)
        for j in range(n):
            a = -math.pi + 2 * math.pi * (j + 0.5) / n
            if gap is not None and gap(t, a):
                continue
            k0 = i * (n + 1) + j
            faces.append((k0, k0 + 1, k0 + n + 2, k0 + n + 1))
    return new_piece(B, name, material, verts, faces, region, weights_from)


def skirt(B, name, material, z_top, z_bot, base, flare, opening=0.0, n=48, rows=9):
    centre = B.co[(B.reg == R_HIPS)][:, :2].mean(axis=0)
    out = []
    for i in range(rows):
        t = i / (rows - 1)
        z = z_top + (z_bot - z_top) * t
        r = ring_radii(B, z, [R_HIPS, R_TORSO] + list(R_THIGH) + list(R_SHIN), centre, n, 0.03)
        out.append((z, r + base + flare * t * t, centre))
    gap = None
    if opening > 0.0:
        def gap(t, a):
            front = abs((a + math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)     # 0 straight ahead (-Y)
            return front < (opening * (0.15 + 0.85 * t)) / 0.35
    return loft(B, name, material, out, n, R_HIPS, [R_HIPS] + list(R_THIGH), gap)


def collar(B, name, material, height, base, flare, n=36):
    centre = B.co[B.reg == R_NECK][:, :2].mean(axis=0)
    z0 = B.zneck - 0.01
    rows = []
    for i in range(4):
        t = i / 3
        r = ring_radii(B, z0, [R_NECK, R_TORSO], centre, n, 0.02)
        rows.append((z0 + height * t, r + base + flare * t, centre))
    return loft(B, name, material, rows, n, R_TORSO, [R_NECK, R_TORSO])


def band(B, name, material, z, regions, base, height, n=40, weights_from=None):
    centre = B.co[np.isin(B.reg, regions) & (np.abs(B.co[:, 2] - z) < 0.03)][:, :2].mean(axis=0)
    r = ring_radii(B, z, regions, centre, n, 0.02)
    rows = [(z - height * 0.5, r + base, centre), (z - height * 0.5, r + base + 0.004, centre),
            (z + height * 0.5, r + base + 0.004, centre), (z + height * 0.5, r + base, centre)]
    verts, faces = [], []
    for (zz, rr, c) in rows:
        for j in range(n + 1):
            a = -math.pi + 2 * math.pi * j / n
            verts.append((c[0] + rr[j % n] * math.cos(a), c[1] + rr[j % n] * math.sin(a), zz))
    for i in range(3):
        for j in range(n):
            k0 = i * (n + 1) + j
            faces.append((k0, k0 + 1, k0 + n + 2, k0 + n + 1))
    return new_piece(B, name, material, verts, faces, regions[0], weights_from or regions)


def box(centre, size, rot_x=0.0):
    """Verts and faces of a box (world), size = (x, y, z) full lengths."""
    sx, sy, sz = (s * 0.5 for s in size)
    vs = [Vector((x, y, z)) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    m = Matrix.Rotation(rot_x, 3, "X")
    vs = [tuple(Vector(centre) + m @ v) for v in vs]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return vs, fs


def merge(parts):
    verts, faces = [], []
    for vs, fs in parts:
        base = len(verts)
        verts += list(vs)
        faces += [tuple(i + base for i in f) for f in fs]
    return verts, faces


def tube(points, radius, n=8):
    """A tube along points (list of 3-vectors) with radii (float or list)."""
    verts, faces = [], []
    rs = radius if isinstance(radius, list) else [radius] * len(points)
    for i, p in enumerate(points):
        p = Vector(p)
        d = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        u = d.cross(Vector((1, 0, 0)))
        if u.length < 0.1:
            u = d.cross(Vector((0, 1, 0)))
        u.normalize()
        w = d.cross(u)
        for j in range(n):
            a = 2 * math.pi * j / n
            verts.append(tuple(p + (u * math.cos(a) + w * math.sin(a)) * rs[i]))
    for i in range(len(points) - 1):
        for j in range(n):
            a0, a1 = i * n + j, i * n + (j + 1) % n
            faces.append((a0, a1, a1 + n, a0 + n))
    return verts, faces


def blob(centre, radii, rings=6, segs=10):
    verts, faces = [], []
    c = Vector(centre)
    verts.append(tuple(c + Vector((0, 0, -radii[2]))))
    for i in range(1, rings):
        t = math.pi * i / rings - math.pi / 2
        for j in range(segs):
            a = 2 * math.pi * j / segs
            verts.append(tuple(c + Vector((radii[0] * math.cos(t) * math.cos(a), radii[1] * math.cos(t) * math.sin(a), radii[2] * math.sin(t)))))
    verts.append(tuple(c + Vector((0, 0, radii[2]))))
    top = len(verts) - 1
    for j in range(segs):
        faces.append((0, 1 + (j + 1) % segs, 1 + j))
    for i in range(rings - 2):
        for j in range(segs):
            a0 = 1 + i * segs + j
            a1 = 1 + i * segs + (j + 1) % segs
            faces.append((a0, a1, a1 + segs, a0 + segs))
    last = 1 + (rings - 2) * segs
    for j in range(segs):
        faces.append((last + j, last + (j + 1) % segs, top))
    return verts, faces


def back_surface(B, x, z, out=0.0):
    """The point on the body's back at (x, z), pushed out by `out` metres."""
    hit = B.bvh.ray_cast(Vector((x, 0.6, z)), Vector((0, -1, 0)))
    if hit[0] is None:
        return Vector((x, 0.1 + out, z))
    return hit[0] + Vector((0, out, 0))


# --- the wardrobe -----------------------------------------------------------------------------

def build_clothes(B):
    H, reg, co = B.H, B.reg, B.co
    sleeve_end = lambda i: reg[i] in R_UARM or (reg[i] in R_FARM and np.linalg.norm(co[i] - B.bone_head("LeftHand" if co[i][0] > 0 else "RightHand")) > 0.05)
    torso = lambda i: reg[i] in (R_TORSO, R_HIPS) or (reg[i] == R_NECK and co[i][2] < B.zneck + 0.025)
    legs = lambda i: reg[i] in (R_HIPS,) + R_THIGH + R_SHIN
    knee_z = 0.285 * H
    toe = lambda i: 1.0 if reg[i] in R_FOOT and co[i][2] < 0.045 else 0.0          # the foot below the ankle bones
    toe_v = lambda p: p.z < 0.065                                                    # world position: relax below the ankle

    # everyday clothes: a tunic, trousers, wrapped shoes
    from_body(B, "cloth_tunic", "cloth_tunic", lambda i: torso(i) or reg[i] in R_UARM or (reg[i] in R_FARM and np.linalg.norm(co[i] - B.bone_head("LeftHand" if co[i][0] > 0 else "RightHand")) > 0.13),
              lambda i: 0.009 + (0.004 if reg[i] == R_HIPS else 0.0), smooth=4)
    skirt(B, "cloth_tunic_skirt", "cloth_tunic", B.zw - 0.02, B.zc - 0.10, 0.012, 0.03)
    from_body(B, "cloth_trousers", "cloth_trousers", lambda i: legs(i) and co[i][2] > 0.06 * H, lambda i: 0.008 + (0.003 if reg[i] in R_THIGH else 0.0), smooth=6)
    from_body(B, "cloth_wraps", "cloth_wraps", lambda i: reg[i] in R_FOOT or (reg[i] in R_SHIN and co[i][2] < 0.085 * H), lambda i: 0.0045, shoe=0.004, smooth=6, smooth_where=toe_v)

    # body slot
    from_body(B, "cloth_coat", "cloth_coat", lambda i: torso(i) or sleeve_end(i), lambda i: 0.018 + (0.006 if reg[i] == R_HIPS else 0.0), smooth=5)
    skirt(B, "cloth_coat_skirt", "cloth_coat", B.zw - 0.01, knee_z - 0.02, 0.024, 0.07, opening=0.10)
    collar(B, "cloth_coat_collar", "cloth_coat", 0.06, 0.022, 0.025)
    from_body(B, "cloth_padded", "cloth_padded", lambda i: torso(i) or sleeve_end(i), lambda i: 0.019 + (0.004 if reg[i] == R_TORSO else 0.0))
    skirt(B, "cloth_padded_skirt", "cloth_padded", B.zw - 0.01, B.zc - 0.05, 0.026, 0.02)
    from_body(B, "cloth_hide", "cloth_hide", lambda i: torso(i) and not (reg[i] == R_TORSO and abs(co[i][0]) > 0.17 * H * 0.6 and co[i][2] > B.zneck - 0.10),
              lambda i: 0.015)
    skirt(B, "cloth_hide_skirt", "cloth_hide", B.zw - 0.01, B.zc - 0.02, 0.022, 0.015)

    # head slot
    eye_z = B.lm["eye"][2]
    face = lambda i: B.front[i] > 0.45 and co[i][2] < eye_z + 0.045 and co[i][2] > B.lm["chin_z"] - 0.03
    from_body(B, "cloth_hood", "cloth_hood", lambda i: (reg[i] == R_HEAD and not face(i)) or reg[i] == R_NECK or (reg[i] == R_TORSO and co[i][2] > B.zneck - 0.11),
              lambda i: 0.024 + 0.012 * max(0.0, (co[i][2] - eye_z) / 0.12) * (B.front[i] < 0.2) if reg[i] == R_HEAD else 0.028)
    from_body(B, "cloth_cap", "cloth_cap", lambda i: reg[i] == R_HEAD and co[i][2] > eye_z + (0.04 if B.front[i] > 0.3 else 0.012) and B.scalp[i] > 0.2,
              lambda i: 0.009)

    # hands slot
    hand_d = lambda i: np.linalg.norm(co[i] - B.bone_head("LeftHand" if co[i][0] > 0 else "RightHand"))
    from_body(B, "cloth_gloves", "cloth_gloves", lambda i: reg[i] in R_HAND or (reg[i] in R_FARM and hand_d(i) < 0.07), lambda i: 0.0028 if reg[i] in R_HAND else 0.007)
    from_body(B, "cloth_bracers", "cloth_bracers", lambda i: reg[i] in R_FARM and 0.025 < hand_d(i) < 0.17, lambda i: 0.010)

    # feet slot
    from_body(B, "cloth_boots", "cloth_boots", lambda i: reg[i] in R_FOOT or (reg[i] in R_SHIN and co[i][2] < 0.13 * H), lambda i: 0.0065, shoe=0.006, smooth=6, smooth_where=toe_v)
    from_body(B, "cloth_tallboots", "cloth_tallboots", lambda i: reg[i] in R_FOOT or (reg[i] in R_SHIN and co[i][2] < knee_z - 0.03), lambda i: 0.0075 + (0.003 if reg[i] in R_SHIN else 0.0), shoe=0.007, smooth=6, smooth_where=toe_v)

    # belt slot
    # belts ride outside the thickest top (the coat at the waist is ~25 mm out)
    band(B, "cloth_beltrope", "cloth_beltrope", B.zw - 0.015, [R_HIPS, R_TORSO], 0.031, 0.018)
    band(B, "cloth_belt", "cloth_belt", B.zw - 0.015, [R_HIPS, R_TORSO], 0.031, 0.045)
    # pouches and a small quiver on the belt
    hips_c = co[reg == R_HIPS][:, :2].mean(axis=0)
    parts = []
    for side in (1, -1):
        p = Vector((hips_c[0] + side * 0.16, hips_c[1] - 0.04, B.zw - 0.05))
        parts.append(box(p, (0.07, 0.05, 0.08)))
    parts.append(tube([(hips_c[0] - 0.13, hips_c[1] + 0.10, B.zw - 0.22), (hips_c[0] - 0.12, hips_c[1] + 0.13, B.zw + 0.10)], 0.035, 10))
    v, f = merge(parts)
    new_piece(B, "cloth_belt_gear", "cloth_belt", v, f, R_HIPS, rigid="Hips")

    # back slot: a canvas pack, a wooden frame with a bundle
    zc = B.zneck - 0.20
    back = back_surface(B, 0.0, zc, 0.0)
    v, f = merge([box(back + Vector((0, 0.09, 0.0)), (0.30, 0.15, 0.38)), box(back + Vector((0, 0.10, 0.16)), (0.31, 0.17, 0.10))])
    new_piece(B, "cloth_pack", "cloth_pack", v, f, R_TORSO, rigid="Spine2")
    parts = []
    for sx in (-0.14, 0.14):
        parts.append(box(back + Vector((sx, 0.07, -0.02)), (0.035, 0.035, 0.70)))
    for dz in (-0.30, -0.05, 0.25):
        parts.append(box(back + Vector((0, 0.07, dz)), (0.32, 0.03, 0.03)))
    parts.append(tube([tuple(back + Vector((-0.17, 0.15, 0.06))), tuple(back + Vector((0.17, 0.15, 0.06)))], 0.09, 12))
    v, f = merge(parts)
    new_piece(B, "cloth_frame", "cloth_frame", v, f, R_TORSO, rigid="Spine2")

    # look: a headband
    from_body(B, "cloth_headband", "cloth_headband", lambda i: reg[i] == R_HEAD and abs(co[i][2] - (eye_z + 0.047 + 0.02 * min(0.0, B.front[i]))) < 0.012,
              lambda i: 0.0075)

    build_invader_gear(B, face, eye_z, knee_z, torso, sleeve_end, toe_v)


def build_invader_gear(B, face, eye_z, knee_z, torso, sleeve_end, toe_v):
    """What the realm invaders wear (the enemies): a smooth bone mask with eye holes, a long robe,
    a cape, plate (cuirass, helmet with a crest, pauldrons, greaves). Same method as the clothes."""
    H, reg, co = B.H, B.reg, B.co
    el, er = np.array(B.lm["eye_l"]), np.array(B.lm["eye_r"])
    eye_hole = lambda i: min(np.linalg.norm(co[i] - el), np.linalg.norm(co[i] - er)) < 0.017
    mask = lambda i: reg[i] == R_HEAD and B.front[i] > 0.3 and B.lm["chin_z"] - 0.012 < co[i][2] < eye_z + 0.055 and not eye_hole(i)
    from_body(B, "cloth_mask", "cloth_mask", mask, lambda i: 0.012 + 0.006 * max(0.0, B.front[i] - 0.6), smooth=10, uv_metres=0.2)
    wrist = lambda i: reg[i] in R_FARM and np.linalg.norm(co[i] - B.bone_head("LeftHand" if co[i][0] > 0 else "RightHand")) > 0.04
    from_body(B, "cloth_robe", "cloth_robe", lambda i: torso(i) or reg[i] in R_UARM or wrist(i), lambda i: 0.016 + (0.006 if reg[i] == R_HIPS else 0.0), smooth=5)
    skirt(B, "cloth_robe_skirt", "cloth_robe", B.zw - 0.01, 0.075 * H, 0.03, 0.13, opening=0.05)
    # cape: a panel off the shoulder blades to the calves, hanging off the spine
    rows, n = 12, 9
    verts, faces = [], []
    z0 = B.zneck - 0.03
    for i in range(rows):
        t = i / (rows - 1)
        z = z0 - (z0 - 0.33 * H) * t
        width = 0.17 + 0.09 * t
        for j in range(n):
            x = -width + 2 * width * j / (n - 1)
            p = back_surface(B, x * (0.85 if t < 0.25 else 1.0), max(z, B.zc + 0.02) if t < 0.5 else z, 0.045 + 0.06 * t)
            p.z = z
            verts.append(tuple(p))
    for i in range(rows - 1):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + 1, a + n + 1, a + n))
    o = new_piece(B, "cloth_cape", "cloth_cape", verts, faces, R_TORSO, weights_from=[R_TORSO])
    blend_down(o, B, [("Spine2", z0, z0 - 0.15), ("Spine1", z0 - 0.15, z0 - 0.3), ("Spine", z0 - 0.3, B.zw - 0.05), ("Hips", B.zw - 0.05, 0.0)])
    # plate
    from_body(B, "cloth_cuirass", "cloth_cuirass", lambda i: torso(i) and co[i][2] > B.zc + 0.06, lambda i: 0.034, smooth=12)
    skirt(B, "cloth_tassets", "cloth_cuirass", B.zw - 0.01, B.zc - 0.13, 0.04, 0.05)
    from_body(B, "cloth_helmet", "cloth_helmet", lambda i: reg[i] == R_HEAD and (co[i][2] > eye_z + 0.012 or (B.front[i] < 0.3 and co[i][2] > B.lm["chin_z"] - 0.01)),
              lambda i: 0.03, smooth=10, uv_metres=0.25)
    crest = box(Vector((0.0, B.lm["head_c"][1] + 0.01, B.lm["top"] + 0.045)), (0.025, 0.24, 0.07))
    new_piece(B, "cloth_helmet_crest", "cloth_helmet", crest[0], crest[1], R_HEAD, rigid="Head")
    parts = []
    for side, bone in ((1, "LeftArm"), (-1, "RightArm")):
        p = Vector(tuple(B.bone_head(bone))) + Vector((side * 0.02, 0.0, 0.045))
        parts.append(blob(p, (0.085, 0.095, 0.055), 6, 12))
    v, f = merge(parts)
    o = new_piece(B, "cloth_pauldrons", "cloth_pauldrons", v, f, R_TORSO, weights_from=[R_TORSO] + list(R_UARM))
    from_body(B, "cloth_greaves", "cloth_greaves", lambda i: reg[i] in R_SHIN and 0.12 * H < co[i][2] < knee_z + 0.02, lambda i: 0.02, smooth=6)


# --- per-garment texture sets ---------------------------------------------------------------

def unique_uv(o, tile_metres=0.35):
    """Pack the garment's layout into 0..1 (for its own baked maps) and record in UV2.y how many
    fabric tiles one UV unit spans, so the shader can still tile the fabric at tile_metres."""
    me = o.data
    me.uv_layers.active = me.uv_layers[0]
    prep.select_only([o], o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, scale=True, margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = me.uv_layers[0].data
    u0 = math.floor(min(d.uv.x for d in uv) + 1e-4)
    v0 = math.floor(min(d.uv.y for d in uv) + 1e-4)
    for d in uv:
        d.uv = (d.uv.x - u0, d.uv.y - v0)
    a3 = sum(p.area for p in me.polygons) * (o.matrix_world.to_scale().x ** 2)
    a2 = 0.0
    for p in me.polygons:
        pts = [uv[li].uv for li in p.loop_indices]
        for k in range(1, len(pts) - 1):
            a2 += abs((pts[k].x - pts[0].x) * (pts[k + 1].y - pts[0].y) - (pts[k + 1].x - pts[0].x) * (pts[k].y - pts[0].y)) * 0.5
    metres = math.sqrt(a3 / max(a2, 1e-9))
    r2 = me.uv_layers["regions"].data
    for d in r2:
        d.uv = (d.uv.x, metres / tile_metres)
    me.uv_layers[0].active_render = True
    me.uv_layers.active = me.uv_layers[0]
    return a3


def take_folds(o, h, most=0.025):
    """Move the game mesh's vertices onto the draped copy (at most `most` metres), in every shape
    key, so the folds show in the silhouette too."""
    bm = bmesh.new()
    bm.from_mesh(h.data)
    bm.transform(h.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    me = o.data
    mw = o.matrix_world
    inv = mw.inverted().to_3x3()
    keys = me.shape_keys.key_blocks if me.shape_keys else []
    for v in me.vertices:
        p = mw @ v.co
        loc, _, _, dist = tree.find_nearest(p)
        if loc is None:
            continue
        d = loc - p
        if d.length > most:
            d = d.normalized() * most
        dl = inv @ d
        v.co += dl
        for k in keys:
            k.data[v.index].co += dl


def seam_fields(o, B):
    """Per vertex: distance along the cloth to the nearest opening (hem) and to the nearest seam
    (where the body region changes, e.g. the armhole; and the side lines). Stored as a colour
    attribute: R hem distance / 0.05, G seam distance / 0.05."""
    me = o.data
    mw = o.matrix_world
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    reg_l = me.uv_layers["regions"].data
    vreg = {}
    for loop in me.loops:
        vreg[loop.vertex_index] = int(reg_l[loop.index].uv.x)
    nrm = {v.index: (mw.to_3x3() @ v.normal).normalized() for v in bm.verts}
    same = lambda a, b: a == b or {a, b} in ({4, 16}, {5, 17})

    def spread(seeds, limit=0.05):
        dist = {i: 0.0 for i in seeds}
        front = list(seeds)
        while front:
            nxt = []
            for i in front:
                v = bm.verts[i]
                for e in v.link_edges:
                    u = e.other_vert(v)
                    d = dist[i] + ((mw @ u.co) - (mw @ v.co)).length
                    if d < limit and d < dist.get(u.index, 9.0):
                        dist[u.index] = d
                        nxt.append(u.index)
            front = nxt
        return dist

    hem = spread([v.index for v in bm.verts if v.is_boundary])
    seams = set()
    for e in bm.edges:
        a, b = e.verts
        if not same(vreg.get(a.index, 0), vreg.get(b.index, 0)):
            seams.update((a.index, b.index))
        na, nb = nrm[a.index], nrm[b.index]
        if na.y * nb.y < 0.0 and abs(na.x) > 0.75 and abs(nb.x) > 0.75:   # the side line
            seams.update((a.index, b.index))
    seam = spread(list(seams))
    bm.free()
    col = me.color_attributes.new("fields", "FLOAT_COLOR", "POINT")
    for i in range(len(me.vertices)):
        col.data[i].color = (min(1.0, hem.get(i, 1.0) / 0.05), min(1.0, seam.get(i, 1.0) / 0.05), 0.0, 1.0)
    return col


def bake_garment(B, o, h, out_dir, size):
    """Bake o's own maps: <name>_fold.png (tangent normals of the draped copy h) and
    <name>_detail.png (R occlusion, G convexity of the folds (0.5 flat), B hem band, A stitching)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    keep_mats = list(o.data.materials)
    mat = prep.ensure_material(o, o.name + "_bake")
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.hide_render = ob not in (o, h, B.obj)
    sc.render.bake.margin = 8
    # 1. folds: normals of the draped copy onto the game mesh
    img_n, _ = prep.bake_image(o, o.name + "_fold", size)
    img_n.generated_color = (0.5, 0.5, 1.0, 1.0)
    if h is not None:
        prep.select_only([h, o], o)
        sc.render.bake.use_selected_to_active = True
        sc.render.bake.cage_extrusion = 0.02
        sc.render.bake.max_ray_distance = 0.04
        sc.cycles.samples = 1
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    nrm = prep.pixels(img_n)
    # 2. occlusion (the body and the folds shade the cloth), off the game mesh alone
    prep.select_only([o], o)
    sc.render.bake.use_selected_to_active = False
    img_ao, _ = prep.bake_image(o, o.name + "_ao", size)
    sc.cycles.samples = 32
    h_was = h.hide_render if h is not None else None
    if h is not None:
        h.hide_render = True
    bpy.ops.object.bake(type="AO")
    ao = prep.pixels(img_ao)[..., 0]
    # 3. convexity of the folds, from the draped copy
    conv = np.full(ao.shape, 0.5, dtype=np.float32)
    if h is not None:
        h.hide_render = False

        def cav(nodes, links):
            g = nodes.new("ShaderNodeNewGeometry")
            mr = nodes.new("ShaderNodeMapRange")
            mr.inputs["From Min"].default_value = 0.42
            mr.inputs["From Max"].default_value = 0.58
            links.new(g.outputs["Pointiness"], mr.inputs["Value"])
            return mr.outputs["Result"]
        prep.emission_material(h, h.name + "_cav", cav)
        prep.select_only([h, o], o)
        sc.render.bake.use_selected_to_active = True
        img_c, _ = prep.bake_image(o, o.name + "_cav", size)
        sc.cycles.samples = 1
        bpy.ops.object.bake(type="EMIT")
        conv = prep.pixels(img_c)[..., 0]
    # 4. hem and seam distances, off the game mesh's own colour attribute
    seam_fields(o, B)

    def fields(nodes, links):
        a = nodes.new("ShaderNodeVertexColor")
        a.layer_name = "fields"
        return a.outputs["Color"]
    prep.emission_material(o, o.name + "_fields", fields)
    prep.select_only([o], o)
    sc.render.bake.use_selected_to_active = False
    img_f, _ = prep.bake_image(o, o.name + "_f", size, float_buf=True)
    sc.render.bake.margin = 8
    bpy.ops.object.bake(type="EMIT")
    f = prep.pixels(img_f)
    hem_d = f[..., 0] * 0.05
    seam_d = f[..., 1] * 0.05
    hem = prep.smooth(0.022 - hem_d, 0.0, 0.004)
    stitch_line = lambda d, at: np.clip(1.0 - np.abs(d - at) / 0.0011, 0.0, 1.0)
    # dashes: alternate along the cloth by the other distance field's fine ripple
    yy, xx = np.mgrid[0:size, 0:size]
    dash = (np.sin((xx + yy) * (2 * math.pi / max(4, size / 180))) > -0.2).astype(np.float32)
    stitch = np.clip(np.maximum(stitch_line(hem_d, 0.016), np.maximum(stitch_line(seam_d, 0.005), stitch_line(seam_d, 0.0))) * dash, 0, 1)
    seam_groove = np.clip(1.0 - seam_d / 0.003, 0, 1)
    ao2 = ao * (1.0 - 0.35 * seam_groove)
    detail = np.stack([ao2, conv, hem, stitch], axis=-1).astype(np.float32)
    # outside the islands (and their bake margin): neutral values, or small mipmaps darken every seam
    inside = prep.pixels(img_ao)[..., 3] > 0.5
    detail[~inside] = (1.0, 0.5, 0.0, 0.0)
    nrm = np.array(nrm)
    nrm[~inside] = (0.5, 0.5, 1.0, 1.0)
    os.makedirs(out_dir, exist_ok=True)
    prep.save_png(nrm, os.path.join(out_dir, o.name + "_fold.png"))
    prep.save_png(detail, os.path.join(out_dir, o.name + "_detail.png"))
    o.data.materials.clear()
    for m in keep_mats:
        o.data.materials.append(m)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.hide_render = False


def texture_garments(B, out_dir):
    """Drape, fold and bake every cloth piece (sizes by area: 1024 for big pieces, else 512)."""
    arm_was = B.arm.data.pose_position
    B.arm.data.pose_position = "REST"
    for o in [ob for ob in bpy.data.objects if ob.type == "MESH" and ob.name.startswith("cloth_")]:
        area = unique_uv(o)
        h = drape(B, o) if o.name in DRAPE else None
        if h is not None:
            take_folds(o, h)
        size = 1024 if area > 0.25 else 512
        bake_garment(B, o, h, out_dir, size)
        if h is not None:
            bpy.data.objects.remove(h, do_unlink=True)
        print("TEXTURED", o.name, "area %.2f m2" % area, size)
    B.arm.data.pose_position = arm_was


def build_hair(B):
    """Hair: MakeHuman's CC0 hair meshes, fitted to this body by blender_mh_hair.py and left in the
    prepared .blend as "mhhair_<style>"; skinned to the head (long styles blend down the neck and
    back). Beards: hair cards grown over the beard area - ribbons from roots that follow a combing
    direction along the face (kept just above it) and fall under gravity."""
    co, reg, lm, s = B.co, B.reg, B.lm, B.lm["s"]
    eye_z = lm["eye"][2]
    top = co[:, 2] - eye_z
    hc = lm["head_c"]
    crown = Vector((0.0, hc[1] + 0.025, lm["top"] - 0.012))
    nape = Vector((0.0, hc[1] + 0.07, eye_z - 0.06))
    knot = Vector((0.0, hc[1] + 0.06, lm["top"] - 0.035))
    rng = np.random.default_rng(7)
    on_top = lambda i: top[i] > 0.05 * s or (B.front[i] > 0.55 and top[i] > 0.035 * s)

    # the hair styles themselves: MakeHuman's meshes fitted by blender_mh_hair.py
    hang = {"long": 0.45, "braid": 0.5, "topknot": 0.42, "bob": 0.2}
    for src in [o for o in bpy.data.objects if o.name.startswith("mhhair_")]:
        style = src.name[len("mhhair_"):]
        me = src.data
        mw = src.matrix_world
        verts = [tuple(mw @ v.co) for v in me.vertices]
        faces = [tuple(p.vertices) for p in me.polygons]
        loop_uv = [tuple(d.uv) for d in me.uv_layers[0].data]
        bpy.data.objects.remove(src, do_unlink=True)
        o = new_piece(B, "hair_" + style, "hair_" + style, verts, faces, R_HEAD, weights_from=[R_HEAD], loop_uv=loop_uv)
        if style in hang:
            blend_down(o, B, [("Head", eye_z - 0.05, eye_z - 0.11), ("Neck", eye_z - 0.11, eye_z - 0.18), ("Spine2", eye_z - 0.18, eye_z - hang[style])])
    # beard: a thin shell over the beard area and short cards combed down
    from_body(B, "beard", "hair", lambda i: reg[i] in (R_HEAD, R_NECK) and B.beard[i] > 0.7, lambda i: 0.0022, uv_metres=0.12)
    beard_roots = roots_on(B, lambda i: reg[i] in (R_HEAD, R_NECK) and B.beard[i] > 0.4, 0.0045, rng)
    grow_cards(B, "beard_cards", dict(roots=beard_roots, comb=lambda p: Vector((0.0, -0.3, -1.0)), length=(0.022, 0.05), width=0.02, lift=0.004, gravity=0.5), rng)


def roots_on(B, keep, spacing, rng):
    """Hair roots on the body's surface near vertices that pass keep(i), jittered, thinned so no two
    are closer than spacing. Returns (point, normal) pairs."""
    idx = [i for i in range(B.n) if keep(i)]
    rng.shuffle(idx)
    taken = []
    grid = {}
    cell = spacing
    for i in idx:
        p = Vector(B.co[i]) + Vector(tuple(rng.normal(0, spacing * 0.3, 3)))
        loc, nrm, _, _ = B.bvh.find_nearest(p)
        if loc is None:
            continue
        key = (int(loc.x // cell), int(loc.y // cell), int(loc.z // cell))
        near = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q in grid.get((key[0] + dx, key[1] + dy, key[2] + dz), ()):
                        if (q - loc).length < spacing:
                            near = True
        if near:
            continue
        grid.setdefault(key, []).append(loc)
        taken.append((loc, nrm))
    return taken


def grow_cards(B, name, cfg, rng):
    """Ribbons from cfg["roots"] (point, normal) along cfg["comb"](p), hugging the head's surface
    at cfg["lift"] and falling under cfg["gravity"]. UV: U across 0..1, V root to tip 0..1; UV2.y a
    random number per card for the shader."""
    verts, faces, uv, uv2 = [], [], [], []
    step = 0.008 if cfg["length"][1] < 0.15 else 0.018
    down = Vector((0, 0, -1))
    for root, nrm in cfg["roots"]:
        length = rng.uniform(*cfg["length"])
        if cfg.get("short_front") and root.y < B.lm["head_c"][1] - 0.03 and root.z < B.lm["top"] - 0.04:
            length *= cfg["short_front"]                  # a fringe, not a curtain over the eyes
        lift = cfg["lift"] * rng.uniform(0.6, 1.4)
        p = root + nrm * lift
        n = nrm
        path, norms = [p.copy()], [n.copy()]
        d = None
        steps = max(2, int(length / step))
        for k in range(steps):
            want = Vector(cfg["comb"](p))
            if want.length < 1e-6:
                want = down.copy()
            want.normalize()
            if p.z <= cfg.get("stick_z", -1.0):
                want = (down + want * 0.15).normalized()     # off the head: it falls
            t = k / steps
            want = (want * (1.0 - cfg["gravity"] * t) + down * (cfg["gravity"] * t)).normalized()
            if cfg.get("wild"):
                want = (want + Vector(tuple(rng.normal(0, cfg["wild"] * 0.3, 3)))).normalized()
            d = want if d is None else (d * 0.55 + want * 0.45).normalized()
            stick = p.z > cfg.get("stick_z", -1.0)
            if stick:
                d = (d - n * d.dot(n))
                if d.length < 1e-4:
                    d = down - n * down.dot(n)
                d.normalize()
            p = p + d * step
            loc, sn, _, _ = B.bvh.find_nearest(p)
            if loc is not None:
                n = sn
                out = (p - loc).dot(sn)
                if out < lift or (stick and out > lift):
                    p = loc + sn * lift
            path.append(p.copy())
            norms.append(n.copy())
            if "stop" in cfg and (p - cfg["stop"]).length < 0.02:
                break
        w = cfg["width"] * rng.uniform(0.7, 1.2)
        r = float(rng.random())
        base = len(verts)
        m = len(path)
        for k in range(m):
            fwd = (path[min(k + 1, m - 1)] - path[max(k - 1, 0)]).normalized()
            side = fwd.cross(norms[k])
            if side.length < 1e-4:
                side = fwd.cross(Vector((0, 1, 0)))
            side.normalize()
            half = w * 0.5 * (1.0 - 0.55 * k / (m - 1))
            for sgn, u in ((-1, 0.0), (1, 1.0)):
                verts.append(tuple(path[k] + side * half * sgn))
                uv.append((u, k / (m - 1)))
                uv2.append(r)
        for k in range(m - 1):
            a = base + 2 * k
            faces.append((a, a + 1, a + 3, a + 2))
    o = new_piece(B, name, "hair_cards", verts, faces, R_HEAD, weights_from=[R_HEAD, R_NECK], uv=uv)
    r2 = o.data.uv_layers["regions"].data
    for loop in o.data.loops:
        r2[loop.index].uv = (R_HEAD + 0.5, uv2[loop.vertex_index])
    print("CARDS", name, len(cfg["roots"]), "cards")
    return o


def hair_uv(B):
    """The beard shell gets a layout that runs top to bottom: U the arc round the head, V the drop (metres)."""
    cx, cy = 0.0, B.lm["head_c"][1]
    top = B.lm["top"]
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name != "beard":
            continue
        me = o.data
        uv = me.uv_layers[0].data
        mw = o.matrix_world
        for loop in me.loops:
            p = mw @ me.vertices[loop.vertex_index].co
            ang = math.atan2(p.x - cx, -(p.y - cy))
            uv[loop.index].uv = (ang * 0.095, top - p.z)
        for poly in me.polygons:
            us = [uv[li].uv.x for li in poly.loop_indices]
            if max(us) - min(us) > 0.2:
                for li in poly.loop_indices:
                    if uv[li].uv.x < 0:
                        uv[li].uv = (uv[li].uv.x + 2 * math.pi * 0.095, uv[li].uv.y)


def blend_down(o, B, spans):
    """Re-skin a hanging piece by height: each vertex rides the bone whose span holds it, blending
    into the next across the span."""
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)
    groups = {name: o.vertex_groups.new(name="mixamorig:" + name) for name, _, _ in spans}
    mw = o.matrix_world
    for v in o.data.vertices:
        z = (mw @ v.co).z
        w = {}
        for k, (name, ztop, zbot) in enumerate(spans):
            if z >= zbot or k == len(spans) - 1:
                t = np.clip((ztop - z) / max(ztop - zbot, 1e-4), 0, 1)
                nxt = spans[k + 1][0] if k + 1 < len(spans) else None
                w[name] = 1.0 - 0.5 * t if nxt else 1.0
                if nxt:
                    w[nxt] = 0.5 * t
                break
        for name, wt in w.items():
            groups[name].add([v.index], float(wt), "REPLACE")


def build_anatomy(B):
    """The anatomy piece blender_anatomy.py left in the prepared .blend: skinned to the hips (its
    shape keys from the nearest body vertex too), its own UVs and edge-fade alpha kept."""
    src = bpy.data.objects.get("anatomy")
    if src is None:
        return
    me = src.data
    mw = src.matrix_world
    verts = [tuple(mw @ v.co) for v in me.vertices]
    faces = [tuple(p.vertices) for p in me.polygons]
    loop_uv = [tuple(d.uv) for d in me.uv_layers[0].data]
    fade = [c.color[3] for c in me.color_attributes["Col"].data]
    bpy.data.objects.remove(src, do_unlink=True)
    o = new_piece(B, "anatomy", "anatomy", verts, faces, R_HIPS, weights_from=[R_HIPS], loop_uv=loop_uv)
    col = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, a in enumerate(fade):
        col.data[i].color = (1.0, 1.0, 1.0, a)
    o.data.color_attributes.active_color = col


def build_stump(B):
    """A bandaged cap over the right upper arm where the lost forearm is hidden (regions 7, 9, 17)."""
    me = B.obj.data
    ring = set()
    for e in me.edges:
        a, b = e.vertices
        ra, rb = B.reg[a], B.reg[b]
        if {ra, rb} == {5, 17}:
            ring.add(a if ra == 5 else b)
    ring = list(ring)
    if not ring:
        print("STUMP no ring")
        return
    pts = B.co[ring]
    c = pts.mean(axis=0)
    sh, el = B.bone_head("RightArm"), B.bone_head("RightForeArm")
    axis = (el - sh) / np.linalg.norm(el - sh)
    rel = pts - c
    u = rel[0] / np.linalg.norm(rel[0])
    w = np.cross(axis, u)
    order = np.argsort(np.arctan2(rel @ w, rel @ u))
    verts = [tuple(pts[k] + (pts[k] - c) * 0.12 + axis * -0.012) for k in order]
    mid = [tuple(c + (pts[k] - c) * 0.75 + axis * 0.012) for k in order]
    verts += mid
    verts.append(tuple(c + axis * 0.022))
    m = len(order)
    faces = [(j, (j + 1) % m, m + (j + 1) % m, m + j) for j in range(m)]
    faces += [(m + j, m + (j + 1) % m, 2 * m) for j in range(m)]
    new_piece(B, "stump_r", "bandage", verts, faces, 5, rigid="RightArm")


def action_fcurves(act):
    """An action's F-curves, for both the old flat actions and Blender 4.4+ layered ones."""
    if hasattr(act, "layers") and len(act.layers):
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    out.extend(bag.fcurves)
        if out:
            return out
    return list(getattr(act, "fcurves", []))


## Clips that run on past what the game needs: last frame kept (30 fps).
TRIM = {"pickup": 165}


def trim(act, last):
    for fc in action_fcurves(act):
        pts = fc.keyframe_points
        for k in reversed(range(len(pts))):
            if pts[k].co[0] > last:
                pts.remove(pts[k], fast=True)
        fc.update()
    if hasattr(act, "use_frame_range"):
        act.use_frame_range = True
        act.frame_end = last


def pin_root(act, arm):
    """Hold the hips still across the ground in a one-off clip (keep the rise and fall): the game
    moves the body itself, a clip that walks it away would leave the model behind its collider.
    Pose locations are in the hips bone's rest frame: the vertical channel is the one whose axis
    points most nearly up in the world."""
    curves = [fc for fc in action_fcurves(act) if fc.data_path == 'pose.bones["mixamorig:Hips"].location']
    if len(curves) != 3:
        return 0.0
    curves.sort(key=lambda fc: fc.array_index)
    rest = (arm.matrix_world.to_3x3() @ arm.data.bones["mixamorig:Hips"].matrix_local.to_3x3())
    up = max(range(3), key=lambda i: abs(rest.col[i].normalized().z))
    drift = 0.0
    for i, fc in enumerate(curves):
        if i == up or not fc.keyframe_points:
            continue
        v0 = fc.keyframe_points[0].co[1]
        for k in fc.keyframe_points:
            drift = max(drift, abs(k.co[1] - v0))
            k.co[1] = v0
            k.handle_left[1] = v0
            k.handle_right[1] = v0
    return drift


def travel_speed(arm, action):
    """Ground speed of a clip that carries its own root motion: the hips' horizontal travel per second."""
    ad = arm.animation_data
    ad.action = action
    sc = bpy.context.scene
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    pb = arm.pose.bones["mixamorig:Hips"]
    sc.frame_set(f0)
    a = arm.matrix_world @ pb.head
    sc.frame_set(f1)
    b = arm.matrix_world @ pb.head
    ad.action = None
    return math.hypot(b.x - a.x, b.y - a.y) * sc.render.fps / max(1, f1 - f0)


def native_speed(arm, action, foot="LeftToeBase"):
    """Ground speed of an in-place loop: how fast the planted foot slides back, metres a second."""
    ad = arm.animation_data
    ad.action = action
    sc = bpy.context.scene
    f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
    pb = arm.pose.bones["mixamorig:" + foot]
    ys, zs = [], []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        p = arm.matrix_world @ pb.head
        ys.append(p.y)
        zs.append(p.z)
    ys, zs = np.array(ys), np.array(zs)
    low = zs < zs.min() + 0.015
    v = np.abs(np.diff(ys)) * sc.render.fps
    planted = low[:-1] & low[1:]
    ad.action = None
    return float(np.median(v[planted])) if planted.any() else 0.0


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    out, prepared, anim_dir = args[0], args[1], args[2]
    tex_dir = args[3] if len(args) > 3 else ""
    bpy.ops.wm.open_mainfile(filepath=prepared)
    arm = bpy.data.objects["Character"]
    body = bpy.data.objects["body"]
    eyes = bpy.data.objects["eyes"]
    arm.data.pose_position = "REST"
    idle = arm.animation_data.action if arm.animation_data else bpy.data.actions[0]
    B = Body(arm, body, eyes)
    build_clothes(B)
    if tex_dir:
        texture_garments(B, tex_dir)
    build_hair(B)
    build_stump(B)
    build_anatomy(B)
    hair_uv(B)
    arm.data.pose_position = "POSE"

    tracks = [("idle", idle)]
    for fn in sorted(os.listdir(anim_dir)):
        if not fn.endswith(".fbx") or fn == "idle.fbx":
            continue
        before, acts = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.fbx(filepath=os.path.join(anim_dir, fn), automatic_bone_orientation=False)
        new_acts = [a for a in bpy.data.actions if a not in acts]
        for o in [o for o in bpy.data.objects if o not in before]:
            bpy.data.objects.remove(o, do_unlink=True)
        tracks.append((fn[:-4], new_acts[0]))
    sc = bpy.context.scene
    sc.render.fps = 30
    for name, act in tracks:
        act.name = name
        if name == "sprint":                          # Mixamo leaves this one moving: measure it, then pin it
            print("SPEED sprint %.3f" % travel_speed(arm, act))
            print("PINNED sprint drift %.1f" % pin_root(act, arm))
        if name not in ("idle", "walk", "run", "sprint", "meditate"):
            print("PINNED %s drift %.1f" % (name, pin_root(act, arm)))
        if name in TRIM:
            trim(act, TRIM[name])
    by = dict(tracks)
    for name in ("walk", "run"):
        if name in by:
            print("SPEED %s %.3f" % (name, native_speed(arm, by[name])))
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for name, act in tracks:
        track = ad.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(act.frame_range[0]), act)
        strip.name = name
    print("CHARACTER tracks=%d meshes=%s" % (len(tracks), sorted(o.name for o in bpy.data.objects if o.type == "MESH")))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS", export_yup=True,
                              export_skins=True, export_animations=True, export_force_sampling=True, export_morph=True,
                              export_morph_normal=False, export_apply=False, export_attributes=False,
                              export_vertex_color="ACTIVE")
    print("EXPORTED", out)


if __name__ == "__main__":
    main()
