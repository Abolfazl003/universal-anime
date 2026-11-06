extends Control
## Versus setup: both slots, control type, rounds, timer, AI difficulty, stage.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")

var _content: VBoxContainer


func _ready() -> void:
	theme = UIKit.theme()
	_build()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("setup.title"),
		"%s — %s" % [Loc.t("app.phase"), Loc.t("setup.lab_banner")])

	var body := UIKit.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	body.add_child(_slot_panel(1))
	body.add_child(_slot_panel(2))

	var options := UIKit.panel()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(options)
	var options_column := UIKit.vbox(10)
	options.add_child(options_column)

	options_column.add_child(_stepper(Loc.t("setup.rounds"), str(Session.rounds_to_win), _rounds_delta))
	options_column.add_child(_stepper(Loc.t("setup.timer"),
		Loc.t("setup.timer_on") if Session.timer_enabled else Loc.t("setup.timer_off"), _toggle_timer))
	var difficulty_names: Array[String] = [Loc.t("setup.easy"), Loc.t("setup.normal"), Loc.t("setup.hard")]
	options_column.add_child(_stepper(Loc.t("setup.difficulty"),
		difficulty_names[clampi(Session.ai_difficulty, 0, 2)], _difficulty_delta))
	var stage: Dictionary = GameData.stage(Session.stage_id)
	var stage_name: String = str(stage.get("name", Loc.t("common.none")))
	var stage_status: String = str(stage.get("status", "PENDING"))
	var stage_row := UIKit.hbox(10)
	stage_row.add_child(UIKit.label(Loc.t("setup.stage"), 0.95, UIKit.MUTED))
	stage_row.add_child(UIKit.label("%s (%s)" % [stage_name, stage_status], 0.9, UIKit.TEXT))
	stage_row.add_child(UIKit.spacer(0))
	stage_row.add_child(UIKit.tiny_button(Loc.t("stage.title"), _open_stage_select, 200))
	options_column.add_child(stage_row)
	options_column.add_child(UIKit.expander())
	options_column.add_child(UIKit.label(Loc.t("stage.no_approved"), 0.72, UIKit.MUTED))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("common.back"), _back, 260))
	var start_button := UIKit.button(Loc.t("setup.start"), _start, 320, true)
	start_button.disabled = not Session.is_versus_ready()
	footer.add_child(start_button)
	if not Session.is_versus_ready():
		footer.add_child(UIKit.label(Loc.t("setup.need_two"), 0.85, UIKit.WARN))
	UIKit.focus_first(self)


func _slot_panel(slot: int) -> PanelContainer:
	var panel := UIKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIKit.vbox(8)
	panel.add_child(column)
	column.add_child(UIKit.label(Loc.t("setup.p1") if slot == 1 else Loc.t("setup.p2"), 1.1, UIKit.ACCENT))
	var entry: Dictionary = Session.get_slot(slot)
	var name_text: String = str(entry.get("name", ""))
	if name_text.is_empty():
		name_text = Loc.t("common.none")
	var temporary: bool = bool(entry.get("temporary", false))
	var name_row := UIKit.hbox(8)
	column.add_child(name_row)
	name_row.add_child(UIKit.label(name_text, 1.2, UIKit.TEXT))
	if temporary:
		name_row.add_child(UIKit.tag(Loc.t("common.temporary"), UIKit.WARN))
	column.add_child(UIKit.label(
		Loc.t("detail.temporary_note") if temporary else Loc.t("common.playable"), 0.75, UIKit.MUTED))
	column.add_child(UIKit.tiny_button(Loc.t("setup.select_fighter"),
		func() -> void: _pick(slot), 240))
	var control_row := UIKit.hbox(8)
	column.add_child(control_row)
	control_row.add_child(UIKit.label(Loc.t("setup.control"), 0.85, UIKit.MUTED))
	var control: int = Session.p1_control if slot == 1 else Session.p2_control
	var control_name: String = "HUMAN" if control == Consts.PlayerControl.HUMAN else "AI"
	control_row.add_child(UIKit.tiny_button(control_name, func() -> void: _toggle_control(slot), 160))
	column.add_child(UIKit.expander())
	column.add_child(UIKit.label("LAB:" if temporary else "", 0.7, UIKit.MUTED))
	return panel


func _stepper(title: String, value: String, callback: Callable) -> HBoxContainer:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label(title, 0.9, UIKit.MUTED))
	row.add_child(UIKit.tiny_button("−", callback.bind(-1), 60))
	row.add_child(UIKit.label(value, 0.95, UIKit.TEXT))
	row.add_child(UIKit.tiny_button("+", callback.bind(1), 60))
	return row


func _rounds_delta(delta: int) -> void:
	Session.rounds_to_win = clampi(Session.rounds_to_win + delta, 1, 5)
	_rebuild()


func _toggle_timer(_delta: int = 0) -> void:
	Session.timer_enabled = not Session.timer_enabled
	_rebuild()


func _difficulty_delta(delta: int) -> void:
	Session.ai_difficulty = clampi(Session.ai_difficulty + delta, 0, 2)
	_rebuild()


func _toggle_control(slot: int) -> void:
	if slot == 1:
		Session.p1_control = Consts.PlayerControl.AI if Session.p1_control == Consts.PlayerControl.HUMAN else Consts.PlayerControl.HUMAN
	else:
		Session.p2_control = Consts.PlayerControl.HUMAN if Session.p2_control == Consts.PlayerControl.AI else Consts.PlayerControl.AI
	_rebuild()


func _pick(slot: int) -> void:
	SceneRouter.change_scene("res://scenes/menus/character_select.tscn", {"purpose": "slot", "slot": slot})


func _open_stage_select() -> void:
	SceneRouter.change_scene("res://scenes/menus/stage_select.tscn")


func _start() -> void:
	if not Session.is_versus_ready():
		return
	var both_lab: bool = bool(Session.p1.get("temporary", false)) and bool(Session.p2.get("temporary", false))
	Session.mode = Consts.Mode.LAB if both_lab else Consts.Mode.VERSUS
	if Session.stage_id.is_empty():
		Session.stage_id = "lab_arena"
	SceneRouter.change_scene("res://scenes/versus/versus_stage.tscn")


func _back() -> void:
	SceneRouter.change_scene("res://scenes/menus/mode_select.tscn")
