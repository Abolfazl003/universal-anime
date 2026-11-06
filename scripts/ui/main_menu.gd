extends Control
## Main menu.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _column: VBoxContainer


func _ready() -> void:
	theme = UIKit.theme()
	Loc.language_changed.connect(func(_lang: String) -> void: _rebuild())
	_build()
	UIKit.focus_first(self)


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	_column = UIKit.screen_root(self)
	var header := UIKit.vbox(2)
	header.add_child(UIKit.label(Loc.t("app.title"), 3.0, UIKit.ACCENT))
	header.add_child(UIKit.label(Loc.t("app.tagline"), 1.0, UIKit.MUTED))
	header.add_child(UIKit.label(Loc.t("app.phase"), 0.85, UIKit.WARN))
	_column.add_child(header)
	_column.add_child(UIKit.divider())

	var body := UIKit.hbox(36)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(body)

	var menu_column := UIKit.vbox(10)
	menu_column.custom_minimum_size = Vector2(480, 0)
	body.add_child(menu_column)
	menu_column.add_child(UIKit.button(Loc.t("menu.versus"), _open_mode_select, 420, true))
	menu_column.add_child(UIKit.button(Loc.t("menu.dungeon"), _open_dungeon, 420, true))
	menu_column.add_child(UIKit.button(Loc.t("menu.lab"), _open_lab, 420, true))
	menu_column.add_child(UIKit.divider())
	menu_column.add_child(UIKit.button(Loc.t("menu.characters"), _open_characters, 420))
	menu_column.add_child(UIKit.button(Loc.t("menu.reference_gallery"), _open_gallery, 420))
	menu_column.add_child(UIKit.button(Loc.t("menu.settings"), _open_settings, 420))
	menu_column.add_child(UIKit.button(Loc.t("menu.controls"), _open_controls, 420))
	menu_column.add_child(UIKit.button(Loc.t("menu.anim_review"), _open_review, 420))
	menu_column.add_child(UIKit.button(Loc.t("menu.quit"), _quit, 420))

	var info := UIKit.vbox(14)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)

	var stats: Dictionary = GameData.stats()
	info.add_child(UIKit.label(Loc.t("menu.roster", [
		str(stats.get("existing", 0)), str(stats.get("playable", 0)), str(stats.get("capacity_target", 600))
	]), 0.95, UIKit.MUTED))

	if int(stats.get("existing", 0)) == 0:
		var warning := UIKit.panel(Color(0.16, 0.13, 0.05), UIKit.WARN)
		var warning_column := UIKit.vbox(6)
		warning.add_child(warning_column)
		warning_column.add_child(UIKit.label(Loc.t("menu.data_missing"), 1.0, UIKit.WARN))
		warning_column.add_child(UIKit.label(Loc.t("chars.empty_body"), 0.78, UIKit.MUTED))
		info.add_child(warning)

	var lab_panel := UIKit.panel()
	var lab_column := UIKit.vbox(6)
	lab_panel.add_child(lab_column)
	info.add_child(lab_panel)
	lab_column.add_child(UIKit.label("WHAT THIS BUILD ACTUALLY CONTAINS", 1.05, UIKit.TEXT))
	lab_column.add_child(UIKit.label(
		"• Playable: side-view combat between two temporary dummies (lab).\n"
		+ "• Playable: one seeded dungeon run with rooms, doors, a trap, loot and a boss.\n"
		+ "• Not playable: any anime character — no character data, no approved reference, no approved art.\n"
		+ "• No character is claimed as implemented, approved or playable.", 0.82, UIKit.MUTED))
	info.add_child(UIKit.expander())
	info.add_child(UIKit.label(Loc.t("menu.debug_hint"), 0.75, UIKit.MUTED))


func _open_mode_select() -> void:
	SceneRouter.change_scene("res://scenes/menus/mode_select.tscn", {"preselect": "versus"})


func _open_dungeon() -> void:
	Session.mode = 2
	Session.dungeon_seed = int(Time.get_unix_time_from_system()) % 100000
	Session.p1 = Session.lab_entry("lab_dummy_a", "LAB AVATAR (TEMP)")
	Session.p1_control = 0
	SceneRouter.change_scene("res://scenes/dungeon/dungeon_run.tscn", {"seed": Session.dungeon_seed})


func _open_lab() -> void:
	Session.mode = 3
	Session.p1 = Session.lab_entry("lab_dummy_a", "LAB DUMMY A")
	Session.p1_control = 0
	Session.p2 = Session.lab_entry("lab_dummy_b", "LAB DUMMY B")
	Session.p2_control = 1
	Session.stage_id = "lab_arena"
	Session.rounds_to_win = 2
	Session.timer_enabled = true
	Session.round_time = 99.0
	SceneRouter.change_scene("res://scenes/versus/versus_stage.tscn")


func _open_characters() -> void:
	SceneRouter.change_scene("res://scenes/menus/character_select.tscn", {"purpose": "browse"})


func _open_gallery() -> void:
	SceneRouter.change_scene("res://scenes/menus/reference_gallery.tscn")


func _open_settings() -> void:
	SceneRouter.change_scene("res://scenes/menus/settings.tscn")


func _open_review() -> void:
	SceneRouter.change_scene("res://scenes/ui/anim_review.tscn")


func _open_controls() -> void:
	SceneRouter.change_scene("res://scenes/menus/controls.tscn")


func _quit() -> void:
	get_tree().quit()
