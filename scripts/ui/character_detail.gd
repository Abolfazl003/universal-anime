extends Control
## Character detail. Shows exactly what the source record contains; missing
## fields stay "unknown" and are never filled in by the game.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")

var _character_id: int = -1


func _ready() -> void:
	theme = UIKit.theme()
	_character_id = int(SceneRouter.payload().get("id", -1))
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	var record: Dictionary = GameData.get_character(_character_id)
	UIKit.header(column, Loc.t("detail.title"), str(record.get("name", "") if not record.is_empty() else ""))
	if record.is_empty():
		column.add_child(UIKit.label(Loc.t("chars.empty_title"), 1.0, UIKit.MUTED))
		column.add_child(UIKit.button(Loc.t("common.back"), _back, 220))
		return

	var body := UIKit.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var info := UIKit.panel()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var info_column := UIKit.vbox(6)
	info.add_child(info_column)
	info_column.add_child(UIKit.label(str(record.get("name", "")), 1.5, UIKit.TEXT))
	info_column.add_child(UIKit.divider())
	for pair in [
		[Loc.t("detail.series"), str(record.get("series", ""))],
		[Loc.t("detail.city"), str(record.get("city", ""))],
		[Loc.t("detail.element"), str(record.get("element", ""))],
		[Loc.t("detail.role"), str(record.get("role", ""))],
		[Loc.t("detail.rarity"), str(record.get("rarity", ""))],
		[Loc.t("detail.world"), str(record.get("world", "")) if record.get("has_world", false) else Loc.t("common.unknown")],
		["ID", str(record.get("id", ""))],
	]:
		var value: String = str(pair[1])
		info_column.add_child(UIKit.key_value_row(str(pair[0]), value if not value.is_empty() else Loc.t("common.unknown")))
	var status_row := UIKit.hbox(10)
	info_column.add_child(status_row)
	status_row.add_child(UIKit.label(Loc.t("detail.status"), 0.95, UIKit.MUTED))
	status_row.add_child(UIKit.tag(str(record.get("status_name", "DATA_ONLY")),
		UIKit.status_color(int(record.get("status", 0)))))
	if int(record.get("status", 0)) < Consts.Status.REFERENCE_APPROVED:
		info_column.add_child(UIKit.label(Loc.t("detail.not_approved"), 0.85, UIKit.WARN))
	info_column.add_child(UIKit.spacer(8))
	info_column.add_child(UIKit.label(Loc.t("detail.source_note"), 0.78, UIKit.MUTED))

	var powers_panel := UIKit.panel()
	powers_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(powers_panel)
	var powers_column := UIKit.vbox(8)
	powers_panel.add_child(powers_column)
	powers_column.add_child(UIKit.label(Loc.t("detail.powers"), 1.0, UIKit.TEXT))
	var powers: Array = record.get("powers", [])
	if powers.is_empty():
		powers_column.add_child(UIKit.label(Loc.t("detail.no_powers"), 0.85, UIKit.MUTED))
	for power in powers:
		var power_column := UIKit.vbox(2)
		powers_column.add_child(power_column)
		power_column.add_child(UIKit.label(str((power as Dictionary).get("name", "?")), 1.0, UIKit.ACCENT))
		var description: String = str((power as Dictionary).get("description", ""))
		if not description.is_empty():
			power_column.add_child(UIKit.label(description, 0.8, UIKit.MUTED))
	var moveset: Dictionary = GameData.moveset_for_character(int(record.get("id", -1)))
	powers_column.add_child(UIKit.divider())
	powers_column.add_child(UIKit.label(Loc.t("detail.moveset"), 0.95, UIKit.MUTED))
	if moveset.is_empty():
		powers_column.add_child(UIKit.label(Loc.t("detail.moveset_none"), 0.8, UIKit.WARN))
	else:
		powers_column.add_child(UIKit.label(str(moveset.get("display_name", "")), 0.85, UIKit.TEXT))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("common.back"), _back, 240))
	var select_button := UIKit.button(Loc.t("chars.select"), _select, 240, true)
	select_button.disabled = not GameData.is_selectable(record)
	footer.add_child(select_button)
	UIKit.focus_first(self)


func _back() -> void:
	SceneRouter.go_back()


func _select() -> void:
	var record: Dictionary = GameData.get_character(_character_id)
	if record.is_empty():
		return
	Session.p1 = Session.character_entry(record)
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")
