class_name MeshKit
extends RefCounted
## Procedural mesh helpers for the art library: shapes Godot's primitives cannot make.
## Every function returns an ArrayMesh with one indexed surface (vertices + smooth normals).
## ModelRig.add_shape() bakes them like any primitive; pass `flat = true` there for facets.


## Surface of revolution around Y. `profile` holds (radius, y) pairs from bottom to top.
## `ripple_n` > 0 adds that many vertical folds: the radius is modulated by `ripple_bottom`
## (as a fraction) at the first ring fading to `ripple_top` at the last. `hem` drops every
## other vertex of the bottom ring by that many metres (ragged cloth). Open ends with a
## radius are capped.
static func lathe(profile: PackedVector2Array, sides: int = 12, ripple_n: int = 0, ripple_bottom: float = 0.0, ripple_top: float = 0.0, hem: float = 0.0) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	var last: int = profile.size() - 1
	for i: int in profile.size():
		var ring := PackedVector3Array()
		var t: float = float(i) / float(maxi(last, 1))
		var amp: float = lerpf(ripple_bottom, ripple_top, t)
		for j: int in sides:
			var a: float = TAU * float(j) / float(sides)
			var rad: float = profile[i].x
			if ripple_n > 0:
				rad *= 1.0 + amp * cos(a * float(ripple_n))
			var y: float = profile[i].y
			if i == 0 and hem != 0.0 and j % 2 == 1:
				y -= hem
			ring.append(Vector3(cos(a) * rad, y, sin(a) * rad))
		rings.append(ring)
	return stitch(rings, profile[0].x > 0.0005, profile[last].x > 0.0005)


## A box whose corners and edges are chamfered and whose top can be narrower or wider than
## its base. `bevel` is in metres; `top` scales the top face in X and Z (1 = straight sides).
## Centred on the origin like BoxMesh. Looks best flat-shaded.
static func bevel_box(size: Vector3, bevel: float = 0.03, top: Vector2 = Vector2.ONE) -> ArrayMesh:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var b: float = minf(bevel, minf(hx, minf(hy, hz)) * 0.9)
	var rows: Array[Vector3] = [
		Vector3(hx - b, -hy, hz - b),
		Vector3(hx, -hy + b, hz),
		Vector3(hx * top.x, hy - b, hz * top.y),
		Vector3(hx * top.x - b, hy, hz * top.y - b),
	]
	var rings: Array[PackedVector3Array] = []
	for row: Vector3 in rows:
		rings.append(_octagon(maxf(row.x, 0.001), row.y, maxf(row.z, 0.001), b * 0.7))
	return stitch(rings, true, true)


## A tube swept along `path` with a radius per point (0 closes it to a point). `flatten`
## squashes the cross-section (1 = round, 0.3 = ribbon-like); `wide` is the direction the
## ribbon stays wide in at the start of the path (default: sideways to the path and -Z).
static func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int = 8, flatten: float = 1.0, wide: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	var count: int = path.size()
	var side_axis := Vector3.RIGHT
	for i: int in count:
		var tangent: Vector3 = (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
		if i == 0:
			side_axis = wide if wide != Vector3.ZERO else tangent.cross(Vector3.FORWARD)
			if (side_axis - tangent * side_axis.dot(tangent)).length() < 0.01:
				side_axis = tangent.cross(Vector3.RIGHT)
		side_axis = (side_axis - tangent * side_axis.dot(tangent)).normalized()
		var other: Vector3 = side_axis.cross(tangent).normalized()
		var ring := PackedVector3Array()
		var rad: float = radii[mini(i, radii.size() - 1)]
		for j: int in sides:
			var a: float = TAU * float(j) / float(sides)
			ring.append(path[i] + (side_axis * cos(a) + other * sin(a) * flatten) * rad)
		rings.append(ring)
	return stitch(rings, radii[0] > 0.0005, radii[mini(count - 1, radii.size() - 1)] > 0.0005)


## A circular arc of tube in the XY plane (centre at the origin), from `from_deg` to `to_deg`
## measured from +X toward +Y. `tip` tapers both ends to that fraction of `thick`.
static func arc(radius: float, thick: float, from_deg: float, to_deg: float, steps: int = 12, sides: int = 6, tip: float = 1.0) -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, t))
		path.append(Vector3(cos(a) * radius, sin(a) * radius, 0.0))
		radii.append(thick * lerpf(tip, 1.0, sin(t * PI)))
	return tube(path, radii, sides)


## A flat polygon in the XY plane given thickness along Z (centred). Handles concave
## outlines. Always faceted.
static func extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var h: float = depth * 0.5
	for face: int in 2:
		var z: float = h if face == 0 else -h
		var n := Vector3(0, 0, 1.0 if face == 0 else -1.0)
		var base: int = verts.size()
		for p: Vector2 in outline:
			verts.append(Vector3(p.x, p.y, z))
			normals.append(n)
		for k: int in range(0, tris.size(), 3):
			var a: int = base + tris[k]
			var b: int = base + tris[k + 1]
			var c: int = base + tris[k + 2]
			if _face_normal(verts[a], verts[b], verts[c]).dot(n) < 0.0:
				indices.append_array([a, c, b])
			else:
				indices.append_array([a, b, c])
	var area: float = 0.0
	for i: int in outline.size():
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[(i + 1) % outline.size()]
		area += p.x * q.y - q.x * p.y
	var sign_out: float = 1.0 if area > 0.0 else -1.0
	for i: int in outline.size():
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[(i + 1) % outline.size()]
		var edge: Vector2 = q - p
		var n := Vector3(edge.y, -edge.x, 0.0).normalized() * sign_out
		var base: int = verts.size()
		verts.append_array([Vector3(p.x, p.y, h), Vector3(q.x, q.y, h), Vector3(q.x, q.y, -h), Vector3(p.x, p.y, -h)])
		normals.append_array([n, n, n, n])
		if _face_normal(verts[base], verts[base + 1], verts[base + 2]).dot(n) < 0.0:
			indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		else:
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return _commit(verts, normals, indices)


## A two-sided hanging cloth: top edge along X at y = 0, falling to y = -length. Width goes
## from `width_top` to `width_bottom`; `folds` vertical ripples of depth `fold_depth` grow
## toward the hem; `billow` pushes the hem back along +Z; `ragged` notches the bottom edge.
static func sheet(width_top: float, width_bottom: float, length: float, folds: float = 2.0, fold_depth: float = 0.05, billow: float = 0.0, ragged: float = 0.0, cols: int = 10, rows: int = 6) -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for side: int in 2:
		var base: int = verts.size()
		for r: int in rows + 1:
			var v: float = float(r) / float(rows)
			var w: float = lerpf(width_top, width_bottom, v)
			for c: int in cols + 1:
				var u: float = float(c) / float(cols)
				var y: float = -length * v
				if r == rows and ragged != 0.0 and c % 2 == 1:
					y += ragged
				var z: float = fold_depth * v * cos(u * folds * TAU) + billow * v * v
				verts.append(Vector3((u - 0.5) * w, y, z))
		for r: int in rows:
			for c: int in cols:
				var i0: int = base + r * (cols + 1) + c
				var i1: int = i0 + 1
				var i2: int = i0 + cols + 1
				var i3: int = i2 + 1
				if side == 0:
					indices.append_array([i0, i1, i2, i1, i3, i2])
				else:
					indices.append_array([i0, i2, i1, i1, i2, i3])
	return _commit(verts, _smooth_normals(verts, indices), indices)


## Joins consecutive rings (each the same vertex count, wound from +X toward +Z) into a
## closed skin with smooth normals, optionally capping the first and last ring.
static func stitch(rings: Array[PackedVector3Array], cap_first: bool = true, cap_last: bool = true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var n: int = rings[0].size()
	for ring: PackedVector3Array in rings:
		verts.append_array(ring)
	for i: int in rings.size() - 1:
		for j: int in n:
			var a: int = i * n + j
			var b: int = i * n + (j + 1) % n
			var c: int = a + n
			var d: int = b + n
			indices.append_array([a, b, c, b, d, c])
	var normals: PackedVector3Array = _smooth_normals(verts, indices)
	if cap_first:
		_cap(verts, normals, indices, rings[0], false)
	if cap_last:
		_cap(verts, normals, indices, rings[rings.size() - 1], true)
	return _commit(verts, normals, indices)


static func _cap(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, ring: PackedVector3Array, top: bool) -> void:
	var centre := Vector3.ZERO
	for p: Vector3 in ring:
		centre += p
	centre /= float(ring.size())
	var n := Vector3.ZERO
	for j: int in ring.size():
		n += (ring[(j + 1) % ring.size()] - centre).cross(ring[j] - centre)
	n = n.normalized() * (1.0 if top else -1.0)
	var base: int = verts.size()
	verts.append(centre)
	normals.append(n)
	for p: Vector3 in ring:
		verts.append(p)
		normals.append(n)
	for j: int in ring.size():
		var a: int = base + 1 + j
		var b: int = base + 1 + (j + 1) % ring.size()
		if top:
			indices.append_array([base, a, b])
		else:
			indices.append_array([base, b, a])


static func _octagon(hx: float, y: float, hz: float, chamfer: float) -> PackedVector3Array:
	var c: float = minf(chamfer, minf(hx, hz) * 0.8)
	return PackedVector3Array([
		Vector3(hx, y, -hz + c), Vector3(hx, y, hz - c),
		Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz),
		Vector3(-hx, y, hz - c), Vector3(-hx, y, -hz + c),
		Vector3(-hx + c, y, -hz), Vector3(hx - c, y, -hz),
	])


static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a)


static func _smooth_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k: int in range(0, indices.size(), 3):
		var a: int = indices[k]
		var b: int = indices[k + 1]
		var c: int = indices[k + 2]
		var n: Vector3 = _face_normal(verts[a], verts[b], verts[c])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i: int in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0 else Vector3.UP
	return normals


static func _commit(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
