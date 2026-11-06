extends Control
## Reference Approval Gallery.
##
## This screen is the gate between "data" and "art". It shows:
##  * which sources were actually opened (with URLs and retrieval dates),
##  * whether an image was visually inspected (here: never),
##  * the written dossier that has to be confirmed,
##  * the explicit statement of what is blocked and why.
##
## Nothing in this screen can claim a design is approved: the approval must come
## from the user. The "approve" button stays disabled until reference images
## exist in the repository.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")

const DOSSIER_PATH: String = "res://data/reference_dossiers/001_naruto.json"
const REFERENCE_DIR: String = "res://assets/characters/001_naruto/references"


func _ready() -> void:
	theme = UIKit.theme()
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("refs.title"), Loc.t("refs.subtitle"))

	var blocked := UIKit.panel(Color(0.16, 0.09, 0.09), UIKit.DANGER)
	var blocked_column := UIKit.vbox(4)
	blocked.add_child(blocked_column)
	blocked_column.add_child(UIKit.label(Loc.t("refs.blocked_title"), 1.15, UIKit.DANGER))
	blocked_column.add_child(UIKit.label(Loc.t("refs.blocked_body"), 0.8, UIKit.TEXT))
	column.add_child(blocked)

	var body := UIKit.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_sources_panel())
	body.add_child(_dossier_panel())

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("common.back"), func() -> void: SceneRouter.change_scene(SceneRouter.MAIN_MENU), 240))
	footer.add_child(UIKit.button(Loc.t("refs.request_assets"), _show_asset_instructions, 300))
	var approve := UIKit.button(Loc.t("refs.approve"), func() -> void: pass, 300)
	approve.disabled = true
	approve.tooltip_text = Loc.t("refs.animation_blocked")
	footer.add_child(approve)
	footer.add_child(UIKit.expander())
	UIKit.focus_first(self)


func _sources_panel() -> PanelContainer:
	var panel := UIKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := UIKit.vbox(8)
	panel.add_child(column)
	column.add_child(UIKit.label(Loc.t("refs.sources"), 1.1, UIKit.ACCENT))

	var entries: Array = GameData.references
	if entries.is_empty():
		column.add_child(UIKit.label("references.json is missing or empty.", 0.85, UIKit.WARN))
	for entry in entries:
		var data: Dictionary = entry
		var box := UIKit.vbox(2)
		column.add_child(box)
		box.add_child(UIKit.label(str(data.get("title", "?")), 0.95, UIKit.TEXT))
		box.add_child(UIKit.label(str(data.get("url", "")), 0.72, UIKit.INFO))
		var meta := UIKit.hbox(8)
		box.add_child(meta)
		meta.add_child(UIKit.tag(str(data.get("kind", "source")), UIKit.MUTED))
		meta.add_child(UIKit.tag("%s: %s" % [Loc.t("refs.image_reviewed"),
			Loc.t("common.yes") if bool(data.get("imageReviewed", false)) else Loc.t("common.no")],
			UIKit.OK if bool(data.get("imageReviewed", false)) else UIKit.WARN))
		meta.add_child(UIKit.label(str(data.get("retrievedOn", "")), 0.72, UIKit.MUTED))
	column.add_child(UIKit.divider())
	var folder_note: String = "%s: %d file(s)" % [REFERENCE_DIR, _reference_file_count()]
	column.add_child(UIKit.label(folder_note, 0.75, UIKit.MUTED))
	return panel


func _dossier_panel() -> PanelContainer:
	var panel := UIKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var column := UIKit.vbox(8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	var dossier: Dictionary = _load_dossier()
	if dossier.is_empty():
		column.add_child(UIKit.label("Dossier file missing: %s" % DOSSIER_PATH, 0.85, UIKit.WARN))
		return panel

	column.add_child(UIKit.label("%s — %s" % [str(dossier.get("characterName", "")), str(dossier.get("status", ""))],
		1.15, UIKit.ACCENT))
	var version: Dictionary = dossier.get("versionDecision", {})
	column.add_child(UIKit.label(str(version.get("chosen", "")), 0.9, UIKit.TEXT))
	column.add_child(UIKit.label(Loc.t("refs.dossier"), 0.85, UIKit.MUTED))

	column.add_child(_bullet_list("Outfit", dossier.get("outfitChecklist", [])))
	column.add_child(_bullet_list("Body", dossier.get("bodyChecklist", [])))
	column.add_child(_bullet_list("Not mixed into this design", version.get("explicitlyExcludedForThisDesign", [])))
	column.add_child(_bullet_list("Open questions for you", dossier.get("openQuestions", [])))
	column.add_child(_bullet_list("Blockers", dossier.get("blockers", [])))

	var powers: Array = dossier.get("powerNamesFromUserBrief", [])
	if not powers.is_empty():
		column.add_child(UIKit.label("Power names in the brief (verbatim): %s" % ", ".join(powers), 0.8, UIKit.MUTED))
	column.add_child(UIKit.label(str(dossier.get("powerNamesNote", "")), 0.72, UIKit.MUTED))
	return panel


func _bullet_list(title: String, items: Array) -> VBoxContainer:
	var box := UIKit.vbox(2)
	if items.is_empty():
		return box
	box.add_child(UIKit.label(title, 0.9, UIKit.ACCENT))
	for item in items:
		box.add_child(UIKit.label("• %s" % str(item), 0.78, UIKit.TEXT))
	return box


func _load_dossier() -> Dictionary:
	if not FileAccess.file_exists(DOSSIER_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(DOSSIER_PATH)) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _reference_file_count() -> int:
	var dir := DirAccess.open(REFERENCE_DIR)
	if dir == null:
		return 0
	var count: int = 0
	for file_name in dir.get_files():
		if file_name.begins_with("."):
			continue
		count += 1
	return count


func _show_asset_instructions() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = Loc.t("refs.request_assets")
	dialog.dialog_text = Loc.t("refs.need_user_images")
	add_child(dialog)
	dialog.popup_centered()
