extends Node
## InputMapService — one authoritative place for every gameplay action.
##
## Actions are registered at runtime (not in project.godot) so that:
##  * two local players can be bound independently without key collisions,
##  * rebinding in the Controls screen is saved with the player save,
##  * keyboard and gamepad share the same action names used by fighters and UI.

signal bindings_changed()
signal device_changed(device: String)

const Consts = preload("res://scripts/core/constants.gd")

const ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "crouch", "light", "heavy", "block", "special", "ultimate",
]

const GLOBAL_ACTIONS: PackedStringArray = ["pause", "debug_toggle", "restart"]

const ACTION_LABEL_KEYS: Dictionary = {
	"move_left": "input.move_left",
	"move_right": "input.move_right",
	"move_up": "input.move_up",
	"move_down": "input.move_down",
	"jump": "input.jump",
	"crouch": "input.crouch",
	"light": "input.light",
	"heavy": "input.heavy",
	"block": "input.block",
	"special": "input.special",
	"ultimate": "input.ultimate",
	"pause": "input.pause",
	"debug_toggle": "input.debug_toggle",
	"restart": "input.restart",
}

var last_device: String = "keyboard"

## Tick-accurate edge detection. Input.is_action_just_pressed() is frame based;
## the simulation runs on 60 Hz physics ticks, so edges are sampled per tick here
## and read by fighters. Same input, same result, at any display refresh rate.
var _edge: Dictionary = {}
var _previous: Dictionary = {}

## Default bindings: arrays of serialized event dictionaries.
var _defaults: Dictionary = {}
var _bindings: Dictionary = {}


func _ready() -> void:
	_build_defaults()
	_load_saved()
	_apply_all()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _build_defaults() -> void:
	_defaults = {}
	# Player 1 — keyboard left hand + J/K/L/U/I.
	_defaults["p1_move_left"] = [_key(KEY_A)]
	_defaults["p1_move_right"] = [_key(KEY_D)]
	_defaults["p1_move_up"] = [_key(KEY_W)]
	_defaults["p1_move_down"] = [_key(KEY_S)]
	_defaults["p1_jump"] = [_key(KEY_W), _joy_button(JOY_BUTTON_A, 0)]
	_defaults["p1_crouch"] = [_key(KEY_S), _joy_button(JOY_BUTTON_B, 0)]
	_defaults["p1_light"] = [_key(KEY_J), _joy_button(JOY_BUTTON_X, 0)]
	_defaults["p1_heavy"] = [_key(KEY_K), _joy_button(JOY_BUTTON_Y, 0)]
	_defaults["p1_block"] = [_key(KEY_L), _joy_button(JOY_BUTTON_LEFT_SHOULDER, 0)]
	_defaults["p1_special"] = [_key(KEY_U), _joy_button(JOY_BUTTON_RIGHT_SHOULDER, 0)]
	_defaults["p1_ultimate"] = [_key(KEY_I), _joy_button(JOY_BUTTON_RIGHT_STICK, 0)]

	# Player 2 — arrows + numpad, second gamepad.
	_defaults["p2_move_left"] = [_key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0, 1)]
	_defaults["p2_move_right"] = [_key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0, 1)]
	_defaults["p2_move_up"] = [_key(KEY_UP)]
	_defaults["p2_move_down"] = [_key(KEY_DOWN)]
	_defaults["p2_jump"] = [_key(KEY_UP), _joy_button(JOY_BUTTON_A, 1)]
	_defaults["p2_crouch"] = [_key(KEY_DOWN), _joy_button(JOY_BUTTON_B, 1)]
	_defaults["p2_light"] = [_key(KEY_KP_1), _joy_button(JOY_BUTTON_X, 1)]
	_defaults["p2_heavy"] = [_key(KEY_KP_2), _joy_button(JOY_BUTTON_Y, 1)]
	_defaults["p2_block"] = [_key(KEY_KP_3), _joy_button(JOY_BUTTON_LEFT_SHOULDER, 1)]
	_defaults["p2_special"] = [_key(KEY_KP_4), _joy_button(JOY_BUTTON_RIGHT_SHOULDER, 1)]
	_defaults["p2_ultimate"] = [_key(KEY_KP_5), _joy_button(JOY_BUTTON_RIGHT_STICK, 1)]

	# Global actions. ui_* navigation stays on Godot defaults so the gamepad and
	# keyboard can both drive menus without extra work.
	_defaults["pause"] = [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START, -1)]
	_defaults["restart"] = [_key(KEY_R)]
	_defaults["debug_toggle"] = [_key(KEY_F3)]

	_bindings = _defaults.duplicate(true)


func _load_saved() -> void:
	var saved: Dictionary = SaveManager.get_value("controls", "bindings", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for action in (saved as Dictionary).keys():
		if _defaults.has(action) and typeof(saved[action]) == TYPE_ARRAY:
			_bindings[action] = saved[action]


func _apply_all() -> void:
	for action in _bindings.keys():
		var input_action: String = str(action)
		if InputMap.has_action(input_action):
			InputMap.action_erase_events(input_action)
		else:
			InputMap.add_action(input_action)
		for event_data in (_bindings[action] as Array):
			var event: InputEvent = _deserialize(event_data)
			if event != null:
				InputMap.action_add_event(input_action, event)
	bindings_changed.emit()


func reset_defaults() -> void:
	_bindings = _defaults.duplicate(true)
	SaveManager.set_value("controls", "bindings", {}, false)
	SaveManager.save_game()
	_apply_all()


func action_name(player_index: int, base_action: String) -> String:
	return "p%d_%s" % [player_index + 1, base_action]


func _physics_process(_delta: float) -> void:
	for action in _bindings.keys():
		var name: String = str(action)
		var now: bool = Input.is_action_pressed(name)
		_edge[name] = now and not bool(_previous.get(name, false))
		_previous[name] = now


## True only on the first simulation tick in which the action went down.
func pressed_this_tick(player_index: int, base_action: String) -> bool:
	return bool(_edge.get(action_name(player_index, base_action), false))


func held_this_tick(player_index: int, base_action: String) -> bool:
	return bool(_previous.get(action_name(player_index, base_action), false))


func is_pressed(player_index: int, base_action: String) -> bool:
	return Input.is_action_pressed(action_name(player_index, base_action))


func just_pressed(player_index: int, base_action: String) -> bool:
	return Input.is_action_just_pressed(action_name(player_index, base_action))


func just_released(player_index: int, base_action: String) -> bool:
	return Input.is_action_just_released(action_name(player_index, base_action))


func move_axis(player_index: int) -> float:
	return Input.get_axis(action_name(player_index, "move_left"), action_name(player_index, "move_right"))


## Human-readable label for the first keyboard binding of an action.
func binding_label(player_index: int, base_action: String) -> String:
	var action: String = action_name(player_index, base_action)
	if not _bindings.has(action):
		return "-"
	var events: Array = _bindings[action]
	for event_data in events:
		if str((event_data as Dictionary).get("type", "")) == "key":
			var code: int = int((event_data as Dictionary).get("physical_keycode", 0))
			return OS.get_keycode_string(code)
	for event_data in events:
		if str((event_data as Dictionary).get("type", "")) == "joy_button":
			return "Pad %d" % int((event_data as Dictionary).get("button", 0))
	return "-"


func global_binding_label(base_action: String) -> String:
	return binding_label_for_action(base_action)


func binding_label_for_action(action: String) -> String:
	if not _bindings.has(action):
		return "-"
	for event_data in (_bindings[action] as Array):
		if str((event_data as Dictionary).get("type", "")) == "key":
			return OS.get_keycode_string(int((event_data as Dictionary).get("physical_keycode", 0)))
	return "-"


## Rebinds an action to a single physical key, replacing keyboard bindings only.
func rebind_key(player_index: int, base_action: String, keycode: Key) -> void:
	rebind_action_key(action_name(player_index, base_action), keycode)


func rebind_action_key(action: String, keycode: Key) -> void:
	if not _bindings.has(action):
		return
	var kept: Array = []
	for event_data in (_bindings[action] as Array):
		if str((event_data as Dictionary).get("type", "")) != "key":
			kept.append(event_data)
	kept.push_front(_key(keycode))
	_bindings[action] = kept
	_persist()
	_apply_all()


func _persist() -> void:
	var serialized: Dictionary = {}
	for action in _bindings.keys():
		serialized[action] = _bindings[action]
	SaveManager.set_value("controls", "bindings", serialized, false)
	SaveManager.save_game()


func _key(keycode: Key) -> Dictionary:
	return {"type": "key", "physical_keycode": int(keycode), "device": -1}


func _joy_button(button: int, device: int) -> Dictionary:
	return {"type": "joy_button", "button": button, "device": device}


func _joy_axis(axis: int, value: float, device: int) -> Dictionary:
	return {"type": "joy_axis", "axis": axis, "value": value, "device": device}


func _deserialize(event_data: Variant) -> InputEvent:
	if typeof(event_data) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = event_data as Dictionary
	match str(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			return key_event
		"joy_button":
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = int(data.get("button", 0)) as JoyButton
			button_event.device = int(data.get("device", -1))
			return button_event
		"joy_axis":
			var axis_event := InputEventJoypadMotion.new()
			axis_event.axis = int(data.get("axis", 0)) as JoyAxis
			axis_event.axis_value = float(data.get("value", 0.0))
			axis_event.device = int(data.get("device", -1))
			return axis_event
	return null


func gamepad_count() -> int:
	return Input.get_connected_joypads().size()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	device_changed.emit("gamepad" if gamepad_count() > 0 else "keyboard")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		if last_device != "keyboard":
			last_device = "keyboard"
			device_changed.emit(last_device)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		if last_device != "gamepad":
			last_device = "gamepad"
			device_changed.emit(last_device)
