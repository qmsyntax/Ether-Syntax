class_name MainLevel
extends RefCounted
## One kind of level main.gd runs - the town, an overland zone, the assault passage, the practice arena - and
## what it does while main.state is its own (MainStates says which state is whose). The node calls `tick` from
## _process, `handle_input` from _unhandled_input (after the keys every state shares) and `where` for the HUD
## and the game menu. A controller also builds its level (through LevelFactory) and holds that level's rules.
## State the rest of the game reads stays on the node (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


## Each frame while main.state is this level's (Main._process, at the same point the old match ran it).
func tick(_delta: float) -> void:
	pass


## An input event that the shared keys left alone, while main.state is this level's (Main._unhandled_input).
func handle_input(_event: InputEvent) -> void:
	pass


## Where the character is, for the HUD and the game menu's header.
func where() -> String:
	return ""
