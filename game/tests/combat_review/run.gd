extends SceneTree
## Launcher for the combat-review probe (driver.gd; design/combat-review-2026-11-03.md section 8):
##   <console exe> --headless --fixed-fps 60 --path game -s res://tests/combat_review/run.gd -- --scenario=... (see driver.gd)
## tools/combat-review/batch.sh runs a list of configurations, one Godot at a time; compare.py makes the before -> after table.
func _initialize() -> void:
	var here: String = (get_script() as Script).resource_path.get_base_dir()
	var n := Node.new()
	n.set_script(load(here.path_join("driver.gd")))
	root.add_child(n)
