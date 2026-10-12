extends UiScreen
## A plain announcement with one button (used for a hardcore death).

var _title := ""
var _text := ""
var _button := ""
var _action: Callable


func _init(game_node: Node, title: String, text: String, button: String, action: Callable) -> void:
	super(game_node)
	_title = title
	_text = text
	_button = button
	_action = action


func backdrop() -> float:
	return 0.8


func build(root: Control) -> void:
	var box: VBoxContainer = framed(root, 0.32, 0.3, 0.68, 0.6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	var t := UiTheme.heading(_title, 44, UiTheme.BAD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := UiTheme.body(_text, 18, UiTheme.TEXT_DIM)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UiWidgets.small_button(_button, _action))
