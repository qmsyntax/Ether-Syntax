class_name Light
extends RefCounted
## Light levels (Dark's rule, 2026-10-22 drafts): every spot is "lit", "dim" or "dark".
## The simplest honest version: a level has a base (balance.json "light": by game state, set on the
## level node as meta "light"); light sources make Lit circles (nodes in group "light_sources" with a
## `light_radius`: lamps; enemies that are Alight or Lit, through `light_radius()`; bright ground
## zones such as fire); dark ground (a GroundZone with `dark`) makes Dark, and a light source inside
## it wins where they overlap. Not built: the shadow behind every enemy and stone.


static func level_at(tree: SceneTree, pos: Vector3) -> String:
	if tree == null:
		return "dim"
	var p := Vector2(pos.x, pos.z)
	for node: Node in tree.get_nodes_in_group("light_sources"):
		var src := node as Node3D
		if src == null or not is_instance_valid(src):
			continue
		var r: float = float(src.call("light_radius")) if src.has_method("light_radius") else float(src.get("light_radius"))
		if r > 0.0 and Vector2(src.global_position.x, src.global_position.z).distance_to(p) <= r:
			return "lit"
	# a burning or Lit body is a light of its own
	for node: Node in tree.get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e != null and e.has_method("light_radius"):
			var er: float = float(e.call("light_radius"))
			if er > 0.0 and Vector2(e.global_position.x, e.global_position.z).distance_to(p) <= er:
				return "lit"
	for node: Node in tree.get_nodes_in_group("ground_zones"):
		if bool(node.get("bright")) and float(node.get("light_radius")) > 0.0 and bool(node.call("has_point", pos)):
			return "lit"
	for node: Node in tree.get_nodes_in_group("ground_zones"):
		if bool(node.get("dark")) and bool(node.call("has_point", pos)):
			return "dark"
	return base(tree)


## The level's own light, before any source or dark ground.
static func base(tree: SceneTree) -> String:
	var cfg: Dictionary = GameData.balance.get("light", {})
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("light_base"):
		return str(scene.call("light_base"))
	return str(cfg.get("default", "dim"))


static func is_dark(tree: SceneTree, pos: Vector3) -> bool:
	return level_at(tree, pos) == "dark"
