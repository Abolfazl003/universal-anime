extends CanvasLayer
## DebugService — F3 overlay: FPS, current screen, game mode, hitbox volume and
## resource usage. Also owns global debug flags (hitbox drawing, slow motion) so
## gameplay code can query them without holding references to UI nodes.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

signal flags_changed()

var show_hitboxes: bool = false
var show_hurtboxes: bool = false
var show_overlay: bool = false
var slow_motion: bool = false
var paused_for_review: bool = false

var _panel: PanelContainer
var _label: Label
var _state_line: String = ""
var _hitbox_count: int = 0
var _update_timer: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_overlay_visible(false)


func _build_ui() -> void:
	_panel = UIKit.panel(Color(0.02, 0.03, 0.05, 0.86), UIKit.OUTLINE)
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(430, 0)
	add_child(_panel)
	var column := UIKit.vbox(4)
	_panel.add_child(column)
	_label = UIKit.label("", 0.72, UIKit.TEXT)
	_label.custom_minimum_size = Vector2(400, 0)
	column.add_child(_label)


func set_overlay_visible(value: bool) -> void:
	show_overlay = value
	if _panel != null:
		_panel.visible = value


func toggle_overlay() -> void:
	set_overlay_visible(not show_overlay)


func toggle_hitboxes() -> void:
	show_hitboxes = not show_hitboxes
	show_hurtboxes = show_hitboxes
	flags_changed.emit()


func report_state(text: String) -> void:
	_state_line = text


func report_hitbox_count(count: int) -> void:
	_hitbox_count = count


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle_overlay()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F4:
			toggle_hitboxes()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F6:
			slow_motion = not slow_motion
			Engine.time_scale = 0.25 if slow_motion else 1.0
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not show_overlay or _label == null:
		return
	_update_timer += delta
	if _update_timer < 0.2:
		return
	_update_timer = 0.0
	var current_scene: String = "-"
	if get_tree().current_scene != null:
		current_scene = get_tree().current_scene.scene_file_path.get_file()
	var lines: PackedStringArray = [
		"FPS: %d   |   physics: %d Hz   |   time_scale: %.2f" % [
			int(Engine.get_frames_per_second()), Engine.physics_ticks_per_second, Engine.time_scale
		],
		"scene: %s" % current_scene,
		"mode: %s" % _mode_name(),
		"state: %s" % (_state_line if not _state_line.is_empty() else "-"),
		"hitboxes drawn: %d   |   hurtboxes: %s" % [_hitbox_count, str(show_hurtboxes)],
		"objects: %d   |   nodes: %d" % [
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		],
		"static mem: %.1f MB   |   video mem: %.1f MB" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		],
		"save: %s" % SaveManager.last_load_status,
		"roster: %d records / %d playable" % [
			GameData.stats().get("existing", 0), GameData.stats().get("playable", 0)
		],
	]
	_label.text = "\n".join(lines)


func _mode_name() -> String:
	if Session == null:
		return "-"
	match Session.mode:
		1:
			return "VERSUS"
		2:
			return "DUNGEON"
		3:
			return "LAB"
		_:
			return "MENU"
