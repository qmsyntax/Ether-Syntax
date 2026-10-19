class_name SkillTreeScreen
extends UiScreen
## The skill tree (design/08): one tree per affinity you hold, roots at the top, capstone at the
## bottom, lines from what a skill needs. Each node is learned, ready to learn, open (its
## prerequisite is met but points or money are short) or locked. It can be looked at anywhere;
## the Learn and Drill buttons work only when it was opened by a trainer in town (`at_trainer`).

const NODE_SIZE := Vector2(176, 76)

var at_trainer := false
var affinity := ""
var selected := ""
var _view: TreeView


func _init(game_node: Node, trainer: bool = false) -> void:
	super(game_node)
	at_trainer = trainer


func backdrop() -> float:
	return 0.85


func close_actions() -> Array[String]:
	return ["skills", "settings"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var affs: Array = player.get("affinities")
	if affinity == "" or not affs.has(affinity):
		affinity = str(affs[0]) if not affs.is_empty() else ""
	var tree: Dictionary = GameData.skill_tree_of(affinity)
	if selected == "" or not tree.has(selected):
		selected = str(tree.keys()[0]) if not tree.is_empty() else ""

	var left: VBoxContainer = framed(root, 0.02, 0.04, 0.64, 0.775)
	left.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	left.add_child(head)
	var title := UiTheme.heading("Skill tree", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var pts := UiTheme.body("Skill points  %d" % int(player.get("skill_points")), 18, UiTheme.STAR)
	pts.name = "PointsLabel"
	pts.autowrap_mode = TextServer.AUTOWRAP_OFF
	pts.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(pts)
	var where: String = ("%s teaches here. Learning costs skill points and a fee." % str(GameData.town_folk("trainer").get("name", "The trainer"))) if at_trainer \
		else "Only a trainer in town can teach you. Points come as your star grows; scrolls teach anywhere."
	left.add_child(UiTheme.body(where, 14, UiTheme.TEXT_DIM))
	if affs.size() > 1:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		left.add_child(tabs)
		for a: Variant in affs:
			var label: String = str(GameData.affinity(str(a)).get("label", a))
			var b := UiWidgets.small_button(label, func() -> void:
				affinity = str(a)
				selected = ""
				rebuild())
			b.set_meta("affinity", str(a))
			if str(a) == affinity:
				b.add_theme_color_override("font_color", GameData.affinity_color(str(a)).lightened(0.35))
				b.add_theme_stylebox_override("normal", UiTheme.box(Color("2a241d"), GameData.affinity_color(str(a)), 2, 4, 10))
			tabs.add_child(b)
	left.add_child(UiTheme.rule())
	_view = TreeView.new(self, tree)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_view)

	var right: VBoxContainer = framed(root, 0.655, 0.04, 0.985, 0.775)
	right.add_theme_constant_override("separation", 7)
	_detail(right)


## learned | ready | open | locked
func node_state(id: String) -> String:
	if bool(player.call("knows", id)):
		return "learned"
	if not bool(player.call("skill_unlocked", id)):
		return "locked"
	return "ready" if str(player.call("cannot_train_reason", id)) == "" else "open"


func select(id: String) -> void:
	selected = id
	rebuild()


func _detail(box: VBoxContainer) -> void:
	if selected == "":
		box.add_child(UiTheme.body("No tree for this affinity.", 15, UiTheme.TEXT_FAINT))
		return
	var ab: Dictionary = GameData.ability(selected)
	var col: Color = GameData.affinity_color(affinity).lightened(0.3)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), col, 52.0))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_col)
	name_col.add_child(UiTheme.heading(str(ab.get("name", selected)), 22))
	name_col.add_child(UiTheme.body("\"%s\"" % str(ab.get("verse", "")), 13, UiTheme.STAR))
	if str(ab.get("summary", "")) != "":
		box.add_child(UiTheme.body(str(ab["summary"]), 14))
	box.add_child(UiTheme.rule())
	var node: Dictionary = GameData.skill_node(selected)
	var cost: Dictionary = player.call("skill_cost", selected)
	box.add_child(UiWidgets.stat_row("Tier", str(int(node.get("tier", 1)))))
	box.add_child(UiWidgets.stat_row("Essence cost", "%d" % int(round(float(ab.get("cost", 0.0))))))
	var needs: Array = node.get("requires", [])
	if not needs.is_empty():
		var names: Array[String] = []
		for id: Variant in needs:
			names.append(str(GameData.ability(str(id)).get("name", id)))
		box.add_child(UiWidgets.stat_row("Needs", " or ".join(names)))
	var state: String = node_state(selected)
	if state == "learned":
		box.add_child(UiTheme.body("You know this skill.", 15, UiTheme.GOOD))
		var drill: Dictionary = GameData.skill_tree.get("drill", {})
		var why_d: String = str(player.call("cannot_drill_reason", selected))
		var d := UiWidgets.service_button("Drill it", "+%d%% toward its next stage. The stage itself still needs a bound construct." % int(float(drill.get("progress", 0.0))),
			"%d pt  $%d" % [int(drill.get("points", 1)), int(drill.get("price", 0))], func() -> void:
				var why: String = game.call("drill_skill", selected)
				if why != "":
					player.call("note", why)
				rebuild(), at_trainer and why_d == "")
		d.name = "DrillButton"
		box.add_child(d)
		if at_trainer and why_d != "":
			box.add_child(UiTheme.body(why_d, 13, UiTheme.BAD))
	else:
		box.add_child(UiWidgets.stat_row("To learn", "%d point%s and $%d" % [int(cost["points"]), "" if int(cost["points"]) == 1 else "s", int(cost["price"])], UiTheme.GOLD))
		var why_l: String = str(player.call("cannot_train_reason", selected))
		var l := UiWidgets.service_button("Learn it", "From %s." % str(GameData.town_folk("trainer").get("name", "the trainer")) if at_trainer else "Only at a trainer in town.",
			"", func() -> void:
				var why: String = game.call("train_skill", selected)
				if why != "":
					player.call("note", why)
				rebuild(), at_trainer and why_l == "")
		l.name = "LearnButton"
		box.add_child(l)
		if why_l != "":
			box.add_child(UiTheme.body(why_l, 13, UiTheme.BAD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(int(player.get("money"))), UiTheme.GOLD))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	foot.add_child(UiWidgets.small_button("Done  (%s)" % Keybinds.binding_text("skills"), func() -> void: game.call("close_screen")))


## The drawn tree: node buttons on tiers, lines from each node to what it needs.
class TreeView extends Control:
	var screen: Node
	var tree: Dictionary
	var buttons: Dictionary = {}          # ability id -> Button

	func _init(owner_screen: Node, nodes: Dictionary) -> void:
		screen = owner_screen
		tree = nodes
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(560, 330)
		for id: String in tree:
			var b := Button.new()
			b.name = "Node_" + id
			b.set_meta("skill", id)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = SkillTreeScreen.NODE_SIZE
			b.size = SkillTreeScreen.NODE_SIZE
			b.clip_text = true
			b.pressed.connect(func() -> void: screen.call("select", id))
			add_child(b)
			buttons[id] = b
		resized.connect(_layout)

	func _ready() -> void:
		_style()
		_layout()

	func _centre_of(id: String) -> Vector2:
		var node: Dictionary = tree[id]
		var tiers: float = 3.0
		var col: float = float(node.get("col", 0.0))
		var x: float = size.x * (col + 0.5) / 3.0
		var y: float = size.y * (float(int(node.get("tier", 1))) - 0.5) / tiers
		return Vector2(x, y)

	func _layout() -> void:
		for id: String in buttons:
			var b: Button = buttons[id]
			b.position = _centre_of(id) - SkillTreeScreen.NODE_SIZE * 0.5
			b.size = SkillTreeScreen.NODE_SIZE
		queue_redraw()

	func _style() -> void:
		var aff_col: Color = GameData.affinity_color(str(screen.get("affinity")))
		for id: String in buttons:
			var b: Button = buttons[id]
			var state: String = screen.call("node_state", id)
			var cost: Dictionary = (screen.get("player") as Node).call("skill_cost", id)
			var ab: Dictionary = GameData.ability(id)
			var tag: String = {"learned": "known", "ready": "%d pt  $%d" % [int(cost["points"]), int(cost["price"])],
				"open": "%d pt  $%d" % [int(cost["points"]), int(cost["price"])], "locked": "locked"}[state]
			b.text = "%s\n%s" % [str(ab.get("name", id)), tag]
			var border: Color = UiTheme.GOLD if state == "learned" else (aff_col if state == "ready" else (aff_col.darkened(0.45) if state == "open" else UiTheme.BRONZE_DIM))
			var bg: Color = Color("3a3024") if state == "learned" else (UiTheme.PANEL_HI if state != "locked" else UiTheme.INSET)
			var width: int = 3 if id == str(screen.get("selected")) else (2 if state == "learned" or state == "ready" else 1)
			for s: String in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(s, UiTheme.box(bg.lightened(0.06) if s == "hover" else bg, border, width, 6, 8))
			b.add_theme_color_override("font_color", UiTheme.GOLD if state == "learned" else (UiTheme.TEXT if state != "locked" else UiTheme.TEXT_FAINT))
			b.add_theme_color_override("font_hover_color", UiTheme.TEXT)
			b.add_theme_font_size_override("font_size", 15)

	func _draw() -> void:
		var player: Node = screen.get("player")
		for id: String in tree:
			for need: Variant in (tree[id] as Dictionary).get("requires", []):
				if not tree.has(str(need)):
					continue
				var from: Vector2 = _centre_of(str(need)) + Vector2(0, SkillTreeScreen.NODE_SIZE.y * 0.5)
				var to: Vector2 = _centre_of(id) - Vector2(0, SkillTreeScreen.NODE_SIZE.y * 0.5)
				var lit: bool = bool(player.call("knows", str(need)))
				draw_line(from, to, UiTheme.GOLD if lit else UiTheme.BRONZE_DIM, 3.0 if lit else 2.0, true)
