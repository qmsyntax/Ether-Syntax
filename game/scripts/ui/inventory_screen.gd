extends UiScreen
## Inventory and character sheet in one, laid out as a paper doll: who you are and what your
## gear adds up to on the left, the figure in the middle with a slot for every piece down either
## side of it, and the pack as a grid on the right. The right panel's second tab holds your
## abilities and the constructs waiting to be bound into them - this is also where you choose
## WHICH ability a construct goes into (the Bind key only takes the first match).

const SLOT_LABELS := {"weapon": "Main hand", "offhand": "Off hand", "ranged": "Ranged", "head": "Head", "body": "Body", "hands": "Hands",
	"feet": "Feet", "back": "Back", "belt": "Belt", "satellite": "Satellite", "trinket": "Trinket", "trinket2": "Trinket"}
## The dim glyph an empty slot shows.
const SLOT_GHOSTS := {"weapon": "blade", "offhand": "slate", "ranged": "sling", "head": "hood", "body": "coat", "hands": "glove",
	"feet": "boot", "back": "pack", "belt": "belt", "satellite": "mote", "trinket": "charm", "trinket2": "charm"}
const SLOT_HINTS := {"weapon": "Bare fists. A weapon goes here.", "offhand": "Nothing in your other hand. A slate goes here.",
	"ranged": "Nothing to shoot with. A sling or bow goes here.", "head": "Bare-headed. A hood or cap goes here.",
	"body": "Nothing between you and a blade. Armour goes here.", "hands": "Bare hands. Gloves or bracers go here.",
	"feet": "Barefoot. Boots go here.", "back": "A backpack goes here.", "belt": "A belt goes here.",
	"satellite": "A satellite goes here - buy one from the merchant.", "trinket": "A charm or coil goes here.",
	"trinket2": "A second charm or coil goes here."}
## The two columns either side of the figure, top to bottom.
const LEFT_SLOTS: Array[String] = ["head", "body", "hands", "belt", "feet", "back"]
const RIGHT_SLOTS: Array[String] = ["weapon", "offhand", "ranged", "satellite", "trinket", "trinket2"]
const BAG_COLUMNS := 7
const BAG_MIN_CELLS := 35
const CELL_PX := 62.0
const GHOST := Color(0.38, 0.35, 0.3)
## What a comparison says about each stat: label, how to print it, and whether more is better.
const STAT_INFO := {
	"melee_damage_mult": ["Strike damage", "mult", true],
	"melee_cooldown_mult": ["Time between strikes", "mult", false],
	"melee_range_bonus": ["Reach", "m", true],
	"armour": ["Armour", "pct", true],
	"ranged_damage_mult": ["Shot damage", "mult", true],
	"ranged_interval": ["Time between shots", "s", false],
	"ranged_interval_mult": ["Time between shots", "mult", false],
	"ranged_range": ["Range", "m", true],
	"carry_capacity": ["Carry", "kg", true],
	"satellite_rate": ["Essence", "rate", true],
	"cost_mult": ["Ability cost", "mult", false],
	"reflux_shed_mult": ["Reflux shedding", "mult", true],
}

var _tab := "pack"
var _figure: FigureView
var _figure_weapon := "-"
## What the panel under the pack describes: the last thing the cursor was over. A slot name
## means "the thing worn there" (or the empty slot itself when the id is blank).
var _inspect_id := ""
var _inspect_slot := ""
var _inspect_box: VBoxContainer


func backdrop() -> float:
	return 0.65


func close_actions() -> Array[String]:
	return ["inventory", "settings"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var inv: Inventory = player.get("inventory")
	_inspect_box = null
	_settle_inspect(inv)
	_build_sheet(framed(root, 0.03, 0.05, 0.235, 0.775), inv)
	_build_doll(framed(root, 0.245, 0.05, 0.605, 0.775), inv)
	var right: VBoxContainer = framed(root, 0.615, 0.05, 0.97, 0.775)
	_build_tabs(right)
	if _tab == "soul":
		_build_soul(right)
	else:
		_build_bag(right, inv)


# --- the sheet: who you are and what the gear adds up to -----------------------------------
# Every number here is read from the player; nothing is worked out a second time.

func _build_sheet(box: VBoxContainer, inv: Inventory) -> void:
	box.add_theme_constant_override("separation", 6)
	var who: String = str(player.get("char_name"))
	box.add_child(UiTheme.heading(who if who != "" else "Nameless", 26))
	var talent: Dictionary = player.get("talent")
	if not talent.is_empty():
		box.add_child(UiTheme.body(str(talent.get("name", "")), 14, UiTheme.STAR))
	var held: Array[String] = []
	for aff: String in player.get("affinities"):
		held.append(str(GameData.affinity(aff).get("label", aff)))
	if not held.is_empty():
		box.add_child(UiTheme.body(", ".join(held), 13, UiTheme.TEXT_DIM))

	box.add_child(UiTheme.section("Body"))
	var star_pct: Array = player.get("star_pct")
	box.add_child(UiWidgets.stat_row("Stars", str(int(player.get("stars"))), UiTheme.STAR))
	if not star_pct.is_empty():
		box.add_child(UiWidgets.stat_row("Newest star", "%d%% grown" % int(float(star_pct.back()))))
	var body: Body = player.get("body")
	box.add_child(UiWidgets.stat_row("Health", "%d / %d" % [int(ceil(body.total())), int(ceil(body.total_max()))],
		UiTheme.BAD if body.total() < body.total_max() * 0.35 else UiTheme.TEXT))
	if not body.wounds.is_empty():
		box.add_child(UiWidgets.stat_row("Wounds", str(body.wounds.size()), UiTheme.BAD))
	box.add_child(UiWidgets.stat_row("Armour", "%d%% off every hit" % int(float(player.call("armour")))))
	box.add_child(UiTheme.section("Combat"))

	var arm_lost: bool = bool(player.get("arm_right_lost"))
	var strike: float = float(player.call("strike_damage")) * (GameData.num("player", "off_hand_factor") if arm_lost else 1.0)
	box.add_child(UiWidgets.stat_row("Strike damage", str(int(round(strike))), UiTheme.BAD if arm_lost else UiTheme.TEXT))
	box.add_child(UiWidgets.stat_row("Reach", "%.1f m" % float(player.call("reach_now"))))
	if (player.call("ranged_weapon") as Dictionary).is_empty():
		box.add_child(UiWidgets.stat_row("Ranged damage", "none", UiTheme.TEXT_FAINT))
	else:
		box.add_child(UiWidgets.stat_row("Ranged damage", str(int(round(float(player.call("ranged_damage"))))), UiTheme.BAD if arm_lost else UiTheme.TEXT))
		box.add_child(UiWidgets.stat_row("Time between shots", "%.2f s" % float(player.call("ranged_interval"))))
	box.add_child(UiTheme.section("Soul"))

	var rate: float = float(player.get("satellite_rate"))
	box.add_child(UiWidgets.stat_row("Essence regeneration", ("+%s / s" % String.num(rate, 1)) if rate > 0.0 else "none"))
	var cost: float = inv.stat("cost_mult", true)
	if not is_equal_approx(cost, 1.0):
		box.add_child(UiWidgets.stat_row("Ability cost", "%+d%%" % int(round((cost - 1.0) * 100.0)), UiTheme.GOOD if cost < 1.0 else UiTheme.BAD))
	var shed: float = inv.stat("reflux_shed_mult", true)
	if not is_equal_approx(shed, 1.0):
		box.add_child(UiWidgets.stat_row("Reflux shedding", "%+d%%" % int(round((shed - 1.0) * 100.0)), UiTheme.GOOD if shed > 1.0 else UiTheme.BAD))
	box.add_child(UiTheme.section("Load"))

	var w: float = inv.weight()
	var cap: float = maxf(1.0, inv.capacity())
	box.add_child(UiWidgets.stat_row("Carried", "%d / %d kg" % [int(w), int(cap)], UiTheme.BAD if w > cap * 0.9 else UiTheme.TEXT))
	box.add_child(UiWidgets.stat_row("Purse", UiTheme.money_text(int(player.get("money"))), UiTheme.BAD if int(player.get("money")) < 0 else UiTheme.GOLD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("inventory"), func() -> void: game.call("close_screen")))


# --- the doll: the figure and a slot for every piece ------------------------------------------
# Three ways to equip, so nobody has to hunt for it: click the item, right-click it, or drag it
# onto a slot (or onto the figure). Slots that would accept the item being dragged light up.
# Click something you are wearing to take it off.

func _build_doll(box: VBoxContainer, inv: Inventory) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_slot_column(LEFT_SLOTS, inv))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	row.add_child(mid)
	var alcove := PanelContainer.new()
	alcove.size_flags_vertical = Control.SIZE_EXPAND_FILL
	alcove.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.INSET, UiTheme.BRONZE_DIM, 1, 4, 2))
	mid.add_child(alcove)
	# The figure outlives a rebuild, so equipping something does not blink it or lose its turn.
	if _figure == null:
		_figure = FigureView.new()
		_figure.show_look(player.get("look"))
		_figure.set_drag_forwarding(Callable(), _figure_can_drop, _figure_drop)
	elif _figure.get_parent() != null:
		_figure.get_parent().remove_child(_figure)
	alcove.add_child(_figure)
	_dress_figure(inv)
	var hint := UiTheme.body("drag to turn  -  click a worn piece to take it off", 12, UiTheme.TEXT_FAINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(hint)

	row.add_child(_slot_column(RIGHT_SLOTS, inv))


func _slot_column(slots: Array[String], inv: Inventory) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	for slot: String in slots:
		col.add_child(SlotPanel.new(self, slot, inv))
	return col


## Put on the figure what the model can show: the weapon in hand, and a missing arm.
func _dress_figure(inv: Inventory) -> void:
	var rig: ModelRig = _figure.rig()
	if rig == null:
		return
	if rig.has_method("set_outfit"):
		rig.call("set_outfit", inv.equipped)
	var id: String = str(inv.equipped.get("weapon", ""))
	if id != _figure_weapon:
		_figure_weapon = id
		rig.set_weapon(Models.weapon(id) if id != "" else null)
	rig.set_part_visible("arm_right", not bool(player.get("arm_right_lost")))


func _figure_can_drop(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("item")


func _figure_drop(_at: Vector2, data: Variant) -> void:
	equip_item(str((data as Dictionary)["item"]))


## Equip an item from the pack - into `into`, or wherever it fits - and say why not if it fails.
## A field kit opens its crafting instead; a crafting tool or material only says what it is for.
func equip_item(id: String, into: String = "") -> void:
	var kind: String = str(GameData.item(id).get("kind", ""))
	if kind == "kit":
		game.call("open_field_kit", id)
		return
	if kind == "tool" or kind == "material":
		player.call("note", "%s is for crafting: a tool goes back to your hand after each combine, a material goes into one." % str(GameData.item(id).get("name", id)))
		return
	if kind == "consumable":
		# using it: a field dressing binds a cut, out of a fight
		var said: String = player.call("use_consumable", id)
		if said != "":
			player.call("note", said)
		game.call("save_now")
		rebuild()
		return
	if str(GameData.item(id).get("kind", "")) == "scroll":
		# reading it: the skill is yours and the scroll is gone
		var why: String = player.call("read_scroll", id)
		if why != "":
			player.call("note", why)
		game.call("save_now")
		rebuild()
		return
	var inv: Inventory = player.get("inventory")
	var result: String = inv.equip(id, into)
	if result == "equipped":
		player.call("note", "Equipped %s." % str(GameData.item(id).get("name", id)))
	else:
		player.call("note", "Cannot equip that: %s." % result)
	player.call("refresh_gear")
	game.call("save_now")
	rebuild()


func unequip_slot(slot: String) -> void:
	var inv: Inventory = player.get("inventory")
	var result: String = inv.unequip(slot)
	if result != "unequipped":
		player.call("note", "Cannot take that off: %s." % result)
	player.call("refresh_gear")
	game.call("save_now")
	rebuild()


## One equipment slot: its name, the icon of what is in it (a dim ghost when empty) and the
## item's name. Accepts a dragged item that fits; a click takes off what is there.
class SlotPanel extends PanelContainer:
	var screen: Control
	var slot := ""
	var worn_id := ""
	var _lit := false

	func _init(owner_screen: Control, slot_name: String, inv: Inventory) -> void:
		screen = owner_screen
		slot = slot_name
		worn_id = str(inv.equipped.get(slot, ""))
		custom_minimum_size = Vector2(128, 84)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		if worn_id != "":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style(false)
		var def: Dictionary = GameData.item(worn_id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)
		col.add_child(_line(str(SLOT_LABELS[slot]).to_upper(), UiTheme.FS_CAPTION, UiTheme.TEXT_FAINT))
		var icon := UiWidgets.Icon.new(UiDraw.item_icon(def) if worn_id != "" else str(SLOT_GHOSTS[slot]), UiTheme.GOLD if worn_id != "" else GHOST, 44.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(icon)
		# a weapon in an arm that is not there does nothing: say so in the one place it shows
		var useless: bool = slot == "weapon" and worn_id != "" and bool((screen.get("player") as Node).get("arm_right_lost"))
		col.add_child(_line(str(def.get("name", worn_id)) if worn_id != "" else "empty", 13,
			UiTheme.BAD if useless else (UiTheme.TEXT if worn_id != "" else GHOST)))
		mouse_entered.connect(func() -> void: screen.call("show_item", worn_id, slot))

	## One centred line that is cut short rather than allowed to widen the slot.
	func _line(text: String, px: int, color: Color) -> Label:
		var l := UiTheme.body(text, px, color)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _style(lit: bool) -> void:
		_lit = lit
		add_theme_stylebox_override("panel", UiTheme.box(Color("2f2a1c") if lit else Color(UiTheme.PANEL_HI, 0.85), UiTheme.GOLD if lit else UiTheme.BRONZE_DIM, 2 if lit else 1, 3, 5))

	func _gui_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and worn_id != "":
			accept_event()
			screen.call("unequip_slot", slot)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok: bool = typeof(data) == TYPE_DICTIONARY and str(GameData.item(str((data as Dictionary).get("item", ""))).get("slot", "")) == Inventory.slot_kind(slot)
		if ok != _lit:
			_style(ok)
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen.call("equip_item", str((data as Dictionary)["item"]), slot)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			if _lit:
				_style(false)


# --- the right panel: pack / abilities -----------------------------------------------------

func _build_tabs(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var ready: int = _bindable_count()
	for tab: Array in [["pack", "Pack"], ["soul", "Abilities" + (("  -  %d to bind" % ready) if ready > 0 else "")]]:
		var id: String = str(tab[0])
		var b: Button = UiWidgets.small_button(str(tab[1]), func() -> void:
			_tab = id
			rebuild())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("15120e"), UiTheme.GOLD, 1, 4, 10))
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		row.add_child(b)


## How many abilities are full and have a construct of the right tier waiting.
func _bindable_count() -> int:
	var n := 0
	for st: Dictionary in player.get("abilities"):
		var need: String = str(player.call("pending_tier", st))
		if need == "":
			continue
		for c: Dictionary in player.get("constructs"):
			if str(c["tier"]) == need:
				n += 1
				break
	return n


# --- carried ---------------------------------------------------------------------------

func _build_bag(box: VBoxContainer, inv: Inventory) -> void:
	var w: float = inv.weight()
	var cap: float = maxf(1.0, inv.capacity())
	box.add_child(UiWidgets.Bar.new(w / cap, UiTheme.BAD if w > cap * 0.9 else UiTheme.BRONZE,
		"%d of %d kg      loot worth $%d" % [int(w), int(cap), inv.loot_value()], 20.0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = BAG_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	# stack identical items so twelve tusks are one cell; gear first, loot after
	var counts: Dictionary = {}
	var gear: Array[String] = []
	var loot: Array[String] = []
	for id: String in inv.bag:
		if not counts.has(id):
			counts[id] = 0
			if not Inventory.is_loot(id):
				gear.append(id)                    # things you can use: gear, and scrolls to read
			else:
				loot.append(id)
		counts[id] = int(counts[id]) + 1
	for id: String in gear + loot:
		grid.add_child(ItemButton.new(self, id, gear.has(id), int(counts[id])))
	# the rest of the grid is drawn empty, a whole number of rows of it
	var cells: int = maxi(BAG_MIN_CELLS, ceili(float(counts.size()) / float(BAG_COLUMNS)) * BAG_COLUMNS)
	for i: int in cells - counts.size():
		grid.add_child(EmptyCell.new())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.INSET, UiTheme.BRONZE_DIM, 1, 4, 10))
	panel.custom_minimum_size = Vector2(0, 196)
	panel.clip_contents = true
	box.add_child(panel)
	_inspect_box = VBoxContainer.new()
	_inspect_box.add_theme_constant_override("separation", 3)
	panel.add_child(_inspect_box)
	_fill_inspect()


## A pack item as one cell of the grid. Gear equips on a left or right click and can be dragged
## onto a slot; loot does nothing when clicked (it is only for selling).
class ItemButton extends Button:
	var screen: Control
	var item_id := ""
	var equippable := false
	var count := 1

	func _init(owner_screen: Control, id: String, can_equip: bool, how_many: int = 1) -> void:
		screen = owner_screen
		item_id = id
		equippable = can_equip
		count = how_many
		custom_minimum_size = Vector2(CELL_PX, CELL_PX)
		focus_mode = Control.FOCUS_NONE
		button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
		var well: StyleBox = UiTheme.frame("slot")
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, well)
		if equippable:
			pressed.connect(func() -> void: screen.call("equip_item", item_id))
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		mouse_entered.connect(func() -> void: screen.call("show_item", item_id, ""))
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if equippable:
			draw_rect(r.grow(-3.0), Color(UiTheme.GOLD, 0.06))            # gear sits on a faint warm ground; loot does not
		UiDraw.icon(self, UiDraw.item_icon(GameData.item(item_id)), size * 0.5, minf(size.x, size.y) * 0.5, UiTheme.GOLD if equippable else UiTheme.TEXT_DIM)
		if count > 1:
			UiDraw.outlined(self, Vector2(0, size.y - 6.0), "x%d" % count, UiTheme.FS_SMALL, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0)
		if is_hovered():
			draw_rect(r.grow(-1.0), UiTheme.GOLD if equippable else UiTheme.BRONZE, false, 1.5)

	func _get_drag_data(_at: Vector2) -> Variant:
		if not equippable:
			return null
		var ghost := Label.new()
		ghost.text = str(GameData.item(item_id).get("name", item_id))
		ghost.add_theme_color_override("font_color", UiTheme.GOLD)
		ghost.add_theme_font_size_override("font_size", 18)
		set_drag_preview(ghost)
		return {"item": item_id}


## A cell of the pack with nothing in it.
class EmptyCell extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(CELL_PX, CELL_PX)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(UiTheme.frame("slot"), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))


# --- the description under the pack -------------------------------------------------------
# It follows the cursor - a pack item, or a slot - and keeps the last thing until the cursor
# finds another, so its Sell / Drop button can be reached. Because it has a place of its own it
# never covers the thing it describes.

## Describe pack item `id` (slot ""), or whatever is worn in `slot`.
func show_item(id: String, slot: String) -> void:
	_inspect_id = id
	_inspect_slot = slot
	if _inspect_box != null and is_instance_valid(_inspect_box):
		_fill_inspect()


## After a rebuild the thing described may have moved: follow it onto the doll, or let it go.
func _settle_inspect(inv: Inventory) -> void:
	if _inspect_id == "":
		return
	if _inspect_slot != "" and str(inv.equipped.get(_inspect_slot, "")) != _inspect_id:
		_inspect_slot = ""
	if _inspect_slot == "" and not inv.bag.has(_inspect_id):
		for slot: String in inv.equipped:
			if str(inv.equipped[slot]) == _inspect_id:
				_inspect_slot = slot
				return
		_inspect_id = ""


func _fill_inspect() -> void:
	for c: Node in _inspect_box.get_children():
		_inspect_box.remove_child(c)
		c.queue_free()
	var inv: Inventory = player.get("inventory")
	if _inspect_id == "":
		if _inspect_slot != "":
			_inspect_box.add_child(UiTheme.heading(str(SLOT_LABELS[_inspect_slot]), 18, UiTheme.TEXT_DIM))
			_inspect_box.add_child(UiTheme.body(str(SLOT_HINTS[_inspect_slot]), 14, UiTheme.TEXT_FAINT))
		else:
			_inspect_box.add_child(UiTheme.body("Point at anything to read about it here.", 14, UiTheme.TEXT_DIM))
			_inspect_box.add_child(UiTheme.body("Click gear in your pack to wear it, or drag it onto a slot. Loot is only good for selling.", 13, UiTheme.TEXT_FAINT))
		return
	var def: Dictionary = GameData.item(_inspect_id)
	var item_slot: String = str(def.get("slot", ""))
	var worn: bool = _inspect_slot != ""
	var id: String = _inspect_id

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_inspect_box.add_child(head)
	head.add_child(UiWidgets.Icon.new(UiDraw.item_icon(def), UiTheme.GOLD if item_slot != "" else UiTheme.TEXT_DIM, 44.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	head.add_child(col)
	col.add_child(UiTheme.body(str(def.get("name", id)), 18, UiTheme.TEXT))
	var kind: String = str(SLOT_LABELS.get(item_slot, "Loot"))
	col.add_child(UiTheme.body("%s%s   -   %.1f kg   -   worth $%d" % [kind, "  (worn)" if worn else "", float(def.get("weight", 0.0)), int(def.get("value", 0))], 12, UiTheme.TEXT_DIM))
	var act: Button
	if worn:
		var from: String = _inspect_slot
		act = UiWidgets.small_button("Take off", func() -> void: unequip_slot(from))
	elif str(game.get("state")) == "town":
		act = UiWidgets.small_button("Sell $%d" % inv.sale_price(id), func() -> void:
			game.call("town_sell_item", id)
			rebuild())
	else:
		act = UiWidgets.small_button("Drop", func() -> void:
			game.call("drop_item", id)
			rebuild())
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(act)

	if str(def.get("kind", "")) == "kit":
		_inspect_box.add_child(UiTheme.body("A field kit. Click it in your pack to work with it here.", 14, UiTheme.TEXT_DIM))
	elif str(def.get("kind", "")) == "tool":
		_inspect_box.add_child(UiTheme.body("A crafting tool. It is used at a station and wears a little with every combine.", 14, UiTheme.TEXT_DIM))
	elif str(def.get("kind", "")) == "material":
		_inspect_box.add_child(UiTheme.body("A crafting material. It sells for what it is worth, one at a time.", 14, UiTheme.TEXT_DIM))
	elif item_slot == "":
		_inspect_box.add_child(UiTheme.body("Loot. Only good for selling.", 14, UiTheme.TEXT_DIM))
	elif worn and _inspect_slot == "weapon" and bool(player.get("arm_right_lost")):
		_inspect_box.add_child(UiTheme.body("No arm to hold it - it does nothing.", 14, UiTheme.BAD))
	else:
		var stats: String = UiWidgets.item_stats_text(def)
		_inspect_box.add_child(UiTheme.body(stats if stats != "" else "Does nothing yet.", 14, UiTheme.GOOD if stats != "" else UiTheme.TEXT_FAINT))
	_inspect_box.add_child(UiTheme.body(str(def.get("desc", "")), 13, UiTheme.TEXT_DIM))
	if item_slot == "" or worn:
		return
	# against what is worn where this would go
	var target: String = inv.slot_for(id)
	var worn_id: String = str(inv.equipped.get(target, ""))
	if worn_id == "":
		_inspect_box.add_child(UiTheme.body("Nothing is worn there now.", 13, UiTheme.TEXT_FAINT))
		return
	var lines: Array = compare_lines(def, GameData.item(worn_id))
	_inspect_box.add_child(UiTheme.body("Instead of the %s you wear:%s" % [str(GameData.item(worn_id).get("name", worn_id)), "  no difference." if lines.is_empty() else ""], 13, UiTheme.TEXT_FAINT))
	for line: Array in lines:
		_inspect_box.add_child(UiTheme.body(str(line[0]), 13, UiTheme.GOOD if bool(line[1]) else UiTheme.BAD))


## What changes if `new_def` replaces `old_def`: one [text, is_better] pair per stat that differs.
static func compare_lines(new_def: Dictionary, old_def: Dictionary) -> Array:
	var out: Array = []
	var a: Dictionary = new_def.get("stats", {})
	var b: Dictionary = old_def.get("stats", {})
	for key: String in STAT_INFO:
		if not a.has(key) and not b.has(key):
			continue
		var info: Array = STAT_INFO[key]
		var kind: String = str(info[1])
		var neutral: float = 1.0 if kind == "mult" else 0.0
		# a shot's interval and range have no neutral value; a weapon that does not say uses the default
		if key == "ranged_interval":
			neutral = GameData.num("ranged", "default_interval")
		elif key == "ranged_range":
			neutral = GameData.num("ranged", "default_range")
		var now: float = float(a.get(key, neutral))
		var was: float = float(b.get(key, neutral))
		if is_equal_approx(now, was):
			continue
		out.append(["%s  %s   (now %s)" % [str(info[0]), _stat_text(now, kind), _stat_text(was, kind)], (now > was) == bool(info[2])])
	return out


static func _stat_text(v: float, kind: String) -> String:
	match kind:
		"mult": return "x%.2f" % v
		"pct": return "%d%%" % int(v)
		"s": return "%.1f s" % v
		"m": return "%.1f m" % v
		"kg": return "%d kg" % int(v)
		"rate": return "+%s / s" % String.num(v, 1)
	return str(v)


# --- soul: abilities and constructs ------------------------------------------------------

func _build_soul(box: VBoxContainer) -> void:
	var abilities: Array = player.get("abilities")
	var held: Array = player.get("constructs")
	var list: VBoxContainer = scroller(box)
	for ai: int in abilities.size():
		var st: Dictionary = abilities[ai]
		var ab: Dictionary = player.call("ability_stats", st)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		list.add_child(head)
		head.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3), 44.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		head.add_child(col)
		col.add_child(UiTheme.body("%s   -   stage %d" % [str(ab.get("name", "?")), int(st["stage"])], UiTheme.FS_BODY + 1, UiTheme.TEXT))
		var need: String = str(player.call("pending_tier", st))
		col.add_child(UiWidgets.Bar.new(float(st["progress"]) / 100.0, UiTheme.GOLD if need != "" else UiTheme.ESSENCE,
			("FULL - needs a %s" % need) if need != "" else "%d%%   costs %d essence" % [int(float(st["progress"])), int(round(float(ab.get("cost", 0.0))))], 22.0))
		var bound: Array = st.get("bound", [])
		if not bound.is_empty():
			var names: Array[String] = []
			for up: Dictionary in bound:
				names.append("%s of %s" % [str(up["tier"]), str(GameData.concept(str(up["concept"])).get("label", up["concept"]))])
			col.add_child(UiTheme.body("Bound: " + ", ".join(names), 12, UiTheme.STAR))
		var rune_fx: Array = player.call("rune_summary", ai)
		if not rune_fx.is_empty():
			col.add_child(UiTheme.body("Sealed word: " + ", ".join(PackedStringArray(rune_fx.map(func(v: Variant) -> String: return str(v)))), 12, UiTheme.GOLD))
		if need != "":
			for ci: int in held.size():
				if str(held[ci]["tier"]) == need:
					var label: String = str(GameData.concept(str(held[ci]["concept"])).get("label", held[ci]["concept"]))
					var bind_b: Button = UiWidgets.small_button("Bind the %s of %s - form the seal" % [need, label], func() -> void:
						game.call("open_seal", ai, ci))
					bind_b.add_theme_font_size_override("font_size", UiTheme.FS_SMALL + 1)
					col.add_child(bind_b)
		list.add_child(UiTheme.rule())

	box.add_child(UiTheme.heading("Constructs carried", 18))
	if held.is_empty():
		box.add_child(UiTheme.body("None. For now they come from the strongest things you kill.", 13, UiTheme.TEXT_FAINT))
	else:
		var names2: Array[String] = []
		for c: Dictionary in held:
			names2.append("%s of %s" % [str(c["tier"]), str(GameData.concept(str(c["concept"])).get("label", c["concept"]))])
		box.add_child(UiTheme.body(", ".join(names2), 14, UiTheme.GOLD))
	var proven: Array = player.get("discoveries")
	if not proven.is_empty():
		box.add_child(UiTheme.heading("Proven about your talent", 18))
		for line: String in proven:
			box.add_child(UiTheme.body(line, 13, UiTheme.TEXT_DIM))
