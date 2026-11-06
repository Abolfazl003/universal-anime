extends Node
## LocalizationStore — all UI strings live in data/localization/<lang>.json.
## Canonical character / series / power names are NEVER translated here; the UI
## prints the records verbatim, exactly as they appear in the source data.

signal language_changed(language: String)

const LOCALE_DIR: String = "res://data/localization"
const FALLBACK_LANGUAGE: String = "en"

var language: String = FALLBACK_LANGUAGE
var _tables: Dictionary = {}
var _missing_keys: Dictionary = {}


func _ready() -> void:
	language = str(SettingsService.get_value("language"))
	load_all()
	SettingsService.setting_changed.connect(_on_setting_changed)


func load_all() -> void:
	_tables.clear()
	var dir := DirAccess.open(LOCALE_DIR)
	if dir == null:
		push_warning("LocalizationStore: locale directory missing.")
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var lang: String = file_name.get_basename()
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(LOCALE_DIR.path_join(file_name))) != OK:
			push_warning("LocalizationStore: cannot parse %s" % file_name)
			continue
		if typeof(json.data) == TYPE_DICTIONARY:
			_tables[lang] = (json.data as Dictionary).get("strings", {})


func available_languages() -> PackedStringArray:
	var out := PackedStringArray(_tables.keys())
	out.sort()
	return out


func set_language(code: String) -> void:
	if code == language:
		return
	language = code if _tables.has(code) else FALLBACK_LANGUAGE
	SettingsService.set_value("language", language)
	language_changed.emit(language)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "language" and str(value) != language:
		language = str(value) if _tables.has(str(value)) else FALLBACK_LANGUAGE
		language_changed.emit(language)


## Translate a UI key. Unknown keys are returned as-is and recorded so a test
## can assert that no UI key is missing from a locale file.
func t(key: String, args: Array = []) -> String:
	var text: String = key
	var table: Dictionary = _tables.get(language, {})
	if table.has(key):
		text = str(table[key])
	else:
		var fallback: Dictionary = _tables.get(FALLBACK_LANGUAGE, {})
		if fallback.has(key):
			text = str(fallback[key])
			_missing_keys["%s:%s" % [language, key]] = true
		else:
			_missing_keys[key] = true
	if not args.is_empty():
		return text % args
	return text


func has(key: String) -> bool:
	var table: Dictionary = _tables.get(language, {})
	if table.has(key):
		return true
	return (_tables.get(FALLBACK_LANGUAGE, {}) as Dictionary).has(key)


func missing_keys() -> PackedStringArray:
	var out := PackedStringArray(_missing_keys.keys())
	out.sort()
	return out


func clear_missing_tracking() -> void:
	_missing_keys.clear()


func all_keys() -> PackedStringArray:
	var table: Dictionary = _tables.get(FALLBACK_LANGUAGE, {})
	var out := PackedStringArray(table.keys())
	out.sort()
	return out
