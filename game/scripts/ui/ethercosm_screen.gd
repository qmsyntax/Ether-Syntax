extends UiScreen
## The ethercosm: the inner space of the soul (design/01 LAW 2, LAW 4c).
##   centre      - your stars. Each is an essence tank; its size and ring show its capacity.
##   in orbit    - your satellite, if you wear one.
##   around them - your abilities. Each sits inside a ring of runes: the runechain that defines
##                 it. Runes light as the ability grows; a completed stage closes into a solid
##                 ring crowned with its keystone (the construct set over it) as a gem; a full ring waiting for a
##                 construct pulses.
##   below       - the three sockets for spirit abilities (not obtainable yet).
## Click an ability to see it, open its seal (and, when its bar is full, its level lock), or assign it
## to a skill slot. Nothing is bound from this page (Brent 2026-10-23: "No binding the constructs on
## the main page, only with the runes"): a full skill says it is ready for its level lock and what
## tier it needs, and one button opens its seal screen.
##
## The ring glyphs are original marks generated per ability - they are not the books' alphabet.
##
## The seal screen (design/14 sections 7-8 and 11, Brent 2026-10-23) is the rune view of the selected
## skill: its word drawn as concentric rings by RuneBoard, beside the runes the character knows. At a
## level lock ("bind") the next ring is built from the skill outward, the construct of the tier is
## chosen on the same screen (with what each concept would do), and the bind locks ring and construct
## together. Opened otherwise it shows the sealed word, read-only - for test characters too. Everything
## it shows about a word - what may be added or joined and why not, sockets, link kinds, rings,
## shape traits, whether the word is closed - comes from the rule set in force (Runes.active()).
## Building it (design/14 section 10): runes are set from the palette by carrying or click-then-place
## and never bonded by a placement; bonds are dragged rune to rune on the board; a rune or a bond is
## selected by a click and deleted with Delete / Backspace (InputMap seal_delete / seal_delete_alt),
## right-click or the bond's x; Ctrl+Z / Ctrl+Y (seal_undo / seal_redo) step the draft's history;
## Esc first cancels whatever is in progress. The screen holds the selection (picked, picked_bond,
## armed_rune); the board only reads the mouse and calls back.

const RUNES_PER_STAGE := 16

var selected := 0
## The rune-setting view is open on the selected skill.
var rune_mode := false
## The rune selected on the board (-1 = none): the panel shows it; Delete takes it out.
var picked := -1
## The bond selected on the board, (a, b) with a < b ((-1, -1) = none): the panel shows it; Delete or
## its x parts it.
var picked_bond := Vector2i(-1, -1)
## A palette rune picked up by a click, waiting for a click on an empty place ("" = none).
var armed_rune := ""
## The panel shows the glossary of every status instead of the selected skill.
var glossary := false
var _cosmos: Cosmos
var _detail: VBoxContainer
var _board: RuneBoard
var _rune_status: VBoxContainer
var _rune_info: VBoxContainer
var _lock_button: Button
var _lock_note: Label
## The level lock's construct choice (the seal screen, mode "bind").
var _constructs_box: VBoxContainer
var _clear_button: Button
var _reset_button: Button
var _undo_button: Button
var _redo_button: Button
var _palette_title: Label
var _palette_tabs: HBoxContainer
var _palette_flow: HFlowContainer
## Which group of the palette is shown: an affinity id, or "universal".
var _palette_tab := ""
var _chips: Array[Control] = []
var _rune_msg := ""
var _rune_msg_bad := false


func backdrop() -> float:
	return 0.9


func close_actions() -> Array[String]:
	return ["ethercosm", "settings"]


func hud_hides() -> Array[String]:
	return HUD_MENU


func build(root: Control) -> void:
	var abilities: Array = player.get("abilities")
	selected = clampi(selected, 0, maxi(0, abilities.size() - 1))
	if rune_mode and not abilities.is_empty():
		_build_runes(root)
		return

	_cosmos = Cosmos.new(self)
	_cosmos.anchor_left = 0.02
	_cosmos.anchor_top = 0.03
	_cosmos.anchor_right = 0.66
	_cosmos.anchor_bottom = 0.97
	_cosmos.offset_left = 0
	_cosmos.offset_top = 0
	_cosmos.offset_right = 0
	_cosmos.offset_bottom = 0
	root.add_child(_cosmos)

	_detail = framed(root, 0.67, 0.03, 0.98, 0.97)
	_detail.add_theme_constant_override("separation", 7)
	_build_detail()


func select(index: int) -> void:
	selected = index
	glossary = false
	if rune_mode or _detail == null or not is_instance_valid(_detail):
		return
	for c: Node in _detail.get_children():
		_detail.remove_child(c)              # out at once, so the new rows keep their names
		c.queue_free()
	_build_detail()


# --- the seal screen (design/14 sections 7-8 and 11) -----------------------------------------
# Brent 2026-10-23: the rune view became the seal screen, and the level lock happens only here. A
# skill whose bar is full opens at its lock: the forming ring is built (inner rings may be reworked),
# the construct of the tier is chosen in the panel, and "Bind and lock" rolls the bind; only if it
# takes does the draft become the skill's word. Opened any other time it shows the sealed word,
# read-only - a test character too (no free edit since the same ruling).

## Open the seal screen of the selected skill at its level lock; `construct_index` < 0 lets the
## player choose the keystone there. The lock opens only with the bar full and a construct of the tier
## carried (Brent 2026-10-24); otherwise the screen stays on (or goes back to) the main page, which
## says what is missing.
func open_seal(construct_index: int = -1) -> void:
	var r: Dictionary = player.call("open_seal", selected, construct_index)
	_clear_selection()
	_palette_tab = ""
	if not bool(r["ok"]):
		rune_mode = false
		player.call("note", str(r["text"]))
		rebuild()
		return
	rune_mode = true
	_say("", false)
	rebuild()


## Open the seal screen of the selected skill: at its level lock when it can be opened, else its
## sealed word to look at.
func open_runes() -> void:
	if bool((player.call("can_open_seal", selected) as Dictionary)["ok"]):
		open_seal()
		return
	rune_mode = true
	_clear_selection()
	_rune_msg = ""
	_palette_tab = ""
	player.call("close_seal")
	rebuild()


## Choose which carried construct the level lock binds - the keystone set over the forming ring (the
## panel's KEYSTONE buttons).
func choose_construct(construct_index: int) -> void:
	var r: Dictionary = player.call("choose_seal_construct", construct_index)
	if bool(r["ok"]):
		var ks: Dictionary = player.call("seal_keystone")
		_say(("The %s is set over ring %d as its keystone." if bool(ks.get("set", false)) else
			"The %s will be set over ring %d as its keystone once every place of the ring is filled.") % [str(ks.get("label", "")), int(ks.get("ring", 0))], false)
	else:
		_say(str(r["text"]), true)
	_fill_constructs()
	_refresh_runes()


func close_runes() -> void:
	rune_mode = false
	_clear_selection()
	player.call("close_seal")
	rebuild()


func _clear_selection() -> void:
	picked = -1
	picked_bond = Vector2i(-1, -1)
	armed_rune = ""


func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and int(player.call("sealing_index")) >= 0:
		player.call("close_seal")        # a draft lives only while its screen is open


## "bind" (forming the skill's next level lock) or "view".
func seal_view() -> String:
	if int(player.call("sealing_index")) == selected:
		return str(player.call("seal_mode"))
	return "view"


## The word being set, and what the rules may know about its skill (read by the board).
func current_word() -> Dictionary:
	return player.call("ability_word", selected)


func current_context() -> RuneContext:
	return player.call("rune_context", selected)


## How many rings of the skill's word are sealed (the draft's are not, until the bind takes).
func sealed_rings() -> int:
	var st: Dictionary = (player.get("abilities") as Array)[selected]
	return RuneWord.sealed(st.get("word", {}))


## Select rune i on the board (-1: none). Also what the shots call.
func select_node(i: int) -> void:
	picked = i if i >= 0 and i < RuneWord.size(current_word()) else -1
	picked_bond = Vector2i(-1, -1)
	_refresh_runes()


## The old name of select_node (shots and tests).
func pick_node(i: int) -> void:
	select_node(i)


## Select the bond a-b.
func select_bond(a: int, b: int) -> void:
	if not RuneWord.linked(current_word(), a, b):
		return
	picked_bond = Vector2i(mini(a, b), maxi(a, b))
	picked = -1
	_refresh_runes()


## A click on empty space: put down the rune in hand, else drop the selection.
func deselect() -> void:
	if armed_rune != "":
		armed_rune = ""
	else:
		picked = -1
		picked_bond = Vector2i(-1, -1)
	_refresh_runes()


## Esc: cancel what is in progress - a bond being dragged, a rune in hand, a selection. Returns true
## if there was something to cancel (otherwise Esc closes the screen as before).
func cancel_action() -> bool:
	if _board != null and is_instance_valid(_board) and _board.cancel_drag():
		_say("No bond made.", false)
		_refresh_runes()
		return true
	if armed_rune != "":
		armed_rune = ""
		_say("", false)
		_refresh_runes()
		return true
	if picked >= 0 or picked_bond.x >= 0:
		picked = -1
		picked_bond = Vector2i(-1, -1)
		_refresh_runes()
		return true
	return false


## A click on a palette rune: pick it up (or put it down again); a click on an empty place then sets
## it there. An undiscovered rune says why it cannot be set.
func arm_rune(rune_id: String) -> void:
	var known: bool = bool(player.call("knows_rune", rune_id))
	var nm: String = str(GameData.rune(rune_id).get("name", rune_id)) if known else "That rune"
	if seal_view() == "view":
		_say("Runes are set at a level lock: when the skill's bar is full its seal opens for the next ring.", true)
	elif not known:
		_say("%s cannot be set: you have not discovered it yet - runes are found in the Netherecho, in fights and on old stones." % nm, true)
	elif armed_rune == rune_id:
		armed_rune = ""
		_say("", false)
	else:
		armed_rune = rune_id
		picked = -1
		picked_bond = Vector2i(-1, -1)
		_say("%s picked up: click an empty place on a ring to set it." % nm, false)
	_refresh_runes()


## A palette rune is being carried to the board, the cursor at `at` (global): the board lights the
## places that would take it and draws it at the cursor.
func carry_move(rune_id: String, at: Vector2) -> void:
	armed_rune = ""
	if _board != null and is_instance_valid(_board):
		_board.carry_at(rune_id, at)


## The carried rune let go at `at` (global): the board sets it on the place there, if any.
func carry_end(rune_id: String, at: Vector2) -> void:
	if _board != null and is_instance_valid(_board):
		_board.drop_at(rune_id, at)


## The carried rune let go away from the board.
func carry_cancelled(_rune_id: String) -> void:
	_refresh_runes()


## A click on an empty place of ring k: the rune in hand goes there.
func click_slot(k: int, place: int) -> void:
	if seal_view() == "view":
		return
	if armed_rune != "":
		place_rune(armed_rune, k, place)
		return
	picked = -1
	picked_bond = Vector2i(-1, -1)
	_say("An empty place on ring %d: drag a rune here from the panel, or click one there first." % k, false)
	_refresh_runes()


## May rune `rune_id` be set on ring k now? {ok, reason, text} - the character's knowledge first,
## then the rules.
func place_check(rune_id: String, k: int) -> Dictionary:
	if not bool(player.call("knows_rune", rune_id)):
		return RuneRules.no("unknown", "Not discovered yet: runes are found in the Netherecho, in fights and on old stones.")
	if not bool(player.call("can_use_rune", rune_id)):
		return RuneRules.no("not_yours", "%s belongs to an affinity you do not hold." % str(GameData.rune(rune_id).get("name", rune_id)))
	return Runes.active().can_add(current_word(), rune_id, current_context(), -1, k)


## Set rune `rune_id` on ring k at place `place` (dropped there, or clicked after picking it up).
## It is set alone: bonds are made by dragging from one rune to another.
func place_rune(rune_id: String, k: int, place: int) -> void:
	var nm: String = str(GameData.rune(rune_id).get("name", rune_id))
	var r: Dictionary = player.call("word_add", selected, rune_id, -1, k, place)
	if bool(r["ok"]):
		armed_rune = ""
		picked = int(r.get("node", -1))
		picked_bond = Vector2i(-1, -1)
		_say("Set %s on ring %d. Drag from it to another rune to bond them." % [nm, k], false)
	else:
		_say("%s cannot be set there: %s" % [nm, str(r["text"])], true)
	_refresh_runes()


## A palette rune was let go over the board but not on an empty place.
func drop_missed(rune_id: String) -> void:
	_say("Drop %s on an empty place on a ring." % str(GameData.rune(rune_id).get("name", rune_id)), false)
	_refresh_runes()


## The end of a bond drag from rune a: let go on rune b (-1: elsewhere - no bond).
func finish_bond(a: int, b: int) -> void:
	if b < 0:
		_say("No bond made: let go on a glowing rune to bond it.", false)
		_refresh_runes()
		return
	var before: Dictionary = current_word()
	var names: Array = [RuneRules.rune_name(before, a), RuneRules.rune_name(before, b)]
	var r: Dictionary = player.call("word_link", selected, a, b)
	if bool(r["ok"]):
		picked_bond = Vector2i(mini(a, b), maxi(a, b))
		picked = -1
		_say("Bonded: %s." % str(Runes.active().describe_link(current_word(), a, b, current_context()).get("text", "")), false)
	else:
		_say("%s and %s cannot bond: %s" % [names[0], names[1], str(r["text"])], true)
	_refresh_runes()


## Part the bond a-b (its x, right-click, or Delete with it selected).
func delete_bond(a: int, b: int) -> void:
	var word: Dictionary = current_word()
	var names: Array = [RuneRules.rune_name(word, a), RuneRules.rune_name(word, b)]
	var r: Dictionary = player.call("word_unlink", selected, a, b)
	if bool(r["ok"]):
		picked_bond = Vector2i(-1, -1)
		_say("Parted %s and %s. %s brings the bond back." % [names[0], names[1], Keybinds.binding_text("seal_undo")], false)
	else:
		_say(str(r["text"]), true)
	_refresh_runes()


## Delete or Backspace: the selected bond, or the selected rune with its bonds.
func delete_selected() -> void:
	if picked_bond.x >= 0:
		delete_bond(picked_bond.x, picked_bond.y)
	elif picked >= 0:
		remove_node(picked)


## Ctrl+Z: the draft one step back.
func undo() -> void:
	if bool(player.call("draft_undo")):
		_say("Undone.", false)
	else:
		_say("Nothing to undo.", false)
	picked = -1
	picked_bond = Vector2i(-1, -1)
	_refresh_runes()


## Ctrl+Y: the step undone, again.
func redo() -> void:
	if bool(player.call("draft_redo")):
		_say("Redone.", false)
	else:
		_say("Nothing to redo.", false)
	picked = -1
	picked_bond = Vector2i(-1, -1)
	_refresh_runes()


func _unhandled_input(event: InputEvent) -> void:
	if rune_mode and seal_view() != "view" and not event.is_echo():
		if event.is_action_pressed("seal_undo"):
			get_viewport().set_input_as_handled()
			undo()
			return
		if event.is_action_pressed("seal_redo"):
			get_viewport().set_input_as_handled()
			redo()
			return
		if event.is_action_pressed("seal_delete") or event.is_action_pressed("seal_delete_alt"):
			get_viewport().set_input_as_handled()
			delete_selected()
			return
	if rune_mode and event.is_action_pressed("settings") and not event.is_echo() and cancel_action():
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


## Take a rune out of the draft, with its bonds.
func remove_node(i: int) -> void:
	var word: Dictionary = current_word()
	var nm: String = RuneRules.rune_name(word, i)
	var r: Dictionary = player.call("word_remove", selected, i)
	if bool(r["ok"]):
		picked = -1 if picked == i else (picked - 1 if picked > i else picked)
		picked_bond = Vector2i(-1, -1)
		_say("Took %s out, with its bonds. %s puts it back." % [nm, Keybinds.binding_text("seal_undo")], false)
	else:
		_say(str(r["text"]), true)
	_refresh_runes()


func clear_word() -> void:
	player.call("word_clear", selected)
	picked = -1
	picked_bond = Vector2i(-1, -1)
	_say("The draft is cleared back to the skill's own rune. %s brings it back." % Keybinds.binding_text("seal_undo"), false)
	_refresh_runes()


## Put the draft back as the sealed word was.
func reset_draft() -> void:
	player.call("draft_reset")
	picked = -1
	picked_bond = Vector2i(-1, -1)
	_say("The draft is back as the seal was.", false)
	_refresh_runes()


## The level lock: bind the chosen construct and, if it takes, seal the draft with it - ring and
## construct lock together. A test character's next lock opens straight after (its bar is refilled,
## a test override), so the screen stays on the lock.
func bind_and_seal(roll: float = -1.0) -> void:
	var st: Dictionary = (player.get("abilities") as Array)[selected]
	var skill: String = str(GameData.ability(str(st["id"])).get("name", "?"))
	var check: Dictionary = player.call("can_bind_seal")
	if not bool(check["ok"]):
		_say(str(check["text"]), true)
		_refresh_runes()
		return
	var result: String = str(player.call("bind_seal", roll))
	picked = -1
	picked_bond = Vector2i(-1, -1)
	armed_rune = ""
	if result == "bound":
		_say("The bind takes and the level %d lock holds: %s now works through this word." % [int(st["stage"]), skill], false)
	elif result == "failed":
		_say("The bind fails. The construct is gone and no seal forms: the word stays as it was.", true)
	else:
		_say(result, true)
	game.call("save_now")
	var msg: String = _rune_msg
	var bad: bool = _rune_msg_bad
	if bool((player.call("can_open_seal", selected) as Dictionary)["ok"]):
		open_seal()                  # the next lock is open at once (a test character), or the failed one again
		_say(msg, bad)
		_refresh_runes()
	elif result == "bound":
		rebuild()                    # the new seal, looked at
	else:
		rune_mode = false            # no construct of the tier left: back to the main page, which says so
		player.call("note", msg)
		rebuild()
	if result == "bound" and _board != null and is_instance_valid(_board):
		_board.play_lock()


## For a palette chip: whether some ring would take that rune now, its sockets, and whether it is known.
func chip_state(rune_id: String) -> Dictionary:
	var known: bool = bool(player.call("knows_rune", rune_id))
	if not known:
		return {"ok": false, "known": false, "text": "Not discovered yet.", "sockets": -1}
	var ctx: RuneContext = current_context()
	var rules: RuneRules = Runes.active()
	var r: Dictionary = {"ok": true, "text": ""}
	if seal_view() != "view":
		r = RuneRules.no("ring", "No ring has room for it.")
		for k: int in range(1, maxi(1, ctx.rings) + 1):
			var c: Dictionary = place_check(rune_id, k)
			if bool(c["ok"]):
				r = c
				break
			r = c
	return {"ok": bool(r["ok"]), "known": true, "text": str(r["text"]), "sockets": int(rules.describe_rune(rune_id, ctx).get("sockets", -1))}


## Show one group of the palette: an affinity, or "universal".
func set_palette_tab(tab: String) -> void:
	_palette_tab = tab
	_fill_palette()


func _say(text: String, bad: bool) -> void:
	_rune_msg = text
	_rune_msg_bad = bad


func _build_runes(root: Control) -> void:
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = current_context()
	var st: Dictionary = (player.get("abilities") as Array)[selected]
	var ab: Dictionary = GameData.ability(str(st["id"]))
	var mode: String = seal_view()

	_board = RuneBoard.new(self)
	_board.anchor_left = 0.015
	_board.anchor_top = 0.03
	_board.anchor_right = 0.585
	_board.anchor_bottom = 0.97
	root.add_child(_board)

	var box: VBoxContainer = framed(root, 0.595, 0.03, 0.985, 0.97)
	box.add_theme_constant_override("separation", 5)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading(("Level %d lock" % (ctx.stage + 1)) if mode == "bind" else "The seal", 26)
	title.name = "SealTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back: Button = UiWidgets.small_button("Back to the ethercosm", close_runes)
	back.name = "RunesBackButton"
	head.add_child(back)
	head.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("ethercosm"), func() -> void: game.call("close_screen")))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3), 42.0))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	name_row.add_child(name_col)
	name_col.add_child(UiTheme.heading("%s     level %d" % [str(ab.get("name", "?")), ctx.stage], 20))
	var anchor: Dictionary = GameData.rune(ctx.anchor)
	name_col.add_child(UiTheme.body(("Built on %s: %s.   Rules: %s" % [str(anchor.get("name", "?")), str(anchor.get("meaning", "")), rules.title()]) if not anchor.is_empty()
		else "This skill has no rune of its own in the data yet.", 12, UiTheme.STAR))
	var banner := UiTheme.body(_mode_banner(mode, ctx, st), 13, UiTheme.GOLD)
	banner.name = "SealBanner"
	box.add_child(banner)

	_rune_status = VBoxContainer.new()
	_rune_status.add_theme_constant_override("separation", 3)
	box.add_child(_rune_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rune_info = VBoxContainer.new()
	_rune_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rune_info.add_theme_constant_override("separation", 3)
	scroll.add_child(_rune_info)

	# the construct this lock binds: the carried ones of the tier, one button per concept
	_constructs_box = null
	if mode == "bind":
		_constructs_box = VBoxContainer.new()
		_constructs_box.name = "LockConstructs"
		_constructs_box.add_theme_constant_override("separation", 3)
		box.add_child(_constructs_box)
		_fill_constructs()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_lock_button = null
	_reset_button = null
	_clear_button = null
	if mode == "bind":
		_lock_button = UiWidgets.small_button("Bind and lock", func() -> void: bind_and_seal.call_deferred())
		_lock_button.name = "SealBindButton"
		_lock_button.custom_minimum_size = Vector2(170, 40)
		actions.add_child(_lock_button)
	_lock_note = UiTheme.body("", 12, UiTheme.TEXT_FAINT)
	_lock_note.name = "LockNote"
	_lock_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(_lock_note)
	# the draft's own row: undo, redo, put it back, clear
	_undo_button = null
	_redo_button = null
	if mode != "view":
		var edits := HBoxContainer.new()
		edits.add_theme_constant_override("separation", 6)
		box.add_child(edits)
		_undo_button = UiWidgets.small_button("Undo  (%s)" % Keybinds.binding_text("seal_undo"), func() -> void: undo.call_deferred())
		_undo_button.name = "UndoButton"
		edits.add_child(_undo_button)
		_redo_button = UiWidgets.small_button("Redo  (%s)" % Keybinds.binding_text("seal_redo"), func() -> void: redo.call_deferred())
		_redo_button.name = "RedoButton"
		edits.add_child(_redo_button)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edits.add_child(gap)
		if mode == "bind":
			_reset_button = UiWidgets.small_button("Put it back", func() -> void: reset_draft.call_deferred())
			_reset_button.name = "DraftResetButton"
			edits.add_child(_reset_button)
		_clear_button = UiWidgets.small_button("Clear", func() -> void: clear_word.call_deferred())
		_clear_button.name = "ClearWordButton"
		edits.add_child(_clear_button)

	var pal_head := HBoxContainer.new()
	pal_head.add_theme_constant_override("separation", 4)
	box.add_child(pal_head)
	_palette_title = UiTheme.body("", 12, UiTheme.GOLD.darkened(0.15))
	_palette_title.name = "PaletteTitle"
	_palette_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_title.tooltip_text = "Runes are found by subduing constructs in the Netherecho, sometimes by kills, and on old rune stones. A rune found is known for good."
	_palette_title.mouse_filter = Control.MOUSE_FILTER_PASS
	pal_head.add_child(_palette_title)
	_palette_tabs = HBoxContainer.new()
	_palette_tabs.add_theme_constant_override("separation", 3)
	pal_head.add_child(_palette_tabs)
	var pal_scroll := ScrollContainer.new()
	pal_scroll.custom_minimum_size = Vector2(0, 134)
	pal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(pal_scroll)
	_palette_flow = HFlowContainer.new()
	_palette_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_flow.add_theme_constant_override("h_separation", 4)
	_palette_flow.add_theme_constant_override("v_separation", 4)
	pal_scroll.add_child(_palette_flow)
	if _palette_tab == "":
		_palette_tab = str(ab.get("affinity", ""))
	_fill_palette()
	_refresh_runes()


## The line under the skill's name saying what this screen is doing.
func _mode_banner(mode: String, ctx: RuneContext, st: Dictionary) -> String:
	if mode == "bind":
		var need: String = str(player.call("pending_tier", st))
		var n_sealed: int = sealed_rings()
		var cap: int = (Runes.active() as RingRules).ring_capacity(ctx.forming) if Runes.active() is RingRules else 0
		var how: String = "Fill all %d places of ring 1, then set the %s over it as its keystone; the bind locks the level - all of it or nothing." % [cap, need] if ctx.forming <= 1 else \
			"Ring%s sealed (it may be reworked, and must stay full); fill all %d places of ring %d and set the %s over it as its keystone - the bind locks the level, all of it or nothing." % [
				(" 1" if n_sealed == 1 else "s 1-%d" % n_sealed), cap, ctx.forming, need]
		return "FORMING RING %d  -  %s" % [ctx.forming, how]
	var n: int = sealed_rings()
	if n <= 0:
		return ("No word yet. Runes are sealed when a construct is bound into the skill: %s." % ("its bar is full - bind a %s" % str(player.call("pending_tier", st))
			if str(player.call("pending_tier", st)) != "" else "fill its bar first"))
	return "Sealed through %d ring%s. It can be reworked when the next construct is bound." % [n, "" if n == 1 else "s"]


## The level lock's keystone choice (Brent 2026-10-24): the carried constructs of the tier the skill
## needs, one button per concept (Player.construct_groups), the chosen one marked; each button's
## tooltip says what that keystone would do. The lock only opens with one carried (can_open_seal).
func _fill_constructs() -> void:
	if _constructs_box == null or not is_instance_valid(_constructs_box):
		return
	for c: Node in _constructs_box.get_children():
		_constructs_box.remove_child(c)
		c.queue_free()
	var st: Dictionary = (player.get("abilities") as Array)[selected]
	var need: String = str(player.call("pending_tier", st))
	var groups: Array = player.call("construct_groups", need)
	var chosen: int = int(player.call("seal_construct"))
	var chosen_g: Dictionary = {}
	for g: Dictionary in groups:
		var cons: Array = player.get("constructs")
		if chosen >= 0 and chosen < cons.size() and str((cons[chosen] as Dictionary)["concept"]) == str(g["concept"]):
			chosen_g = g
	var ctx: RuneContext = current_context()
	var head := UiTheme.body("KEYSTONE  -  the %s set over ring %d, chosen here (x%s: it counts for more than any rune)" % [need, ctx.forming,
		RingRules._x((Runes.active() as RingRules).keystone_weight(need))] if Runes.active() is RingRules else "KEYSTONE", 12, UiTheme.GOLD.darkened(0.15))
	head.name = "KeystoneHead"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_constructs_box.add_child(head)
	if groups.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	_constructs_box.add_child(flow)
	for g: Dictionary in groups:
		var ci: int = int(g["index"])
		var label: String = str(GameData.concept(str(g["concept"])).get("label", g["concept"]))
		var b: Button = UiWidgets.small_button(label + ((" x%d" % int(g["count"])) if int(g["count"]) > 1 else ""), func() -> void: choose_construct.call_deferred(ci))
		b.name = "LockConstruct_%s" % str(g["concept"])
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(0, 30)
		var rows: Array[Dictionary] = player.call("preview_bind", st, str(g["concept"]))
		b.tooltip_text = "The %s of %s as the keystone of ring %d:\n%s" % [need, label, ctx.forming, "\n".join(PackedStringArray(rows.map(func(r: Dictionary) -> String:
			return "%s  %s -> %s" % [str(r["label"]), str(r["before"]), str(r["after"])])))]
		if g == chosen_g:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 3, 8))
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		flow.add_child(b)


## The palette's tabs and the chips of the tab shown.
func _palette_groups() -> Array[String]:
	var out: Array[String] = []
	for rid: String in (player.call("rune_palette") as Array):
		var aff: String = str(GameData.rune(rid).get("affinity", ""))
		var g: String = aff if aff != "" else "universal"
		if not out.has(g):
			out.append(g)
	return out


func _fill_palette() -> void:
	if _palette_flow == null or not is_instance_valid(_palette_flow):
		return
	var groups: Array[String] = _palette_groups()
	if not groups.has(_palette_tab) and not groups.is_empty():
		_palette_tab = groups[0]
	for c: Node in _palette_tabs.get_children():
		_palette_tabs.remove_child(c)
		c.queue_free()
	var all: Array = player.call("rune_palette")
	var known_n: int = all.filter(func(id: String) -> bool: return bool(player.call("knows_rune", id))).size()
	if _palette_title != null:
		_palette_title.text = "RUNES  -  every rune known (test character)" if bool(player.get("test_character")) \
			else "RUNES YOU KNOW  -  %d of %d found" % [known_n, all.size()]
	for g: String in groups:
		var b: Button = UiWidgets.small_button(g.capitalize(), func() -> void: set_palette_tab.call_deferred(g))
		b.name = "Tab_%s" % g
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(0, 30)
		if g == _palette_tab:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 1, 3, 8))
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		elif g != "universal":
			b.add_theme_color_override("font_color", GameData.affinity_color(g).lightened(0.35))
		_palette_tabs.add_child(b)
	for c2: Node in _palette_flow.get_children():
		_palette_flow.remove_child(c2)
		c2.queue_free()
	_chips.clear()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = current_context()
	for rid: String in all:
		var aff: String = str(GameData.rune(rid).get("affinity", ""))
		if (aff if aff != "" else "universal") != _palette_tab:
			continue
		var chip := RuneBoard.Chip.new(self, rid)
		if bool(player.call("knows_rune", rid)):
			var rune: Dictionary = GameData.rune(rid)
			var lines: Array = rules.describe_rune(rid, ctx).get("lines", [])
			chip.tooltip_text = "%s  %s\n%s%s" % [str(rune.get("name", rid)), str(rune.get("character", "")),
				str(rune.get("meaning", "")), ("\n" + "\n".join(PackedStringArray(lines))) if not lines.is_empty() else ""]
		else:
			chip.tooltip_text = "?  Not discovered yet.\nRunes are found by subduing constructs in the Netherecho, sometimes by kills, and on old rune stones."
		_palette_flow.add_child(chip)
		_chips.append(chip)


## Redraw what changes when the draft does: the status, the effects preview, the action row and the
## palette's dimming.
func _refresh_runes() -> void:
	if _rune_status == null or not is_instance_valid(_rune_status):
		return
	for holder: Control in [_rune_status, _rune_info]:
		for c: Node in holder.get_children():
			holder.remove_child(c)          # out at once, so the new rows keep their names
			c.queue_free()
	var rules: RuneRules = Runes.active()
	var ctx: RuneContext = current_context()
	var word: Dictionary = current_word()
	var mode: String = seal_view()
	var sealed: bool = mode == "view" and RuneWord.is_locked(word)
	var cap: int = rules.capacity(ctx)
	var used_n: int = rules.used(word, ctx)

	# status: room, state, the last thing said
	var cap_bar := UiWidgets.Bar.new(float(used_n) / float(cap) if cap > 0 else 0.0, UiTheme.STAR.darkened(0.55),
		("%d of %d runes   -   %d ring%s" % [used_n, cap, ctx.rings, "" if ctx.rings == 1 else "s"]) if cap >= 0 else "%d runes   -   no limit under these rules" % used_n, 20.0)
	cap_bar.name = "RuneCapacity"
	_rune_status.add_child(cap_bar)
	var ws: Dictionary = rules.word_state(word, ctx)
	var state_text: String = ("SEALED  -  the skill works through this word" if sealed else ("no word yet" if mode == "view" else str(ws.get("label", ""))))
	var state_line := UiTheme.body(state_text, 15, UiTheme.GOLD if sealed else (UiTheme.GOOD if bool(ws.get("closed", false)) else UiTheme.TEXT_DIM))
	state_line.name = "WordState"
	_rune_status.add_child(state_line)
	for p: Variant in ws.get("problems", []):
		_rune_status.add_child(UiTheme.body(str(p), 13, UiTheme.BAD))
	if mode != "view":
		var l_text: String = "   ".join(PackedStringArray((ws.get("lines", []) as Array).map(func(v: Variant) -> String: return str(v))))
		if l_text != "":
			_rune_status.add_child(UiTheme.body(l_text, 12, UiTheme.TEXT_FAINT))
	if _rune_msg != "":
		var msg := UiTheme.body(_rune_msg, 13, UiTheme.BAD if _rune_msg_bad else UiTheme.TEXT)
		msg.name = "RuneMessage"
		_rune_status.add_child(msg)

	# the picked rune first (filled below), then the effects preview
	var picked_box := VBoxContainer.new()
	picked_box.add_theme_constant_override("separation", 2)
	_rune_info.add_child(picked_box)
	var pv: Dictionary = player.call("rune_preview", selected)
	# at a level lock: the keystone chosen - set over the ring once it is full - and what it alone does
	if mode == "bind":
		var ks: Dictionary = player.call("seal_keystone")
		if not ks.is_empty():
			var csec := UiTheme.section("Keystone: the %s, %s ring %d" % [str(ks["label"]), "set over" if bool(ks["set"]) else "waiting above", int(ks["ring"])])
			csec.name = "ChosenConstruct"
			_rune_info.add_child(csec)
			var kfx: Dictionary = (Runes.active() as RingRules).keystone_effect(GameData.ability(str((player.get("abilities") as Array)[selected]["id"])), ks) \
				if Runes.active() is RingRules else {}
			var kl := UiTheme.body("      x%s (a rune works at most x1):  %s" % [RingRules._x(float(kfx.get("weight", 1.0))), ", ".join(PackedStringArray(kfx.get("lines", [])))],
				13, UiTheme.STAR.lightened(0.2))
			kl.name = "KeystoneEffect"
			kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_rune_info.add_child(kl)
			if not bool(ks["set"]):
				_rune_info.add_child(UiTheme.body("      It is set over ring %d when every place of the ring is filled." % int(ks["ring"]), 12, UiTheme.TEXT_FAINT))
			_rune_info.add_child(_bind_preview((player.get("abilities") as Array)[selected], str(ks["concept"])))
	var head_text: String = "WHAT THE SEAL DOES" if sealed else ("WHAT THE WORD WOULD DO, SEALED" if mode != "view" else "NO WORD YET")
	_rune_info.add_child(UiTheme.section(head_text))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	grid.name = "EffectRows"
	_rune_info.add_child(grid)
	for row: Dictionary in pv.get("rows", []):
		var changed: bool = bool(row["changed"])
		# a row that names a status ("Live marks") explains it: a tooltip, and a click opens it in place
		var lab: Control = UiWidgets.status_line(str(row["label"]), 13, UiTheme.TEXT if changed else UiTheme.TEXT_FAINT)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lab is Label:
			(lab as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(lab)
		var val := UiTheme.body(("%s   ->   %s" % [str(row["before"]), str(row["after"])]) if changed else str(row["before"]), 13,
			(UiTheme.GOOD if bool(row["better"]) else UiTheme.BAD) if changed else UiTheme.TEXT_FAINT)
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
	var anchor_info: Dictionary = pv.get("anchor", {})
	for t: Variant in (anchor_info.get("lines", []) as Array) + (pv.get("effect_lines", []) as Array):
		_rune_info.add_child(UiWidgets.status_line("  +  %s" % str(t), 13, UiTheme.STAR))      # names a status: tooltip + click
	if not anchor_info.is_empty() and RuneWord.degree(word, 0) > 0:
		_rune_info.add_child(UiTheme.body("The skill's own rune keeps x%.2f of what it does (%s)%s." % [float(anchor_info.get("factor", 1.0)),
			", ".join(PackedStringArray((anchor_info.get("kinds", []) as Array).map(func(v: Variant) -> String: return str(v)))),
			" - balanced" if bool(anchor_info.get("balanced", false)) else ""], 12, UiTheme.TEXT_FAINT))

	# the keystones, one over each sealed ring (and the one this lock sets)
	var kss: Array = pv.get("keystones", [])
	if not kss.is_empty():
		var ksec := UiTheme.section("Keystones")
		ksec.name = "Keystones"
		_rune_info.add_child(ksec)
		for kd: Dictionary in kss:
			var kline := UiTheme.body("  ring %d  -  %s  (x%s):  %s" % [int(kd["ring"]), str(kd["label"]), RingRules._x(float(kd["weight"])),
				", ".join(PackedStringArray(kd["lines"]))], 13, UiTheme.STAR.lightened(0.15))
			kline.name = "Keystone_%d" % int(kd["ring"])
			kline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_rune_info.add_child(kline)

	# the shape: traits the word has
	var traits: Array = pv.get("traits", [])
	if not traits.is_empty():
		var sh := UiTheme.section("Shape")
		sh.name = "ShapeTraits"
		_rune_info.add_child(sh)
		for t2: Dictionary in traits:
			var tl := UiTheme.body("  %s%s:  %s" % [str(t2["label"]), (" (ring %d)" % int(t2["ring"])) if t2.has("ring") else "", str(t2.get("effect", ""))], 13, UiTheme.GOLD.lightened(0.2))
			tl.name = "Trait_%s" % str(t2["id"])
			_rune_info.add_child(tl)
	# what ionic bonds carried where, and what they converted into strength (Bond Rules rows 71-72)
	var transfers: Array = pv.get("transfers", [])
	var convs: Array = pv.get("conversions", [])
	if not transfers.is_empty() or not convs.is_empty():
		var ch := UiTheme.section("Carried and converted")
		ch.name = "Carried"
		_rune_info.add_child(ch)
		for tr: Dictionary in transfers:
			_rune_info.add_child(UiTheme.body("  %s" % str(tr["text"]), 13, RuneBoard.LINK_COLOURS["ionic"].lightened(0.3)))
		for cv: Dictionary in convs:
			var cvl := UiTheme.body("  %s" % str(cv["text"]), 13, RuneBoard.LINK_COLOURS["ionic"].lightened(0.45))
			cvl.name = "Conversion_%d" % int(cv["from"])
			_rune_info.add_child(cvl)

	# rune by rune
	var rows: Array = pv.get("runes", [])
	if not rows.is_empty():
		_rune_info.add_child(UiTheme.section("Rune by rune"))
		for r: Dictionary in rows:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			_rune_info.add_child(line)
			var rune: Dictionary = GameData.rune(str(r["id"]))
			var aff: String = str(rune.get("affinity", ""))
			var nm := UiTheme.body("%s %s" % [str(rune.get("character", "")), str(r["name"])], 14, GameData.affinity_color(aff).lightened(0.35) if aff != "" else UiTheme.STAR)
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			nm.custom_minimum_size = Vector2(118, 0)
			line.add_child(nm)
			var ring_t: String = ("ring %d  -  " % int(r["ring"])) if r.has("ring") else ""
			var how: String = ring_t + ("not joined to the skill" if int(r["bonds"]) < 0 else "%d bond%s in  -  %s" % [int(r["bonds"]), "" if int(r["bonds"]) == 1 else "s", str(r.get("relation", r["kind"]))])
			var hl := UiTheme.body(how, 12, UiTheme.TEXT_DIM)
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hl.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(hl)
			var carried: bool = int(r.get("carried_to", -1)) >= 0
			var sl := UiTheme.body(("-> %s" % str(r.get("carried_by", ""))) if carried else "x%.2f" % float(r["strength"]), 13, RuneBoard.LINK_COLOURS["ionic"].lightened(0.3) if carried else UiTheme.GOLD)
			sl.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(sl)
			if float(r.get("converted", 0.0)) > 0.0:
				# ionic conversion (Bond Rules rows 71-72): what it took became its strength
				var cl := UiTheme.body("      strength x%.2f + %.2f %s = x%.2f%s" % [float(r["path_strength"]), float(r["converted"]),
					str(r.get("converted_from", "converted")), float(r["strength"]), "  (capped)" if bool(r.get("capped", false)) else ""], 12,
					RuneBoard.LINK_COLOURS["ionic"].lightened(0.35))
				cl.name = "Converted_%d" % int(r["node"])
				_rune_info.add_child(cl)
			var gives: Array = (r.get("used", []) as Array) + (r.get("fallback", []) as Array)
			if carried:
				gives = ["its effect is carried by %s" % str(r.get("carried_by", ""))]
			if not gives.is_empty():
				_rune_info.add_child(UiWidgets.status_line("      " + ";  ".join(PackedStringArray(gives.map(func(v: Variant) -> String: return str(v)))), 12, UiTheme.TEXT_FAINT))

	# the picked rune
	if picked >= 0 and picked < RuneWord.size(word):
		var rid: String = RuneWord.node_id(word, picked)
		var d: Dictionary = rules.describe_node(word, picked, ctx)
		var sockets: int = int(d.get("sockets", -1))
		picked_box.add_child(UiTheme.section("Picked"))
		var prow := HBoxContainer.new()
		picked_box.add_child(prow)
		var pl := UiTheme.body("%s%s:  %s" % [RuneRules.rune_name(word, picked), ("   (%d of %d joined, ring %d)" % [int(d.get("used", 0)), sockets, RuneWord.ring(word, picked)]) if sockets >= 0 else "",
			str(GameData.rune(rid).get("meaning", ""))], 13, UiTheme.GOLD)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(pl)
		if picked > 0 and mode != "view":
			var rm: Button = UiWidgets.small_button("Take it out  (%s)" % Keybinds.binding_text("seal_delete"), func() -> void: remove_node.call_deferred(picked))
			rm.name = "RemoveRuneButton"
			prow.add_child(rm)
		if d.has("strength") and picked > 0:
			var stl: String = "strength x%.2f" % float(d["strength"])
			if float(d.get("converted", 0.0)) > 0.0:
				stl = "strength x%.2f + %.2f %s = x%.2f" % [float(d["path_strength"]), float(d["converted"]), str(d.get("converted_from", "")), float(d["strength"])]
			var stb := UiTheme.body("      " + stl, 13, RuneBoard.LINK_COLOURS["ionic"].lightened(0.35) if float(d.get("converted", 0.0)) > 0.0 else UiTheme.GOLD)
			stb.name = "PickedStrength"
			picked_box.add_child(stb)
		for k: int in RuneWord.neighbours(word, picked):
			var dl: Dictionary = rules.describe_link(word, picked, k, ctx)
			var flags: Array = dl.get("flags", [])
			picked_box.add_child(UiTheme.body("      %s%s" % [str(dl.get("label", "")), ("   (%s)" % ", ".join(PackedStringArray(flags.map(func(v: Variant) -> String: return str(v))))) if not flags.is_empty() else ""],
				13, (RuneBoard.LINK_COLOURS.get(str(dl.get("colour", "plain")), UiTheme.TEXT_DIM) as Color).lightened(0.2)))
	# the selected bond: its kind, who dominates, what it passes on, what it carries
	if picked_bond.x >= 0 and RuneWord.linked(word, picked_bond.x, picked_bond.y):
		var bd: Dictionary = rules.describe_link(word, picked_bond.x, picked_bond.y, ctx)
		var kc: Color = (RuneBoard.LINK_COLOURS.get(str(bd.get("colour", "plain")), UiTheme.TEXT_DIM) as Color).lightened(0.25)
		var bsec := UiTheme.section("Selected bond")
		bsec.name = "SelectedBond"
		picked_box.add_child(bsec)
		var brow := HBoxContainer.new()
		picked_box.add_child(brow)
		var bt := UiTheme.body("%s  -  %s" % [RuneRules.rune_name(word, picked_bond.x), RuneRules.rune_name(word, picked_bond.y)], 14, UiTheme.GOLD)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(bt)
		if mode != "view":
			var db: Button = UiWidgets.small_button("Delete bond  (%s)" % Keybinds.binding_text("seal_delete"), func() -> void: delete_bond.call_deferred(picked_bond.x, picked_bond.y))
			db.name = "DeleteBondButton"
			brow.add_child(db)
		var kind_l := UiTheme.body("      %s%s" % [str(bd.get("kind", "")).capitalize(), ("  -  " + str(bd.get("label", "")).get_slice(": ", 1)) if str(bd.get("label", "")).contains(": ") else ""], 13, kc)
		kind_l.name = "BondKind"
		picked_box.add_child(kind_l)
		if bd.has("transmission"):
			picked_box.add_child(UiTheme.body("      passes x%.2f inward (its kind factor, read from %s's side, further out)" % [float(bd["transmission"]),
				RuneRules.rune_name(word, int(bd.get("outer", picked_bond.y)))], 13, UiTheme.TEXT_DIM))
		var carries: Array = bd.get("carries", [])
		var cl2 := UiTheme.body("      carries " + (", ".join(PackedStringArray(carries.map(func(cc: Dictionary) -> String: return "%s (x%.2f)" % [str(cc["name"]), float(cc["strength"])])))
			if not carries.is_empty() else "nothing: no rune's strongest way to the skill runs through it"), 13, UiTheme.TEXT_DIM)
		cl2.name = "BondCarries"
		picked_box.add_child(cl2)
		for h: Variant in bd.get("hand_over", []):
			picked_box.add_child(UiTheme.body("      " + str(h), 13, RuneBoard.LINK_COLOURS["ionic"].lightened(0.35)))
		for fl: Variant in bd.get("flags", []):
			picked_box.add_child(UiTheme.body("      %s" % ("weakened: the affinities lean apart" if str(fl) == "weakened" else str(fl)), 12, UiTheme.BAD.lightened(0.2)))
	for n2: String in rules.notes():
		_rune_info.add_child(UiTheme.body(n2, 12, UiTheme.TEXT_FAINT))

	# the action row
	if _lock_button != null and is_instance_valid(_lock_button):
		if mode == "bind":
			var can: Dictionary = player.call("can_bind_seal")
			var ks2: Dictionary = player.call("seal_keystone")
			var need2: String = str(player.call("pending_tier", (player.get("abilities") as Array)[selected]))
			_lock_button.text = "Bind the %s and lock" % need2
			_lock_button.disabled = not bool(can["ok"])
			_lock_button.tooltip_text = "" if bool(can["ok"]) else str(can["text"])
			var odds: String = "%d%% it takes; a failed bind loses the construct, wounds you, and changes nothing in the word." % int(round(GameData.num("binding", "success_chance") * 100.0))
			if bool(can["ok"]):
				_lock_note.text = "Ready: every ring full, the word closed, the %s over ring %d - the level locks if the bind takes.  %s" % [
					str(ks2.get("label", "")), ctx.forming, odds]
			else:
				_lock_note.text = "Cannot bind yet: %s  %s" % [str(can["text"]), odds]
	elif _lock_note != null and is_instance_valid(_lock_note):
		_lock_note.text = ""
	if _clear_button != null and is_instance_valid(_clear_button):
		_clear_button.disabled = RuneWord.size(word) <= 1
	if _reset_button != null and is_instance_valid(_reset_button):
		_reset_button.disabled = not bool(player.call("draft_changed"))
	if _undo_button != null and is_instance_valid(_undo_button):
		_undo_button.disabled = not bool(player.call("can_undo"))
	if _redo_button != null and is_instance_valid(_redo_button):
		_redo_button.disabled = not bool(player.call("can_redo"))
	for chip: Control in _chips:
		chip.queue_redraw()


# --- right-hand panel --------------------------------------------------------------------

func _build_detail() -> void:
	var box: VBoxContainer = _detail
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Statuses" if glossary else "Ethercosm", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var gb: Button = UiWidgets.small_button("Back" if glossary else "Statuses", show_glossary.bind(not glossary))
	gb.name = "GlossaryButton"
	head.add_child(gb)
	head.add_child(UiWidgets.small_button("Skill tree  (%s)" % Keybinds.binding_text("skills"), func() -> void: game.call("open_skill_tree", false)))
	head.add_child(UiWidgets.small_button("Close  (%s)" % Keybinds.binding_text("ethercosm"), func() -> void: game.call("close_screen")))
	box.add_child(UiTheme.body("Every status a skill can leave on an enemy. Click a name to fold it." if glossary else "The inner space of your soul.", 14, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())
	# everything between the heading and the skill slots scrolls, so the slots stay in reach
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 14)          # clear of the scroll bar
	scroll.add_child(pad)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	pad.add_child(list)
	var held: Array = player.get("constructs")
	if glossary:
		for id: String in StatusText.all_ids():
			list.add_child(UiWidgets.StatusEntry.new(id, "", -1.0, true))
	else:
		_build_skill_detail(list, held)
	_build_slots(box, held)


## The glossary of every status (the header's "Statuses" button) in place of the skill.
func show_glossary(on: bool) -> void:
	glossary = on
	if _detail == null or not is_instance_valid(_detail):
		return
	for c: Node in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	_build_detail()


func _build_skill_detail(box: VBoxContainer, held: Array) -> void:
	# the soul at a glance
	var t: Dictionary = player.get("talent")
	box.add_child(UiWidgets.stat_row("Talent", str(t.get("name", "?")), UiTheme.GOLD))
	var pcts: Array = player.get("star_pct")
	for i: int in pcts.size():
		box.add_child(UiWidgets.Bar.new(float(pcts[i]) / 99.0, UiTheme.STAR.darkened(0.25),
			"star %d   %d%% capacity   %d essence" % [i + 1, int(float(pcts[i])), int(GameData.num("stars", "full_tank") * float(pcts[i]) / 100.0)], 22.0))
	box.add_child(UiTheme.body(str(player.call("aura_read")), 14, UiTheme.STAR))
	var rate: float = float(player.get("satellite_rate"))
	box.add_child(UiTheme.body(("A satellite orbits your star: +%d essence a second." % int(rate)) if rate > 0.0
		else "Nothing orbits your star. Essence returns only when you meditate.", 13, UiTheme.TEXT_DIM))
	box.add_child(UiTheme.rule())

	var abilities: Array = player.get("abilities")
	if abilities.is_empty():
		box.add_child(UiTheme.body("You know no abilities.", 15, UiTheme.TEXT_FAINT))
		return
	var st: Dictionary = abilities[selected]
	var ab: Dictionary = player.call("ability_stats", st)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	box.add_child(name_row)
	name_row.add_child(UiWidgets.Icon.new(str(ab.get("icon", "drop")), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3), 52.0))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 1)
	name_row.add_child(name_col)
	var nm := UiTheme.heading(str(ab.get("name", "?")), 22)
	nm.name = "SkillName"
	name_col.add_child(nm)
	name_col.add_child(UiTheme.body(UiTheme.verse_of(ab), 14, UiTheme.STAR))
	if str(ab.get("summary", "")) != "":
		box.add_child(UiTheme.body(str(ab["summary"]), 14, UiTheme.TEXT))

	var need: String = str(player.call("pending_tier", st))
	box.add_child(UiWidgets.Bar.new(float(st["progress"]) / 100.0, UiTheme.GOLD if need != "" else UiTheme.ESSENCE,
		("stage %d   -   bar full: %s" % [int(st["stage"]), ("ready for its level %d lock" % (int(st["stage"]) + 1))
			if bool((player.call("can_open_seal", selected) as Dictionary)["ok"]) else "its level %d lock needs a %s" % [int(st["stage"]) + 1, need]]) if need != ""
		else "stage %d   -   %d of %d runes lit" % [int(st["stage"]), int(float(st["progress"]) / 100.0 * RUNES_PER_STAGE), RUNES_PER_STAGE], 22.0))
	box.add_child(UiTheme.body("It grows by essence spent through it - fastest when something is trying to kill you.", 13, UiTheme.TEXT_FAINT))

	# the level lock: its state only, and the one way to it - the seal screen (Brent 2026-10-23: "No
	# binding the constructs on the main page, only with the runes"), open only with the bar full and a
	# construct of the tier carried (Brent 2026-10-24); otherwise what is missing, and no way in
	var lock: Dictionary = player.call("can_open_seal", selected)
	if bool(lock["ok"]):
		var lock_box := HBoxContainer.new()
		lock_box.name = "LockState"
		lock_box.add_theme_constant_override("separation", 8)
		box.add_child(lock_box)
		var carried: int = (player.call("construct_groups", need) as Array).reduce(func(a: int, g: Dictionary) -> int: return a + int(g["count"]), 0)
		var ready_l := UiTheme.body("Ready for its level %d lock: needs a %s (%d carried)." % [int(st["stage"]) + 1, need, carried], 14, UiTheme.GOLD)
		ready_l.name = "LockReady"
		ready_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_box.add_child(ready_l)
		var ob: Button = UiWidgets.small_button("Open the seal", func() -> void: open_seal.call_deferred(-1))
		ob.name = "OpenSealButton"
		ob.custom_minimum_size = Vector2(150, 36)
		lock_box.add_child(ob)
		box.add_child(UiTheme.body("On the seal screen every place of the new ring is filled and the %s set over it as its keystone; the bind locks the whole level or nothing." % need, 12, UiTheme.TEXT_FAINT))
	elif str(lock["reason"]) in ["no_construct", "bar"]:
		var miss := UiTheme.body(str(lock["text"]), 14, UiTheme.BAD.lightened(0.2) if str(lock["reason"]) == "no_construct" else UiTheme.TEXT_DIM)
		miss.name = "LockMissing"
		miss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(miss)

	# what it does: the skill's real numbers, and the statuses it leaves
	var det: Dictionary = player.call("skill_details", selected)
	var sealed: bool = bool(det.get("sealed", false))
	box.add_child(UiTheme.section("What it does"))
	if sealed:
		box.add_child(UiTheme.body("As sealed. Where the word changes a number, the skill's own is in brackets.", 12, UiTheme.TEXT_FAINT))
	var grid := GridContainer.new()
	grid.name = "SkillDetailRows"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for row: Dictionary in det.get("rows", []):
		var changed: bool = bool(row["changed"])
		var lab := UiTheme.body(str(row["label"]), 14, UiTheme.TEXT_DIM)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.name = "Row_" + str(row["label"]).replace(" ", "_").replace(",", "")
		grid.add_child(lab)
		var val_box := HBoxContainer.new()
		val_box.add_theme_constant_override("separation", 6)
		val_box.alignment = BoxContainer.ALIGNMENT_END
		grid.add_child(val_box)
		var val := UiTheme.body(str(row["after"]), 14, ((UiTheme.GOOD if bool(row["better"]) else UiTheme.BAD) if changed else UiTheme.TEXT))
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.name = "Value"
		val_box.add_child(val)
		if changed:
			var base := UiTheme.body("(%s)" % str(row["before"]), 13, UiTheme.TEXT_FAINT)
			base.autowrap_mode = TextServer.AUTOWRAP_OFF
			base.name = "Base"
			val_box.add_child(base)
	# the keystones in it: the construct set over each sealed ring, and what each does (weighted)
	var kss: Array = det.get("keystones", [])
	if not kss.is_empty():
		var kbox := VBoxContainer.new()
		kbox.name = "SkillKeystones"
		kbox.add_theme_constant_override("separation", 1)
		box.add_child(kbox)
		for kd: Dictionary in kss:
			var kl := UiTheme.body("Keystone, ring %d:  %s  (x%s)  -  %s" % [int(kd["ring"]), str(kd["label"]), RingRules._x(float(kd["weight"])),
				", ".join(PackedStringArray(kd["lines"]))], 13, UiTheme.STAR)
			kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			kbox.add_child(kl)
		kbox.add_child(UiTheme.body("The numbers above already hold them; a keystone's concept counts for more than a rune's.", 12, UiTheme.TEXT_FAINT))

	var applied: Array = det.get("statuses", [])
	var shown: Array[String] = []
	if not applied.is_empty():
		var ss := UiTheme.section("Statuses it leaves")
		ss.name = "SkillStatuses"
		box.add_child(ss)
		for s: Dictionary in applied:
			shown.append(str(s["id"]))
			box.add_child(UiWidgets.StatusEntry.new(str(s["id"]), _status_note(s), float(s["lasts"]), true,
				UiTheme.GOLD if bool(s["added"]) else UiTheme.TEXT_DIM))
	# statuses it reads, spends or keeps off, and any its words name: closed, a click opens each
	var others: Array[String] = []
	for id: Variant in (det.get("works_on", []) as Array) + StatusText.mentioned(str(ab.get("summary", ""))):
		if not shown.has(str(id)) and not others.has(str(id)):
			others.append(str(id))
	if not others.is_empty():
		var ws := UiTheme.section("Statuses it works on")
		ws.name = "SkillWorksOn"
		box.add_child(ws)
		for id2: String in others:
			box.add_child(UiWidgets.StatusEntry.new(id2, "", -1.0, false))

	# the word built in it
	box.add_child(UiTheme.rule())
	var word: Dictionary = player.call("ability_word", selected)
	var ctx: RuneContext = player.call("rune_context", selected)
	var rules: RuneRules = Runes.active()
	var runes_row := HBoxContainer.new()
	box.add_child(runes_row)
	var n_sealed: int = RuneWord.sealed(word)
	var runes_line := UiTheme.body(("Sealed: %d ring%s, %d rune%s" % [n_sealed, "" if n_sealed == 1 else "s", rules.used(word, ctx) - 1, "" if rules.used(word, ctx) == 2 else "s"]) if n_sealed > 0
		else "No word yet - runes are sealed at a binding", 14, UiTheme.GOLD if n_sealed > 0 else UiTheme.TEXT_DIM)
	runes_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runes_row.add_child(runes_line)
	var test: bool = bool(player.get("test_character"))
	if not bool(lock["ok"]):               # a skill whose lock can open has its one button, "Open the seal", above
		var rb: Button = UiWidgets.small_button("The seal", open_runes)
		rb.name = "RunesButton"
		runes_row.add_child(rb)
	var fx_lines: Array = player.call("rune_summary", selected)
	if not fx_lines.is_empty():
		box.add_child(UiWidgets.status_line("Sealed word:  " + ",  ".join(PackedStringArray(fx_lines.map(func(v: Variant) -> String: return str(v)))), 13, UiTheme.GOLD))
	var known: Array = player.get("known_runes")
	box.add_child(UiTheme.body("Every rune known (test character)." if test else "Runes known: %d of %d. Found in the Netherecho, in fights and on old stones." % [
		(player.call("rune_palette") as Array).filter(func(id: String) -> bool: return known.has(id)).size(), (player.call("rune_palette") as Array).size()], 12, UiTheme.TEXT_FAINT))


## How a skill applies one status, beside its name: how long, how many, its conditions, and what the
## sealed word changed (the skill's own value in brackets).
func _status_note(s: Dictionary) -> String:
	var parts: Array[String] = []
	var lasts: float = float(s["lasts"])
	var before: float = float(s.get("lasts_before", -1.0))
	if lasts > 0.0:
		parts.append("lasts %s s%s" % [StatusText._n(lasts), (" (%s s)" % StatusText._n(before)) if before >= 0.0 and absf(before - lasts) > 0.001 else ""])
	var n: int = int(s["stacks"])
	var nb: int = int(s.get("stacks_before", -1))
	if n > 1 or (nb >= 0 and nb != n):
		parts.append("%d stack%s a hit%s" % [n, "" if n == 1 else "s", (" (%d)" % nb) if nb >= 0 and nb != n else ""])
	for t: Variant in s.get("notes", []):
		parts.append(str(t))
	if bool(s.get("added", false)) and bool(player.call("word_locked", selected)):
		parts.append("from the sealed word")
	return ";  ".join(PackedStringArray(parts))


## The skill slots (and the constructs carried), under the scrolling part so they are always in reach.
func _build_slots(box: VBoxContainer, held: Array) -> void:
	var abilities: Array = player.get("abilities")
	if not abilities.is_empty() and not glossary:
		box.add_child(UiTheme.rule())
		box.add_child(UiTheme.body("Skill slot", 13, UiTheme.TEXT_DIM))
		var hotbar: Array = player.get("hotbar")
		var slots := HBoxContainer.new()
		slots.name = "SkillSlots"
		slots.add_theme_constant_override("separation", 6)
		box.add_child(slots)
		for i: int in hotbar.size():
			var here: bool = int(hotbar[i]) == selected
			var b: Button = UiWidgets.small_button(Keybinds.binding_text("ability_%d" % (i + 1)), func() -> void:
				player.call("assign_slot", i, selected)
				game.call("save_now")
				rebuild())
			b.name = "SlotButton_%d" % i
			b.custom_minimum_size = Vector2(44, 40)
			if here:
				b.add_theme_stylebox_override("normal", UiTheme.box(Color("3a3024"), UiTheme.GOLD, 2, 4, 10))
				b.add_theme_color_override("font_color", UiTheme.GOLD)
			slots.add_child(b)
		slots.add_child(UiWidgets.small_button("clear", func() -> void:
			player.call("unassign_ability", selected)
			game.call("save_now")
			rebuild()))
	if not held.is_empty():
		var names: Array[String] = []
		var groups: Array = player.call("construct_groups")
		if groups.size() > 6:          # a long list (a test character's): count by tier
			for tier: Variant in GameData.construct_tiers:
				var n: int = held.filter(func(c2: Dictionary) -> bool: return str(c2["tier"]) == str(tier)).size()
				if n > 0:
					names.append("%d %s" % [n, str(tier)])
		else:
			for g: Dictionary in groups:
				names.append(str(g["text"]))
		box.add_child(UiTheme.body("Constructs carried:  " + ", ".join(names), 13, UiTheme.GOLD))


# --- the drawn soul --------------------------------------------------------------------------

## What that bind would do to the ability: one "label  before -> after" line per number that moves.
func _bind_preview(st: Dictionary, concept: String) -> Control:
	var col := VBoxContainer.new()
	col.name = "BindPreview"
	col.add_theme_constant_override("separation", 4)
	var rows: Array[Dictionary] = player.call("preview_bind", st, concept)
	for r: Dictionary in rows:
		var line := HBoxContainer.new()
		col.add_child(line)
		var name_label := UiTheme.body("      %s" % str(r["label"]), 13, UiTheme.TEXT_DIM)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var change := UiTheme.body("%s  ->  %s" % [str(r["before"]), str(r["after"])], 13, UiTheme.GOOD if bool(r["better"]) else UiTheme.BAD)
		change.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(change)
	col.add_child(UiTheme.body("      %d%% chance it takes. A failed bind destroys the construct and wounds you." % int(round(GameData.num("binding", "success_chance") * 100.0)), 12, UiTheme.TEXT_FAINT))
	return col


class Cosmos extends Control:
	var screen: Control
	var _time := 0.0
	var _k := 1.0                    # how big each ability is drawn (smaller when there are many)
	var _nodes: Array = []          # [{pos, r, index}] for click testing
	var _hover := -1

	func _init(owner_screen: Control) -> void:
		screen = owner_screen
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_time += delta
		var m: Vector2 = get_local_mouse_position()
		_hover = -1
		for n: Dictionary in _nodes:
			if m.distance_to(n["pos"]) <= float(n["r"]):
				_hover = int(n["index"])
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# what is under the click itself (the hover is only refreshed once a frame)
			var at: int = -1
			for n: Dictionary in _nodes:
				if mb.position.distance_to(n["pos"]) <= float(n["r"]):
					at = int(n["index"])
			if at >= 0:
				screen.call("select", at)
				accept_event()

	func _draw() -> void:
		var player: Node = screen.get("player")
		var c: Vector2 = size * 0.5 + Vector2(0, -20.0)
		_draw_void(c)

		var abilities: Array = player.get("abilities")
		var orbit: float = minf(size.x, size.y) * 0.34
		# many abilities (a test character knows a whole affinity): a wider oval and smaller nodes
		var rx: float = orbit
		var ry: float = orbit
		_k = 1.0
		if abilities.size() > 8:
			rx = size.x * 0.41
			ry = size.y * 0.35
			var spacing: float = PI * (rx + ry) / float(abilities.size())
			_k = clampf(spacing / 182.0, 0.42, 1.0)
		var spots: Array[Vector2] = _oval_spots(c, rx, ry, abilities.size())
		_nodes.clear()
		# channels first, so nodes sit on top of them
		for i: int in abilities.size():
			var p: Vector2 = spots[i]
			draw_line(c, p, Color(UiTheme.ESSENCE, 0.18), 2.0, true)
			var t: float = fmod(_time * 0.35 + float(i) * 0.37, 1.0)
			draw_circle(c.lerp(p, t), 2.5, Color(UiTheme.ESSENCE.lightened(0.4), 0.7 * sin(t * PI)))

		_draw_stars(player, c)
		_draw_satellite(player, c)

		for i: int in abilities.size():
			var p2: Vector2 = spots[i]
			_draw_ability(player, abilities[i], i, p2)
			_nodes.append({"pos": p2, "r": 66.0 * _k, "index": i})

		_draw_spirit_sockets(Vector2(c.x, size.y - 46.0))
		UiDraw.text(self, Vector2(14.0, 24.0), "Click an ability to inspect it.", 13, UiTheme.TEXT_FAINT)

	## `n` points round an oval, evenly spaced along it (not by angle, which would crowd the ends),
	## the first at the top.
	func _oval_spots(c: Vector2, rx: float, ry: float, n: int) -> Array[Vector2]:
		var out: Array[Vector2] = []
		if n <= 0:
			return out
		var samples := 360
		var pts: Array[Vector2] = []
		var cum: Array[float] = [0.0]
		for s: int in samples + 1:
			var a: float = -PI / 2.0 + TAU * float(s) / float(samples)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
			if s > 0:
				cum.append(cum[s - 1] + pts[s].distance_to(pts[s - 1]))
		var total: float = cum[samples]
		var j := 0
		for i: int in n:
			var want: float = total * float(i) / float(n)
			while j < samples and cum[j + 1] < want:
				j += 1
			out.append(pts[j])
		return out

	func _draw_void(c: Vector2) -> void:
		UiDraw.void_field(self, size, c, _time)

	func _draw_stars(player: Node, c: Vector2) -> void:
		var pcts: Array = player.get("star_pct")
		var n: int = pcts.size()
		for i: int in n:
			var off := Vector2((float(i) - float(n - 1) * 0.5) * 124.0, 0.0)
			var p: Vector2 = c + off
			var frac: float = float(pcts[i]) / 99.0
			var r: float = 16.0 + 26.0 * sqrt(frac)          # a baby star is visibly small
			var pulse: float = 1.0 + 0.04 * sin(_time * 2.0 + float(i))
			for g: int in 5:
				draw_circle(p, r * pulse * (2.2 - g * 0.25), Color(UiTheme.STAR, 0.035 + g * 0.012))
			draw_circle(p, r * pulse, Color("f4efff"))
			draw_circle(p, r * pulse * 0.72, Color(1, 1, 1))
			UiDraw.ring(self, p, r + 12.0, frac, UiTheme.STAR)
			UiDraw.text(self, Vector2(p.x - 60.0, p.y + r + 34.0), "star %d   %d%%" % [i + 1, int(float(pcts[i]))], 13, UiTheme.STAR, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		var t: Dictionary = player.get("talent")
		UiDraw.text(self, Vector2(c.x - 200.0, c.y - 78.0), str(t.get("name", "")), 16, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 400.0)

	func _draw_satellite(player: Node, c: Vector2) -> void:
		var rate: float = float(player.get("satellite_rate"))
		if rate <= 0.0:
			return
		var rx := 118.0 + 62.0 * float((player.get("star_pct") as Array).size() - 1)
		var ry := 46.0
		var prev := c + Vector2(rx, 0.0)
		for i: int in range(1, 49):
			var a: float = TAU * float(i) / 48.0
			var p := c + Vector2(cos(a) * rx, sin(a) * ry)
			draw_line(prev, p, Color(UiTheme.GOLD, 0.22), 1.0, true)
			prev = p
		var a2: float = _time * 0.9
		var s := c + Vector2(cos(a2) * rx, sin(a2) * ry)
		draw_circle(s, 9.0, Color(UiTheme.GOLD, 0.25))
		draw_circle(s, 5.0, UiTheme.GOLD.lightened(0.3))
		UiDraw.text(self, s + Vector2(10.0, -8.0), "+%d/s" % int(rate), 12, UiTheme.GOLD)

	func _draw_ability(player: Node, st: Dictionary, index: int, p: Vector2) -> void:
		var ab: Dictionary = player.call("ability_stats", st)
		var is_selected: bool = index == int(screen.get("selected"))
		var need: String = str(player.call("pending_tier", st))
		var stage: int = int(st["stage"])
		var lit: int = int(float(st["progress"]) / 100.0 * RUNES_PER_STAGE)
		var k: float = _k
		var ring_r: float = 52.0 * k

		# completed stages: solid rings, each crowned with its keystone (the construct set over it)
		var sealed_w: Dictionary = st.get("word", {})
		for s: int in stage:
			var rr: float = ring_r + (12.0 + s * 9.0) * k
			draw_arc(p, rr, 0, TAU, 64, UiTheme.GOLD.darkened(0.25), 2.0, true)
			var ks: Dictionary = RuneWord.keystone(sealed_w, s + 1)
			if not ks.is_empty():
				var ga: float = -PI / 2.0 + s * 0.5
				UiDraw.icon(self, "gem", p + Vector2(cos(ga), sin(ga)) * rr, 13.0 * k, UiTheme.STAR if str(ks["tier"]) != "vestige" else UiTheme.GOLD)

		# the current runechain - or, with a locked rune word, that word repeated round the ring
		draw_arc(p, ring_r, 0, TAU, 64, Color(1, 1, 1, 0.06), 12.0 * k, true)
		var word: Dictionary = player.call("ability_word", index)
		if RuneWord.is_locked(word) and RuneWord.size(word) > 1:
			_draw_word_chain(p, ring_r, word, GameData.affinity_color(str(ab.get("affinity", ""))))
		var rng := RandomNumberGenerator.new()
		for i: int in (0 if RuneWord.is_locked(word) else RUNES_PER_STAGE):
			var a: float = -PI / 2.0 + TAU * float(i) / float(RUNES_PER_STAGE)
			var on: bool = i < lit
			var col: Color = (UiTheme.GOLD if need != "" else UiTheme.ESSENCE.lightened(0.45)) if on else Color(0.32, 0.3, 0.3)
			if need != "":
				col = col.lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(_time * 4.0 + float(i) * 0.4))
			rng.seed = hash(str(st["id"])) + stage * 977 + i * 31
			if k >= 0.8:
				_draw_rune(p + Vector2(cos(a), sin(a)) * ring_r, a + PI / 2.0, rng, col, on)
			else:
				draw_circle(p + Vector2(cos(a), sin(a)) * ring_r, 2.2, col)       # too small for glyphs: a bead each

		# the ability itself
		draw_circle(p, 36.0 * k, Color(0, 0, 0, 0.7))
		draw_circle(p, 33.0 * k, UiTheme.PANEL_HI if not is_selected else Color("3a3024"))
		draw_arc(p, 33.0 * k, 0, TAU, 48, UiTheme.GOLD if (is_selected or _hover == index) else UiTheme.BRONZE, 2.0 if is_selected else 1.5, true)
		UiDraw.icon(self, str(ab.get("icon", "drop")), p, 34.0 * k, GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))
		var below: float = ring_r + (30.0 + stage * 9.0) * k
		UiDraw.text(self, Vector2(p.x - 110.0, p.y + below), str(ab.get("name", "?")), 15 if k >= 0.8 else 13, UiTheme.TEXT if not is_selected else UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		var sub: String = ("lock %d: needs a %s" % [stage + 1, need]) if need != "" else "stage %d" % stage
		if k >= 0.8 or need != "":
			UiDraw.text(self, Vector2(p.x - 110.0, p.y + below + 17.0), sub, 12, UiTheme.GOLD if need != "" else UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		# which skill slot it sits in
		var hotbar: Array = player.get("hotbar")
		var slot: int = hotbar.find(index)
		if slot >= 0:
			var kp := p + Vector2(26.0, -26.0) * k
			draw_circle(kp, 11.0, UiTheme.INSET)
			draw_arc(kp, 11.0, 0, TAU, 20, UiTheme.GOLD, 1.5, true)
			UiDraw.text(self, Vector2(kp.x - 11.0, kp.y + 5.0), Keybinds.binding_text("ability_%d" % (slot + 1)), 13, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 22.0)

	## A locked word as a chain: its real glyphs, copy after copy round the ring, each linked to
	## the next, turning slowly, with a soft glow of the skill's colour under it.
	func _draw_word_chain(p: Vector2, r: float, word: Dictionary, col: Color) -> void:
		var seq: Array = RuneWord.nodes(word)
		var n: int = seq.size()
		var total: int = maxi(1, int(TAU * r / 21.0) / n) * n
		var rot: float = _time * 0.08
		draw_arc(p, r, 0, TAU, 64, Color(col, 0.16), 14.0, true)
		draw_arc(p, r - 9.0, 0, TAU, 64, Color(UiTheme.GOLD, 0.22), 1.0, true)
		draw_arc(p, r + 9.0, 0, TAU, 64, Color(UiTheme.GOLD, 0.22), 1.0, true)
		var gap: float = 7.0 / r
		for j: int in total:
			var a: float = -PI / 2.0 + rot + TAU * float(j) / float(total)
			var nxt: float = -PI / 2.0 + rot + TAU * float(j + 1) / float(total)
			var rid: String = str(seq[j % n])
			var rune: Dictionary = GameData.rune(rid)
			var aff: String = str(rune.get("affinity", ""))
			var gc: Color = GameData.affinity_color(aff).lightened(0.45) if aff != "" else UiTheme.STAR
			UiDraw.rune_glyph(self, p + Vector2(cos(a), sin(a)) * r, rid, str(rune.get("character", "")), 12, gc)
			draw_arc(p, r, a + gap, nxt - gap, 4, Color(UiTheme.GOLD, 0.6) if j % n == n - 1 else Color(gc, 0.35), 1.1, true)

	## One original glyph: a few strokes between points of a 3x3 grid, rotated to face outward.
	func _draw_rune(at: Vector2, angle: float, rng: RandomNumberGenerator, col: Color, lit: bool) -> void:
		UiDraw.rune_strokes(self, at, angle, rng, col, lit)

	func _draw_spirit_sockets(at: Vector2) -> void:
		for i: int in 3:
			var p := at + Vector2((float(i) - 1.0) * 70.0, 0.0)
			draw_arc(p, 18.0, 0, TAU, 32, UiTheme.BRONZE_DIM, 1.5, true)
			draw_arc(p, 12.0, 0, TAU, 24, Color(1, 1, 1, 0.05), 1.0, true)
		UiDraw.text(self, Vector2(at.x - 300.0, at.y + 36.0), "Spirit abilities  -  none held. Each one compresses your latent aura by a third.", 12, UiTheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 600.0)
