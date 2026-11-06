extends Node
## GameData — the single source of truth loaded from res://data.
##
## Responsibilities:
##  * load character records verbatim (never invent or rename fields),
##  * validate them and expose an honest report (duplicates, missing fields),
##  * merge supplemental information from data/character_extensions with provenance,
##  * expose movesets, stages, animation metadata and the reference index,
##  * gate gameplay: only Status.PLAYABLE characters may enter a final match.
##
## The loader tolerates a missing or broken characters.json instead of crashing:
## the UI then shows an explicit "no data" state.

const Consts = preload("res://scripts/core/constants.gd")
const CharacterValidator = preload("res://scripts/data/character_validator.gd")
const MovesetLoader = preload("res://scripts/data/moveset_loader.gd")
const AnimationDB = preload("res://scripts/data/animation_db.gd")
const StageLoader = preload("res://scripts/data/stage_loader.gd")

signal data_loaded(report: Dictionary)

const LAB_FIGHTERS: Array[String] = ["lab_dummy_a", "lab_dummy_b"]

var characters: Array[Dictionary] = []
var series_list: PackedStringArray = PackedStringArray()
var element_list: PackedStringArray = PackedStringArray()
var role_list: PackedStringArray = PackedStringArray()
var rarity_list: PackedStringArray = PackedStringArray()

var validation_report: Dictionary = {}
var data_report: Dictionary = {}
var source_status: String = "NOT_LOADED"
var source_path_used: String = ""
var extensions: Dictionary = {}
var references: Array = []
var load_errors: Array[String] = []

var movesets: MovesetLoader
var animations: AnimationDB
var stages: StageLoader

var _by_id: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	# Defer so autoload siblings (SaveManager/Settings/Loc) are fully ready even
	# if the autoload order ever changes.
	call_deferred("reload_all")


func reload_all() -> Dictionary:
	load_errors.clear()
	movesets = MovesetLoader.new()
	animations = AnimationDB.new()
	stages = StageLoader.new()

	var moveset_report: Dictionary = movesets.load_all(Consts.DATA_FILES["movesets_dir"])
	var animation_report: Dictionary = animations.load_all(Consts.DATA_FILES["animations_dir"])
	var stage_report: Dictionary = stages.load_all(Consts.DATA_FILES["stages_dir"])
	load_characters()
	load_extensions()
	load_references()

	_loaded = true
	# validation_report must stay the validator's own report: the boot screen reads
	# its errors/warnings, and overwriting it with the merged summary made the
	# screen claim "no duplicate ids, no missing fields" no matter what.
	var report := get_report()
	report["movesets"] = moveset_report
	report["animations"] = animation_report
	report["stages"] = stage_report
	data_report = report
	data_loaded.emit(report)
	return report


func load_characters() -> void:
	characters.clear()
	_by_id.clear()
	series_list = PackedStringArray()
	element_list = PackedStringArray()
	role_list = PackedStringArray()
	rarity_list = PackedStringArray()

	var path: String = ""
	if FileAccess.file_exists(Consts.DATA_FILES["characters_local_override"]):
		path = Consts.DATA_FILES["characters_local_override"]
		source_status = "LOCAL_OVERRIDE"
	elif FileAccess.file_exists(Consts.DATA_FILES["characters"]):
		path = Consts.DATA_FILES["characters"]
		source_status = "LOADED"
	else:
		source_status = "MISSING"
		source_path_used = ""
		validation_report = {
			"total_records": 0,
			"valid_records": 0,
			"distinct_series": 0,
			"status_counts": {},
			"errors": ["Character database not found: %s" % Consts.DATA_FILES["characters"]],
			"warnings": [],
			"ok": false,
		}
		return

	source_path_used = path
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		source_status = "PARSE_ERROR"
		validation_report = {
			"total_records": 0,
			"valid_records": 0,
			"distinct_series": 0,
			"status_counts": {},
			"errors": ["JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()]],
			"warnings": [],
			"ok": false,
		}
		return

	var raw_list: Array = []
	match typeof(json.data):
		TYPE_ARRAY:
			raw_list = json.data
		TYPE_DICTIONARY:
			var root: Dictionary = json.data as Dictionary
			var declared: Variant = root.get("characters", [])
			if typeof(declared) == TYPE_ARRAY:
				raw_list = declared
			else:
				load_errors.append("characters.json has no 'characters' array.")
		_:
			load_errors.append("characters.json root must be an array or object.")

	var validator := CharacterValidator.new()
	var report: Dictionary = validator.validate(raw_list)
	validation_report = report
	for raw in raw_list:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = validator.normalize(raw as Dictionary)
		if normalized["id"] < 0 or str(normalized["name"]).is_empty():
			continue
		characters.append(normalized)
		_by_id[normalized["id"]] = normalized
	series_list = _sorted_unique("series")
	element_list = _sorted_unique("element")
	role_list = _sorted_unique("role")
	rarity_list = _sorted_unique("rarity")
	if characters.size() > Consts.MAX_CHARACTERS:
		load_errors.append(
			"Dataset holds %d records, above the %d capacity target. UI supports it; dataset must be reviewed."
			% [characters.size(), Consts.MAX_CHARACTERS]
		)


func load_extensions() -> void:
	extensions.clear()
	var dir := DirAccess.open(Consts.DATA_FILES["extensions_dir"])
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json") or file_name.begins_with("_"):
			continue
		var path: String = Consts.DATA_FILES["extensions_dir"].path_join(file_name)
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			load_errors.append("Extension parse error: %s" % path)
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = json.data as Dictionary
		var character_id: int = int(raw.get("characterId", -1))
		if character_id < 0:
			load_errors.append("Extension without characterId: %s" % path)
			continue
		extensions[character_id] = {
			"characterId": character_id,
			"source": str(raw.get("source", "")),
			"retrieved": str(raw.get("retrieved", "")),
			"notes": str(raw.get("notes", "")),
			"data": raw.get("data", {}),
			"path": path,
		}


func load_references() -> void:
	references.clear()
	var path: String = Consts.DATA_FILES["references"]
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		load_errors.append("references.json parse error: %s" % json.get_error_message())
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		return
	var entries: Variant = (json.data as Dictionary).get("entries", [])
	if typeof(entries) == TYPE_ARRAY:
		references = entries


func _sorted_unique(field: String) -> PackedStringArray:
	var seen: Dictionary = {}
	for character in characters:
		var value: String = str(character.get(field, "")).strip_edges()
		if not value.is_empty() and value != Consts.UNKNOWN_LABEL:
			seen[value] = true
	var keys: Array = seen.keys()
	keys.sort()
	var out := PackedStringArray()
	for key in keys:
		out.append(str(key))
	return out


func is_loaded() -> bool:
	return _loaded


func get_character(character_id: int) -> Dictionary:
	return _by_id.get(character_id, {})


func get_character_by_id(character_id: String) -> Dictionary:
	var numeric: int = int(character_id)
	if _by_id.has(numeric):
		return _by_id[numeric]
	return {}


func get_extension(character_id: int) -> Dictionary:
	return extensions.get(character_id, {})


## "Existing" = present in the source file. "Prepared" = has every required
## field and a valid moveset-animatable record. "Playable" = PLAYABLE status.
func stats() -> Dictionary:
	var playable: int = 0
	var prepared: int = 0
	var status_counts: Dictionary = {}
	for character in characters:
		if int(character["status"]) == Consts.Status.PLAYABLE:
			playable += 1
		if CharacterValidator.is_complete(character["raw"]):
			prepared += 1
		var status_name: String = str(character["status_name"])
		status_counts[status_name] = int(status_counts.get(status_name, 0)) + 1
	return {
		"capacity_target": Consts.MAX_CHARACTERS,
		"existing": characters.size(),
		"prepared": prepared,
		"playable": playable,
		"distinct_series": series_list.size(),
		"status_counts": status_counts,
		"source_status": source_status,
		"source_path": source_path_used,
	}


func get_report() -> Dictionary:
	var report: Dictionary = {
		"stats": stats(),
		"validation": validation_report,
		"load_errors": load_errors.duplicate(),
		"references": references.size(),
		"extensions": extensions.size(),
	}
	return report


## Search + filter used by Character Select. Never loads portraits or animations:
## rows are plain dictionaries so a 600+ roster stays cheap.
func query(
	search_text: String = "",
	element: String = "",
	role: String = "",
	rarity: String = "",
	only_playable: bool = false,
	series: String = ""
) -> Array[Dictionary]:
	var needle: String = search_text.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for character in characters:
		if only_playable and int(character["status"]) != Consts.Status.PLAYABLE:
			continue
		if not element.is_empty() and str(character["element"]) != element:
			continue
		if not role.is_empty() and str(character["role"]) != role:
			continue
		if not rarity.is_empty() and str(character["rarity"]) != rarity:
			continue
		if not series.is_empty() and str(character["series"]) != series:
			continue
		if not needle.is_empty():
			var haystack: String = ("%s\n%s\n%s" % [
				str(character["name"]), str(character["series"]), str(character["city"])
			]).to_lower()
			if not haystack.contains(needle):
				continue
		out.append(character)
	return out


func is_selectable(character: Dictionary) -> bool:
	return int(character.get("status", -1)) == Consts.STATUS_SELECTABLE


## Moveset resolution for a character id: explicit moveset bound to the character,
## otherwise the lab placeholder. Beam/engine code never branches on character names.
## Data is normally loaded on the deferred _ready(); a scene started directly
## (F6 single-scene run, animation review, tests) can ask earlier than that.
func ensure_loaded() -> void:
	if _loaded and movesets != null and animations != null and stages != null:
		return
	reload_all()


func moveset_for_character(character_id: int) -> Dictionary:
	ensure_loaded()
	for moveset in movesets.list_movesets():
		if int(moveset.get("character_id", -1)) == character_id:
			return moveset
	return {}


func lab_moveset(fighter_key: String) -> Dictionary:
	ensure_loaded()
	return movesets.get_moveset(fighter_key)


func stage(stage_id: String) -> Dictionary:
	ensure_loaded()
	return stages.get_stage(stage_id)


func all_stages() -> Array:
	ensure_loaded()
	return stages.list_stages()


func stage_count() -> int:
	ensure_loaded()
	return stages.stages.size()


func moveset_count() -> int:
	ensure_loaded()
	return movesets.movesets.size()


func get_references_for(character_id: int) -> Array:
	var out: Array = []
	for entry in references:
		if typeof(entry) == TYPE_DICTIONARY and int((entry as Dictionary).get("characterId", -1)) == character_id:
			out.append(entry)
	return out
