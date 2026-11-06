extends Node
## SaveService — persistent player data in user:// with schema migration,
## corruption tolerance and (best-effort) atomic writes.
##
## Art approval metadata NEVER lives here: it belongs to the repository under
## assets/characters/<id>/metadata/ so it cannot be altered by a player save.

const Consts = preload("res://scripts/core/constants.gd")

signal save_written(path: String)
signal load_finished(status: String, detail: String)
signal save_reset()

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.tmp.json"
const BACKUP_PATH: String = "user://save.backup.json"
const CORRUPT_PATH: String = "user://save.corrupt.json"

const LOAD_STATUS := {
	"NEW": "NEW",
	"OK": "OK",
	"MIGRATED": "MIGRATED",
	"CORRUPT": "CORRUPT",
	"PARTIAL": "PARTIAL",
}

var data: Dictionary = {}
var last_load_status: String = LOAD_STATUS.NEW
var last_load_detail: String = ""


func _ready() -> void:
	load_game()


static func defaults() -> Dictionary:
	return {
		"schemaVersion": Consts.SAVE_SCHEMA_VERSION,
		"settings": {
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
		},
		"controls": {
			"bindings": {},
		},
		"unlocks": {
			"characters": [],
			"stages": [],
		},
		"progress": {
			"versus_matches": 0,
			"dungeon_runs": 0,
			"best_dungeon_floor": 0,
			"seen_intro": false,
		},
		"results": {
			"last_versus": {},
			"last_dungeon": {},
		},
	}


func load_game() -> void:
	last_load_status = LOAD_STATUS.NEW
	last_load_detail = ""
	if not FileAccess.file_exists(SAVE_PATH):
		data = defaults()
		if FileAccess.file_exists(BACKUP_PATH):
			last_load_status = LOAD_STATUS.PARTIAL
			last_load_detail = "No primary save; a backup exists but was not auto-applied."
		load_finished.emit(last_load_status, last_load_detail)
		return

	var parsed: Variant = _read_json(SAVE_PATH)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		last_load_detail = "Save file unreadable or malformed."
		var backup: Variant = _read_json(BACKUP_PATH)
		if typeof(backup) == TYPE_DICTIONARY:
			data = _merge_with_defaults(backup as Dictionary)
			last_load_status = LOAD_STATUS.PARTIAL
			last_load_detail += " Loaded backup save instead."
		else:
			_copy_corrupt_file()
			data = defaults()
			last_load_status = LOAD_STATUS.CORRUPT
			last_load_detail += " Started from defaults; corrupt file preserved."
		load_finished.emit(last_load_status, last_load_detail)
		return

	var loaded: Dictionary = parsed as Dictionary
	data = _merge_with_defaults(loaded)
	var version: int = int(loaded.get("schemaVersion", 0))
	if version < Consts.SAVE_SCHEMA_VERSION:
		_migrate(version)
		last_load_status = LOAD_STATUS.MIGRATED
		last_load_detail = "Migrated save from schema %d to %d." % [version, Consts.SAVE_SCHEMA_VERSION]
		save_game()
	else:
		last_load_status = LOAD_STATUS.OK
		last_load_detail = "Save loaded (schema %d)." % version
	load_finished.emit(last_load_status, last_load_detail)


func _merge_with_defaults(source: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults()
	for section in source.keys():
		var value: Variant = source[section]
		if typeof(value) == TYPE_DICTIONARY and typeof(merged.get(section)) == TYPE_DICTIONARY:
			var target: Dictionary = merged[section]
			for key in (value as Dictionary).keys():
				target[key] = (value as Dictionary)[key]
			merged[section] = target
		else:
			merged[section] = value
	merged["schemaVersion"] = Consts.SAVE_SCHEMA_VERSION
	return merged


func _migrate(from_version: int) -> void:
	# Each migration step is explicit and additive; unknown data is preserved.
	if from_version < 2:
		if not data.has("controls") or not (data["controls"] as Dictionary).has("bindings"):
			data["controls"] = {"bindings": {}}
	if from_version < 3:
		if not data.has("results"):
			data["results"] = {"last_versus": {}, "last_dungeon": {}}
	data["schemaVersion"] = Consts.SAVE_SCHEMA_VERSION


func save_game() -> bool:
	data["schemaVersion"] = Consts.SAVE_SCHEMA_VERSION
	var payload: String = JSON.stringify(data, "\t")
	var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_warning("SaveService: cannot open temp save file (%s)." % str(FileAccess.get_open_error()))
		return false
	tmp.store_string(payload)
	tmp.flush()
	tmp.close()

	# Verify before replacing the good save.
	if _read_json(TMP_PATH) == null:
		push_warning("SaveService: temp save verification failed; keeping previous save.")
		return false

	if FileAccess.file_exists(SAVE_PATH):
		var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if backup != null:
			backup.store_string(FileAccess.get_file_as_string(SAVE_PATH))
			backup.close()

	var err: int = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		# Fallback for platforms where rename across the same directory is denied.
		var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if direct == null:
			push_warning("SaveService: cannot write save file (%d)." % err)
			return false
		direct.store_string(payload)
		direct.close()
	save_written.emit(SAVE_PATH)
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


func _copy_corrupt_file() -> void:
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var out := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(text)
		out.close()


# --- Convenience accessors -------------------------------------------------

func get_section(section: String) -> Dictionary:
	var value: Variant = data.get(section, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var dict: Dictionary = get_section(section)
	return dict.get(key, fallback)


func set_value(section: String, key: String, value: Variant, autosave: bool = true) -> void:
	if not data.has(section) or typeof(data[section]) != TYPE_DICTIONARY:
		data[section] = {}
	(data[section] as Dictionary)[key] = value
	if autosave:
		save_game()


func record_result(kind: String, result: Dictionary) -> void:
	var results: Dictionary = get_section("results")
	results["last_%s" % kind] = result
	data["results"] = results
	var progress: Dictionary = get_section("progress")
	if kind == "versus":
		progress["versus_matches"] = int(progress.get("versus_matches", 0)) + 1
	elif kind == "dungeon":
		progress["dungeon_runs"] = int(progress.get("dungeon_runs", 0)) + 1
		progress["best_dungeon_floor"] = maxi(
			int(progress.get("best_dungeon_floor", 0)), int(result.get("floor", 0))
		)
	data["progress"] = progress
	save_game()


func reset_settings_only() -> void:
	data["settings"] = defaults()["settings"]
	save_game()


func reset_everything() -> void:
	data = defaults()
	save_game()
	save_reset.emit()
