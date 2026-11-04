extends SceneTree
## Launcher: godot --headless --fixed-fps 60 --path game -s <scratchpad>/combat-review/run.gd -- --scenario=... (see driver.gd)
func _initialize() -> void:
	var here: String = (get_script() as Script).resource_path.get_base_dir()
	var n := Node.new()
	n.set_script(load(here.path_join("driver.gd")))
	root.add_child(n)
