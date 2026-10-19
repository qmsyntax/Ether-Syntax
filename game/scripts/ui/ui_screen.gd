class_name UiScreen
extends Control
## Base for the menu screens. A screen holds a reference to the game (main.gd) and calls its
## public methods; it owns no game state. `rebuild()` throws the contents away and builds them
## again from the current state - simple, and screens are small.

## What a menu screen hides of the HUD: everything but the dock (see hud_hides).
const HUD_MENU: Array[String] = ["plate", "hints", "log", "tags", "buffs", "tracker"]

var game: Node
var player: Node
var _content: Control


func _init(game_node: Node) -> void:
	game = game_node
	player = game_node.get("player")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP if blocks_clicks() else Control.MOUSE_FILTER_IGNORE
	rebuild()


## Override: actions that close this screen while the game is paused under it.
func close_actions() -> Array[String]:
	return []


func _unhandled_input(event: InputEvent) -> void:
	# When the tree is not paused the game script handles these keys itself.
	if not get_tree().paused or event.is_echo():
		return
	for action: String in close_actions():
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			game.call("close_screen")
			return


## Override: whether the screen swallows clicks on its empty areas.
func blocks_clicks() -> bool:
	return true


## Override: which parts of the HUD to hide while this screen is open, so a menu never sits on
## top of something it repeats: "plate", "hints", "log", "tags", "buffs", "tracker". The dock
## (orbs and skill slots) always stays.
func hud_hides() -> Array[String]:
	return []


## Override: darkness of the backdrop behind the panel (0 = none).
func backdrop() -> float:
	return 0.6


## Override: build the screen into `root` (a full-rect container).
func build(_root: Control) -> void:
	pass


func rebuild() -> void:
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	if backdrop() > 0.0:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.015, 0.01, backdrop())
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(dim)
	build(_content)


## A framed panel placed by anchors (fractions of the screen) with a vertical layout inside.
func framed(root: Control, left: float, top: float, right: float, bottom: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


## A scrolling vertical list that fills the remaining height of its parent.
func scroller(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list
