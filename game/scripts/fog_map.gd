class_name FogMap
extends RefCounted
## What you have seen of a zone (Brent 2026-10-18: a minimap with fog of war). The zone is cut
## into square cells `cell` metres across; a cell is seen once you have stood within `radius` of
## it, and stays seen. It keeps an image the minimap draws over the map - opaque where you have
## not been - and saves as a short string per zone.

var cell := 4.0
var cols := 1
var rows := 1
var seen := PackedByteArray()
var image: Image
var texture: ImageTexture
var _dirty := false


func _init(zone_size: Vector2, cell_m: float = 4.0) -> void:
	cell = cell_m
	cols = maxi(1, ceili(zone_size.x / cell))
	rows = maxi(1, ceili(zone_size.y / cell))
	seen.resize(cols * rows)
	seen.fill(0)
	image = Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(image)


## Mark everything within `radius` metres of a map-frame point (x east, y south) as seen.
## Returns true if anything new was seen.
func reveal(x: float, y: float, radius: float) -> bool:
	var changed := false
	var c0: int = maxi(0, floori((x - radius) / cell))
	var c1: int = mini(cols - 1, floori((x + radius) / cell))
	var r0: int = maxi(0, floori((y - radius) / cell))
	var r1: int = mini(rows - 1, floori((y + radius) / cell))
	for r: int in range(r0, r1 + 1):
		for c: int in range(c0, c1 + 1):
			var i: int = r * cols + c
			if seen[i] != 0:
				continue
			var mid := Vector2((float(c) + 0.5) * cell, (float(r) + 0.5) * cell)
			if mid.distance_to(Vector2(x, y)) <= radius:
				seen[i] = 1
				image.set_pixel(c, r, Color(0, 0, 0, 0))
				changed = true
	if changed:
		_dirty = true
	return changed


## True if the cell holding this map-frame point has been seen.
func is_seen(x: float, y: float) -> bool:
	var c: int = clampi(floori(x / cell), 0, cols - 1)
	var r: int = clampi(floori(y / cell), 0, rows - 1)
	return seen[r * cols + c] != 0


## Share of the zone seen, 0 to 1.
func explored() -> float:
	var n := 0
	for b: int in seen:
		n += b
	return float(n) / float(seen.size())


## Push the image to the texture if anything changed since the last call.
func refresh_texture() -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


## "cols,rows:" then the cells, compressed. The size goes first so a map made for another
## zone shape is recognised and ignored without trying to unpack it.
func to_text() -> String:
	return "%d,%d:%s" % [cols, rows, Marshalls.raw_to_base64(seen.compress(FileAccess.COMPRESSION_DEFLATE))]


## Restore from to_text(). Anything that does not fit this zone is ignored.
func from_text(text: String) -> void:
	var parts: PackedStringArray = text.split(":", true, 1)
	if parts.size() != 2 or parts[0] != "%d,%d" % [cols, rows]:
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(parts[1]).decompress(cols * rows, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != cols * rows:
		return
	seen = raw
	for r: int in rows:
		for c: int in cols:
			image.set_pixel(c, r, Color(0, 0, 0, 0) if seen[r * cols + c] != 0 else Color(0, 0, 0, 1))
	_dirty = true
	refresh_texture()
