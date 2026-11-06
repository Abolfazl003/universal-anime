extends Node
## SettingsStore — typed access to player settings plus application to the engine.
## Volume, window mode, resolution, text scale, shake/flash intensity and
## reduced-motion live here. Defaults are deliberately safe: heavy shake and
## strong flashes are OFF unless the player enables them.

signal setting_changed(key: String, value: Variant)

const SAVE_SECTION := "settings"
const UiKit = preload("res://scripts/ui/ui_kit.gd")

const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"window_mode": "windowed",
	"resolution": "1280x720",
	"text_scale": 1.0,
	"screen_shake": 0.0,
	"flash_intensity": 0.0,
	"reduced_motion": true,
	"language": "en",
	"show_fps": false,
}

const RESOLUTIONS: Array[String] = ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]

var _values: Dictionary = {}


func _ready() -> void:
	var stored: Dictionary = SaveManager.get_section(SAVE_SECTION)
	_values = DEFAULT_SETTINGS.duplicate(true)
	for key in stored.keys():
		if DEFAULT_SETTINGS.has(key):
			_values[key] = stored[key]
	apply_window(true)
	apply_audio()
	UiKit.set_text_scale(float(_values.get("text_scale", 1.0)))


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULT_SETTINGS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_warning("SettingsStore: unknown setting '%s'." % key)
		return
	if _values.get(key) == value:
		return
	_values[key] = value
	SaveManager.set_value(SAVE_SECTION, key, value, false)
	SaveManager.save_game()
	apply_single(key)
	if key == "text_scale":
		UiKit.set_text_scale(float(value))
	setting_changed.emit(key, value)


func as_dict() -> Dictionary:
	return _values.duplicate(true)


func apply_single(key: String) -> void:
	match key:
		"master_volume", "music_volume", "sfx_volume":
			apply_audio()
		"window_mode", "resolution":
			apply_window()
		_:
			pass


func apply_all() -> void:
	apply_window()
	apply_audio()


func apply_window(force: bool = false) -> void:
	var mode: String = str(get_value("window_mode"))
	var res: String = str(get_value("resolution"))
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == "borderless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	if mode != "fullscreen" and WindowSizeHelper.is_valid(res):
		var size: Vector2i = WindowSizeHelper.parse(res)
		if force or DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		if screen_size.x > 0 and screen_size.y > 0:
			DisplayServer.window_set_position((screen_size - size) / 2)


func apply_audio() -> void:
	_ensure_buses()
	_set_bus_volume("Master", float(get_value("master_volume")))
	_set_bus_volume("Music", float(get_value("music_volume")))
	_set_bus_volume("SFX", float(get_value("sfx_volume")))


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.0001)))


func cycle_resolution(direction: int) -> void:
	var current: String = str(get_value("resolution"))
	var index: int = RESOLUTIONS.find(current)
	index = clampi(index + direction, 0, RESOLUTIONS.size() - 1)
	set_value("resolution", RESOLUTIONS[index])


func cycle_window_mode(direction: int) -> void:
	var current: String = str(get_value("window_mode"))
	var index: int = WINDOW_MODES.find(current)
	index = wrapi(index + direction, 0, WINDOW_MODES.size())
	set_value("window_mode", WINDOW_MODES[index])


func reset_to_defaults() -> void:
	for key in DEFAULT_SETTINGS.keys():
		_values[key] = DEFAULT_SETTINGS[key]
		SaveManager.set_value(SAVE_SECTION, key, DEFAULT_SETTINGS[key], false)
	SaveManager.save_game()
	apply_all()
	for key in DEFAULT_SETTINGS.keys():
		setting_changed.emit(key, _values[key])


func shake_enabled() -> bool:
	return float(get_value("screen_shake")) > 0.01 and not reduced_motion_enabled()


func flash_enabled() -> bool:
	return float(get_value("flash_intensity")) > 0.01 and not reduced_motion_enabled()


func reduced_motion_enabled() -> bool:
	return bool(get_value("reduced_motion"))


## Utility class kept here to avoid an extra autoload.
class WindowSizeHelper:
	static func parse(value: String) -> Vector2i:
		var parts: PackedStringArray = value.split("x")
		if parts.size() != 2:
			return Vector2i(1280, 720)
		return Vector2i(int(parts[0]), int(parts[1]))

	static func is_valid(value: String) -> bool:
		var parts: PackedStringArray = value.split("x")
		if parts.size() != 2:
			return false
		return parts[0].is_valid_int() and parts[1].is_valid_int()
