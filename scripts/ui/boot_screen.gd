extends Control
## Boot / data report screen.
## It states plainly what the build actually loaded. No character count is
## claimed unless it came from the file.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")

var _column: VBoxContainer
var _status_panel: PanelContainer


func _ready() -> void:
	theme = UIKit.theme()
	_build()
	await get_tree().process_frame
	_fill_report()


func _build() -> void:
	_column = UIKit.screen_root(self)
	var header := UIKit.vbox(4)
	header.add_child(UIKit.label(Loc.t("app.title"), 2.6, UIKit.ACCENT))
	header.add_child(UIKit.label(Loc.t("app.tagline"), 1.0, UIKit.MUTED))
	header.add_child(UIKit.label(Loc.t("app.phase"), 0.85, UIKit.WARN))
	_column.add_child(header)
	_column.add_child(UIKit.divider())

	var body := UIKit.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(body)

	var report_panel := UIKit.panel()
	report_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(report_panel)
	var report_column := UIKit.vbox(8)
	report_panel.add_child(report_column)
	report_column.add_child(UIKit.label(Loc.t("boot.report_title"), 1.2, UIKit.TEXT))
	_status_panel = PanelContainer.new()
	_status_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_column.add_child(_status_panel)

	var actions := UIKit.vbox(10)
	actions.custom_minimum_size = Vector2(420, 0)
	body.add_child(actions)
	actions.add_child(UIKit.button(Loc.t("boot.ready"), _open_menu, 360, true))
	actions.add_child(UIKit.button(Loc.t("menu.reference_gallery"), _open_gallery, 360))
	actions.add_child(UIKit.button(Loc.t("menu.settings"), _open_settings, 360))
	actions.add_child(UIKit.button(Loc.t("menu.quit"), _quit, 360))
	actions.add_child(UIKit.spacer(12))
	actions.add_child(UIKit.label(Loc.t("menu.debug_hint"), 0.75, UIKit.MUTED))


func _fill_report() -> void:
	if _status_panel == null:
		return
	for child in _status_panel.get_children():
		child.queue_free()
	var box := UIKit.vbox(6)
	_status_panel.add_child(box)

	var stats: Dictionary = GameData.stats()
	var validation: Dictionary = GameData.validation_report
	var report: Dictionary = GameData.get_report()
	var source_status: String = str(stats.get("source_status", "UNKNOWN"))
	var source_color: Color = UIKit.OK if int(stats.get("existing", 0)) > 0 else UIKit.WARN

	box.add_child(UIKit.key_value_row(Loc.t("boot.engine"), "Godot %s" % Engine.get_version_info().get("string", "?")))
	box.add_child(UIKit.key_value_row(Loc.t("boot.build"), str(ProjectSettings.get_setting("application/config/version", "?"))))
	box.add_child(UIKit.key_value_row(Loc.t("boot.data_source"), "%s — %s" % [
		str(stats.get("source_path", "(none)")), source_status
	]))
	box.add_child(UIKit.key_value_row(Loc.t("boot.records"), "%d  (capacity target %d)" % [
		int(stats.get("existing", 0)), int(stats.get("capacity_target", 600))
	]))
	box.add_child(UIKit.key_value_row(Loc.t("boot.playable"), "%d" % int(stats.get("playable", 0))))
	box.add_child(UIKit.key_value_row("Series", "%d distinct" % int(stats.get("distinct_series", 0))))
	box.add_child(UIKit.key_value_row("Movesets", "%d" % GameData.moveset_count()))
	box.add_child(UIKit.key_value_row("Stages", "%d" % GameData.stage_count()))
	box.add_child(UIKit.key_value_row("Save", "%s — %s" % [SaveManager.last_load_status, SaveManager.last_load_detail]))
	box.add_child(UIKit.key_value_row("Language", "en / fa (UI strings external)"))
	box.add_child(UIKit.divider())

	var errors: Array = validation.get("errors", [])
	var warnings: Array = validation.get("warnings", [])
	if errors.is_empty() and warnings.is_empty():
		box.add_child(UIKit.label("Validator: no duplicate ids, no missing required fields.", 0.9, UIKit.OK))
	else:
		box.add_child(UIKit.label("Validator: %d error(s), %d warning(s)" % [errors.size(), warnings.size()], 0.9, UIKit.DANGER))
		var shown: int = 0
		for message in errors + warnings:
			if shown >= 8:
				box.add_child(UIKit.label("… %d more" % (errors.size() + warnings.size() - 8), 0.8, UIKit.MUTED))
				break
			box.add_child(UIKit.label("· %s" % str(message), 0.8, UIKit.MUTED))
			shown += 1

	if int(stats.get("existing", 0)) == 0:
		var warning := UIKit.panel(Color(0.16, 0.13, 0.05), UIKit.WARN)
		var warning_column := UIKit.vbox(6)
		warning.add_child(warning_column)
		warning_column.add_child(UIKit.label("CHARACTER DATA NOT PRESENT", 1.0, UIKit.WARN))
		warning_column.add_child(UIKit.label(Loc.t("chars.empty_body"), 0.8, UIKit.TEXT))
		box.add_child(warning)

	if not load_errors_empty(report):
		for error in report.get("load_errors", []):
			box.add_child(UIKit.label("· %s" % str(error), 0.8, UIKit.DANGER))

	_box_tint(source_color)


func load_errors_empty(_report: Dictionary) -> bool:
	return (_report.get("load_errors", []) as Array).is_empty()


func _box_tint(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.PANEL
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_status_panel.add_theme_stylebox_override("panel", style)


func _open_menu() -> void:
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)


func _open_gallery() -> void:
	SceneRouter.change_scene("res://scenes/menus/reference_gallery.tscn")


func _open_settings() -> void:
	SceneRouter.change_scene("res://scenes/menus/settings.tscn")


func _quit() -> void:
	get_tree().quit()
