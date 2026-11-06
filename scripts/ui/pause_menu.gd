extends Control
## Pause overlay. Added by SceneRouter above the gameplay scene, with the tree
## paused; it must therefore run in PROCESS_MODE_ALWAYS.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _payload: Dictionary = {}


func setup(payload: Dictionary) -> void:
	_payload = payload


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.theme()
	_build()
	UIKit.focus_first(self)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := VBoxContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centre.offset_left = -280
	centre.offset_right = 280
	centre.offset_top = -300
	centre.offset_bottom = 300
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 10)
	add_child(centre)

	centre.add_child(UIKit.label(Loc.t("pause.title"), 2.4, UIKit.ACCENT))
	centre.add_child(UIKit.button(Loc.t("pause.resume"), _resume, 460, true))
	centre.add_child(UIKit.button(Loc.t("pause.restart"), _restart, 460))
	centre.add_child(UIKit.button(Loc.t("pause.controls"), _controls, 460))
	centre.add_child(UIKit.button(Loc.t("pause.character_select"), _character_select, 460))
	centre.add_child(UIKit.button(Loc.t("pause.main_menu"), _main_menu, 460))
	centre.add_child(UIKit.label(Loc.t("menu.debug_hint"), 0.7, UIKit.MUTED))


func _unpause() -> void:
	get_tree().paused = false
	SceneRouter.close_overlay()


func _resume() -> void:
	_unpause()


func _restart() -> void:
	_unpause()
	var current: String = ""
	if get_tree().current_scene != null:
		current = get_tree().current_scene.scene_file_path
	if current.is_empty():
		SceneRouter.change_scene(SceneRouter.MAIN_MENU)
	else:
		SceneRouter.change_scene(current)


func _controls() -> void:
	SceneRouter.push_overlay("res://scenes/menus/controls.tscn", {})


func _character_select() -> void:
	_unpause()
	SceneRouter.change_scene("res://scenes/menus/character_select.tscn", {"purpose": "browse"})


func _main_menu() -> void:
	_unpause()
	SceneRouter.change_scene(SceneRouter.MAIN_MENU)
