extends Control
## Mode select: versus, dungeon, mechanics lab.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")


func _ready() -> void:
	theme = UIKit.theme()
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("mode.title"), Loc.t("mode.subtitle"))

	var cards := UIKit.hbox(24)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)

	cards.add_child(_card(Loc.t("menu.versus"), Loc.t("menu.versus_desc"), UIKit.ACCENT, _start_versus))
	cards.add_child(_card(Loc.t("menu.dungeon"), Loc.t("menu.dungeon_desc"), UIKit.INFO, _start_dungeon))
	cards.add_child(_card(Loc.t("menu.lab"), Loc.t("menu.lab_desc"), UIKit.WARN, _start_lab))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("common.back"), func() -> void: SceneRouter.change_scene(SceneRouter.MAIN_MENU), 260))
	footer.add_child(UIKit.label(Loc.t("menu.debug_hint"), 0.75, UIKit.MUTED))
	UIKit.focus_first(self)


func _card(title: String, description: String, color: Color, callback: Callable) -> PanelContainer:
	var panel := UIKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := UIKit.vbox(12)
	panel.add_child(column)
	var accent_bar := ColorRect.new()
	accent_bar.color = color
	accent_bar.custom_minimum_size = Vector2(0, 6)
	column.add_child(accent_bar)
	column.add_child(UIKit.label(title, 1.6, color))
	column.add_child(UIKit.label(description, 0.9, UIKit.MUTED))
	column.add_child(UIKit.expander())
	column.add_child(UIKit.button(Loc.t("common.start"), callback, 240, true))
	return panel


func _start_versus() -> void:
	Session.mode = Consts.Mode.VERSUS
	Session.p1 = {}
	Session.p2 = {}
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")


func _start_dungeon() -> void:
	Session.mode = Consts.Mode.DUNGEON
	Session.dungeon_seed = int(Time.get_unix_time_from_system()) % 100000
	Session.p1 = Session.lab_entry("lab_dummy_a", "LAB AVATAR (TEMP)")
	Session.p1_control = Consts.PlayerControl.HUMAN
	SceneRouter.change_scene("res://scenes/dungeon/dungeon_run.tscn", {"seed": Session.dungeon_seed})


func _start_lab() -> void:
	Session.mode = Consts.Mode.LAB
	Session.p1 = Session.lab_entry("lab_dummy_a", "LAB DUMMY A")
	Session.p1_control = Consts.PlayerControl.HUMAN
	Session.p2 = Session.lab_entry("lab_dummy_b", "LAB DUMMY B")
	Session.p2_control = Consts.PlayerControl.AI
	Session.stage_id = "lab_arena"
	Session.rounds_to_win = 2
	Session.timer_enabled = true
	Session.round_time = 99.0
	SceneRouter.change_scene("res://scenes/versus/versus_stage.tscn")
