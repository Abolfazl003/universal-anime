extends Node
## RouterService — scene changes with a short fade, a navigation history and
## overlay support (pause menu, debug panels).
##
## Gameplay code never calls get_tree().change_scene_to_file() directly, so that
## transitions, payload passing and overlay lifetime stay consistent.

signal scene_changed(path: String)
signal overlay_opened(path: String)
signal overlay_closed()

const MAIN_MENU: String = "res://scenes/menus/main_menu.tscn"
const BOOT: String = "res://scenes/boot/boot.tscn"

var history: Array[String] = []
var fade_enabled: bool = true

var _payload: Dictionary = {}
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _overlay_layer: CanvasLayer
var _overlay: Node
var _busy: bool = false


func _ready() -> void:
	# Transitions must keep running while the gameplay tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_layers()


func _build_layers() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	_fade_layer.name = "FadeLayer"
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 64
	_overlay_layer.name = "OverlayLayer"
	add_child(_overlay_layer)


func change_scene(path: String, payload: Dictionary = {}, use_fade: bool = true) -> void:
	if _busy:
		return
	_busy = true
	_payload = payload.duplicate(true)
	if not history.is_empty() and history[-1] == path:
		pass
	else:
		var current: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		if not current.is_empty():
			history.append(current)
	close_overlay()
	if use_fade and fade_enabled and not DisplayServer.get_name().contains("headless"):
		await _fade_to(1.0, 0.12)
		await _do_change(path)
		await _fade_to(0.0, 0.14)
	else:
		await _do_change(path)
	_busy = false
	scene_changed.emit(path)


func _do_change(path: String) -> void:
	var result: int = get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("RouterService: cannot load scene %s (error %d)" % [path, result])
		_busy = false
		return
	await get_tree().process_frame
	await get_tree().process_frame


func _fade_to(alpha: float, duration: float) -> void:
	_fade_rect.color.a = _fade_rect.color.a
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished


func payload() -> Dictionary:
	return _payload


func go_back() -> void:
	if history.is_empty():
		change_scene(MAIN_MENU)
		return
	var path: String = history.pop_back()
	change_scene(path)


func clear_history() -> void:
	history.clear()


## Overlays are children of this autoload, so they survive a paused tree and can
## be closed without touching the gameplay scene.
func push_overlay(path: String, payload: Dictionary = {}) -> Node:
	close_overlay()
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("RouterService: cannot load overlay %s" % path)
		return null
	_overlay = scene.instantiate()
	if _overlay.has_method("setup"):
		_overlay.call("setup", payload)
	_overlay_layer.add_child(_overlay)
	overlay_opened.emit(path)
	return _overlay


func close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
		overlay_closed.emit()


func has_overlay() -> bool:
	return _overlay != null and is_instance_valid(_overlay)


func overlay() -> Node:
	return _overlay
