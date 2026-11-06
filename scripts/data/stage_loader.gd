extends RefCounted
## Stage data store (data/stages/*.json).
## A stage is data + palette + geometry now; final art is only produced after the
## environment is shown to the user and explicitly approved.

var stages: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []

const REQUIRED_FIELDS: PackedStringArray = ["id", "name", "anime", "status"]


func load_all(dir_path: String) -> Dictionary:
	stages.clear()
	errors.clear()
	warnings.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("Stage directory not found: %s" % dir_path)
		return summary()
	for file_name in dir.get_files():
		if not file_name.ends_with(".json") or file_name.begins_with("_"):
			continue
		var path: String = dir_path.path_join(file_name)
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			errors.append("JSON parse error in %s: %s" % [path, json.get_error_message()])
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			errors.append("Stage file is not an object: %s" % path)
			continue
		var raw: Dictionary = json.data as Dictionary
		var missing: Array[String] = []
		for field in REQUIRED_FIELDS:
			if not raw.has(field):
				missing.append(field)
		if not missing.is_empty():
			errors.append("Stage %s missing fields: %s" % [path, ", ".join(missing)])
			continue
		var stage_id: String = str(raw.get("id", ""))
		var palette: Variant = raw.get("palette", {})
		stages[stage_id] = {
			"id": stage_id,
			"name": str(raw.get("name", "")),
			"anime": str(raw.get("anime", "")),
			"city": str(raw.get("city", "")),
			"world": str(raw.get("world", "")),
			"architecture": str(raw.get("architecture", "")),
			"status": str(raw.get("status", "PENDING")),
			"palette": palette if typeof(palette) == TYPE_DICTIONARY else {},
			"floor_y": float(raw.get("floor_y", 820.0)),
			"bounds": raw.get("bounds", {"left": 120.0, "right": 1800.0}),
			"spawn": raw.get("spawn", {"p1_x": 620.0, "p2_x": 1300.0}),
			"notes": str(raw.get("notes", "")),
			"temporary_geometry": bool(raw.get("temporaryGeometry", true)),
			"source": path,
		}
	return summary()


func get_stage(stage_id: String) -> Dictionary:
	return stages.get(stage_id, {})


func list_stages() -> Array:
	return stages.values()


## Stages whose environment has been explicitly approved by the user.
func approved_stage_ids() -> PackedStringArray:
	var approved := PackedStringArray()
	for id in stages.keys():
		if str((stages[id] as Dictionary).get("status", "")).to_upper() == "APPROVED":
			approved.append(id)
	return approved


func summary() -> Dictionary:
	return {
		"count": stages.size(),
		"ids": stages.keys(),
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"ok": errors.is_empty(),
	}
