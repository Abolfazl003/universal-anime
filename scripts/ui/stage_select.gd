extends Control
## Stage select. Every stage carries an explicit approval status; only temporary
## or approved stages may be picked, and unapproved ones are visibly labelled.

const UIKit = preload("res://scripts/ui/ui_kit.gd")


func _ready() -> void:
	theme = UIKit.theme()
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("stage.title"), Loc.t("stage.no_approved"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := UIKit.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var stages: Array = GameData.all_stages()
	if stages.is_empty():
		list.add_child(UIKit.label(Loc.t("stage.no_approved"), 0.95, UIKit.MUTED))
	for stage in stages:
		list.add_child(_stage_card(stage))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("common.back"), _back_to_setup, 260))
	UIKit.focus_first(self)


func _stage_card(stage: Dictionary) -> PanelContainer:
	var status: String = str(stage.get("status", "PENDING")).to_upper()
	var approved: bool = status == "APPROVED"
	var temporary: bool = status == "TEMPORARY"
	var color: Color = UIKit.OK if approved else (UIKit.WARN if temporary else UIKit.MUTED)
	var panel := UIKit.panel(UIKit.PANEL_ALT if (approved or temporary) else Color("12161f"), color)
	var row := UIKit.hbox(16)
	panel.add_child(row)
	var column := UIKit.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UIKit.label(str(stage.get("name", "?")), 1.15, UIKit.TEXT))
	column.add_child(UIKit.label("%s · %s · %s" % [
		str(stage.get("anime", "")), str(stage.get("city", "")), str(stage.get("architecture", ""))
	], 0.78, UIKit.MUTED))
	var status_text: String = Loc.t("stage.approved")
	if temporary:
		status_text = Loc.t("stage.temporary")
	elif not approved:
		status_text = Loc.t("stage.pending")
	row.add_child(UIKit.tag(status_text, color))
	var select := UIKit.tiny_button(Loc.t("chars.select"), func() -> void: _choose(stage), 180)
	select.disabled = not (approved or temporary)
	row.add_child(select)
	return panel


func _back_to_setup() -> void:
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")


func _choose(stage: Dictionary) -> void:
	Session.stage_id = str(stage.get("id", "lab_arena"))
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")
