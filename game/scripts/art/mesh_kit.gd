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


## Pads loft rows to all eight values and inserts `detail` - 1 smoothly interpolated rows
## between each pair (Catmull-Rom on every value), so a few hand-written sections give a
## rounded form.
static func refine(rows: Array, detail: int = 3) -> Array:
	var full: Array = []
	for row: Array in rows:
		var r: Array = [float(row[0]), float(row[1]), float(row[2]), float(row[3]) if row.size() > 3 else float(row[2])]
		for k: int in range(4, 8):
			r.append(float(row[k]) if row.size() > k else 0.0)
		full.append(r)
	if detail <= 1 or full.size() < 2:
		return full
	var out: Array = []
	var last: int = full.size() - 1
	for i: int in last:
		var p0: Array = full[maxi(i - 1, 0)]
		var p1: Array = full[i]
		var p2: Array = full[i + 1]
		var p3: Array = full[mini(i + 2, last)]
		for step: int in detail:
			var t: float = float(step) / float(detail)
			var r: Array = []
			for k: int in 8:
				var a: float = p1[k]
				var b: float = p2[k]
				var m1: float = (b - float(p0[k])) * 0.5
				var m2: float = (float(p3[k]) - a) * 0.5
				var t2: float = t * t
				var t3: float = t2 * t
				r.append((2.0 * t3 - 3.0 * t2 + 1.0) * a + (t3 - 2.0 * t2 + t) * m1 + (-2.0 * t3 + 3.0 * t2) * b + (t3 - t2) * m2)
			out.append(r)
	out.append(full[last])
	return out


## A skin over stacked cross-sections, for anatomy and tailored cloth. Each row is
## [y, rx, rz_front, rz_back, cx, cz, square, ripple] (trailing values optional): half-width,
## depth toward -Z and +Z, centre offset, corner squareness 0..1, and fold depth as a
## fraction of the radius (`ripple_n` folds round the ring). `from_deg`..`to_deg` (measured
## from +X toward +Z; -90 is the front) makes an open panel instead of a closed tube.
static func loft(rows: Array, sides: int = 20, ripple_n: int = 0, from_deg: float = 0.0, to_deg: float = 360.0, cap_first: bool = true, cap_last: bool = true) -> ArrayMesh:
	var closed: bool = to_deg - from_deg >= 359.9
	var rings: Array[PackedVector3Array] = []
	var count: int = sides if closed else sides + 1
	for row: Array in rows:
		var n: int = row.size()
		var y: float = row[0]
		var rx: float = row[1]
		var rzf: float = row[2]
		var rzb: float = row[3] if n > 3 else rzf
		var cx: float = row[4] if n > 4 else 0.0
		var cz: float = row[5] if n > 5 else 0.0
		var power: float = 1.0 - 0.5 * (float(row[6]) if n > 6 else 0.0)
		var fold: float = row[7] if n > 7 else 0.0
		var ring := PackedVector3Array()
		for j: int in count:
			var a: float = deg_to_rad(lerpf(from_deg, to_deg, float(j) / float(sides)))
			var c: float = cos(a)
			var s: float = sin(a)
			var k: float = 1.0 + (fold * cos(a * float(ripple_n)) if ripple_n > 0 else 0.0)
			var ex: float = signf(c) * pow(absf(c), power)
			var ez: float = signf(s) * pow(absf(s), power)
			ring.append(Vector3(cx + rx * ex * k, y, cz + (rzb if s > 0.0 else rzf) * ez * k))
		rings.append(ring)
	if closed:
		return stitch(rings, cap_first, cap_last)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring: PackedVector3Array in rings:
		verts.append_array(ring)
	for i: int in rings.size() - 1:
		for j: int in sides:
			var a0: int = i * count + j
			var b0: int = a0 + 1
			var c0: int = a0 + count
			var d0: int = b0 + count
			indices.append_array([a0, b0, c0, b0, d0, c0])
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
