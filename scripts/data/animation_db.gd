extends RefCounted
## Animation metadata store.
## Animation *timing* lives in data (resources/animations/*.json), never inside
## scene files, so playback is deterministic and independent of display FPS.
## No image frames exist for a character until its design is approved; entries
## therefore carry an explicit status and frame count of 0 while pending.

## Minimum animation set required before a character can be marked QA_PASSED.
const REQUIRED_ANIMATIONS: PackedStringArray = [
	"idle",
	"walk",
	"run",
	"jump_start",
	"jump_loop",
	"landing",
	"crouch",
	"block",
	"block_hit",
	"light_attack",
	"heavy_attack",
	"special",
	"ultimate",
	"hit_reaction",
	"knockdown",
	"get_up",
	"victory",
	"defeat",
	"intro",
	"outro",
]

## Animations needed by the top-down dungeon camera (8 directions).
const DUNGEON_ANIMATIONS: PackedStringArray = [
	"d_idle_down",
	"d_walk_down",
	"d_idle_up",
	"d_walk_up",
	"d_idle_side",
	"d_walk_side",
]

var clips: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


func load_all(dir_path: String) -> Dictionary:
	clips.clear()
	errors.clear()
	warnings.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("Animation directory not found: %s" % dir_path)
		return summary()
	for file_name in dir.get_files():
		if not file_name.ends_with(".json") or file_name.begins_with("_"):
			continue
		var path: String = dir_path.path_join(file_name)
		var text: String = FileAccess.get_file_as_string(path)
		var json := JSON.new()
		if json.parse(text) != OK:
			errors.append("JSON parse error in %s: %s" % [path, json.get_error_message()])
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			errors.append("Animation file is not an object: %s" % path)
			continue
		var raw: Dictionary = json.data as Dictionary
		var character_id: String = str(raw.get("characterId", file_name.get_basename()))
		var raw_clips: Variant = raw.get("clips", {})
		if typeof(raw_clips) != TYPE_DICTIONARY:
			errors.append("Animation file %s has no 'clips' object." % path)
			continue
		var character_clips: Dictionary = {}
		for clip_id in (raw_clips as Dictionary).keys():
			var clip_raw: Variant = (raw_clips as Dictionary)[clip_id]
			if typeof(clip_raw) != TYPE_DICTIONARY:
				continue
			character_clips[str(clip_id)] = _normalize_clip(str(clip_id), clip_raw as Dictionary, path)
		clips[character_id] = {
			"characterId": character_id,
			"status": str(raw.get("status", "PENDING")),
			"canvas": raw.get("canvas", {}),
			"pivot": raw.get("pivot", {}),
			"clips": character_clips,
			"source": path,
		}
	return summary()


func _normalize_clip(clip_id: String, raw: Dictionary, path: String) -> Dictionary:
	var frames: int = int(raw.get("frames", 0))
	var fps: float = float(raw.get("fps", 12.0))
	if fps <= 0.0:
		errors.append("Clip '%s' in %s has invalid fps." % [clip_id, path])
		fps = 12.0
	if frames < 0:
		errors.append("Clip '%s' in %s has a negative frame count." % [clip_id, path])
		frames = 0
	return {
		"id": clip_id,
		"frames": frames,
		"fps": fps,
		"loop": bool(raw.get("loop", false)),
		"anchor": str(raw.get("anchor", "feet")),
		"status": str(raw.get("status", "PENDING")),
		"placeholder": frames == 0,
		"duration_ticks": int(round(float(frames) / fps * float(60.0))) if frames > 0 else 0,
	}


func get_character(character_id: String) -> Dictionary:
	return clips.get(character_id, {})


func get_clip(character_id: String, clip_id: String) -> Dictionary:
	var character: Dictionary = get_character(character_id)
	if character.is_empty():
		return {}
	return (character.get("clips", {}) as Dictionary).get(clip_id, {})


## Returns the missing required animation ids for a character. Used by QA gates
## and by the tests. A placeholder clip (frames == 0) counts as missing.
func missing_animations(character_id: String) -> PackedStringArray:
	var missing := PackedStringArray()
	var character: Dictionary = get_character(character_id)
	if character.is_empty():
		return REQUIRED_ANIMATIONS.duplicate()
	var character_clips: Dictionary = character.get("clips", {})
	for clip_id in REQUIRED_ANIMATIONS:
		if not character_clips.has(clip_id):
			missing.append(clip_id)
			continue
		if int((character_clips[clip_id] as Dictionary).get("frames", 0)) <= 0:
			missing.append(clip_id)
	return missing


func summary() -> Dictionary:
	return {
		"characters": clips.size(),
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"ok": errors.is_empty(),
	}
