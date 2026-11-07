extends RefCounted
## Loads and validates movesets from data/movesets/*.json.
## A moveset is pure data: no scene, no script and no character name checks.
## Adding a character must never require rewriting the combat engine.

const REQUIRED_MOVE_FIELDS: PackedStringArray = [
	"id",
	"animation_id",
	"startup",
	"active",
	"recovery",
	"damage",
	"hitstun",
	"blockstun",
	"hitbox",
]

const DEFAULT_MOVE: Dictionary = {
	"type": "melee",
	"damage": 0,
	"chip_damage": 0,
	"hitstun": 0,
	"blockstun": 0,
	"knockback_x": 0.0,
	"knockback_y": 0.0,
	"energy_cost": 0.0,
	"energy_gain": 0.0,
	"ultimate_gain": 0.0,
	"cooldown": 0,
	"hitbox_offset_x": 0.0,
	"hitbox_offset_y": 0.0,
	"hitbox_size_x": 0.0,
	"hitbox_size_y": 0.0,
	"multi_hit": [],
	"projectile": {},
	"cancel_windows": [],
	"meter_required": 0.0,
	"invulnerable_frames": 0,
	"move_speed": 0.0,
	"air_ok": false,
	"heal": 0,
	"energy_gain_on_cast": 0.0,
}

var movesets: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


func load_all(dir_path: String = "res://data/movesets") -> Dictionary:
	movesets.clear()
	errors.clear()
	warnings.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append("Moveset directory not found: %s" % dir_path)
		return summary()
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		if file_name.begins_with("_"):
			continue
		var path: String = dir_path.path_join(file_name)
		var parsed: Variant = _read_json(path)
		if parsed == null:
			errors.append("Unreadable moveset file: %s" % path)
			continue
		if typeof(parsed) != TYPE_DICTIONARY:
			errors.append("Moveset file is not a JSON object: %s" % path)
			continue
		_register(parsed as Dictionary, path)
	return summary()


func _register(raw: Dictionary, path: String) -> void:
	var moveset_id: String = str(raw.get("movesetId", "")).strip_edges()
	if moveset_id.is_empty():
		errors.append("Moveset in %s has no 'movesetId'." % path)
		return
	var raw_moves: Variant = raw.get("moves", {})
	if typeof(raw_moves) != TYPE_DICTIONARY:
		errors.append("Moveset '%s' has an invalid 'moves' object." % moveset_id)
		return
	var moves: Dictionary = {}
	for key in (raw_moves as Dictionary).keys():
		var raw_move: Variant = (raw_moves as Dictionary)[key]
		if typeof(raw_move) != TYPE_DICTIONARY:
			errors.append("Moveset '%s' move '%s' is not an object." % [moveset_id, str(key)])
			continue
		var move: Dictionary = _normalize_move(str(key), raw_move as Dictionary, moveset_id)
		if not move.is_empty():
			moves[str(key)] = move
	if moves.is_empty():
		errors.append("Moveset '%s' has no usable moves." % moveset_id)
		return
	movesets[moveset_id] = {
		"id": moveset_id,
		"character_id": raw.get("characterId", null),
		"display_name": str(raw.get("displayName", moveset_id)),
		"temporary": bool(raw.get("temporary", false)),
		"fighter": raw.get("fighter", {}),
		"moves": moves,
		"forms": raw.get("forms", {}),
		"stats": raw.get("stats", {}),
		"source": path,
	}


func _normalize_move(key: String, raw: Dictionary, moveset_id: String) -> Dictionary:
	var move: Dictionary = DEFAULT_MOVE.duplicate(true)
	move["id"] = str(raw.get("id", key))
	var declared_type: String = str(raw.get("type", "melee"))
	for field in REQUIRED_MOVE_FIELDS:
		# Support moves (heals, self-buffs) never hit anything, so a hitbox,
		# damage and hitstun are all optional for them.
		if declared_type == "support" and field in ["hitbox", "damage", "hitstun", "blockstun"]:
			continue
		if not raw.has(field):
			errors.append("Moveset '%s' move '%s' is missing required field '%s'." % [moveset_id, key, field])
			return {}

	var move_type: String = str(raw.get("type", "melee"))
	var hitbox_raw: Variant = raw.get("hitbox")
	if typeof(hitbox_raw) != TYPE_DICTIONARY:
		# Support moves (heals, buffs) have nothing to hit, so a hitbox is optional
		# for them. Everything that can damage still needs a real box.
		if move_type == "support":
			hitbox_raw = {}
		else:
			errors.append("Moveset '%s' move '%s' has an invalid hitbox." % [moveset_id, key])
			return {}
	var hitbox: Dictionary = hitbox_raw as Dictionary

	move["animation_id"] = str(raw.get("animation_id", ""))
	move["startup"] = maxi(0, int(raw.get("startup", 0)))
	move["active"] = maxi(1, int(raw.get("active", 1)))
	move["recovery"] = maxi(0, int(raw.get("recovery", 0)))
	move["damage"] = maxi(0, int(raw.get("damage", 0)))
	move["hitstun"] = maxi(0, int(raw.get("hitstun", 0)))
	move["blockstun"] = maxi(0, int(raw.get("blockstun", 0)))
	move["type"] = str(raw.get("type", "melee"))
	move["name"] = str(raw.get("name", ""))
	var effect: Variant = raw.get("effect", {})
	move["effect"] = effect if typeof(effect) == TYPE_DICTIONARY else {}
	move["chip_damage"] = maxi(0, int(raw.get("chip_damage", 0)))
	move["energy_cost"] = float(raw.get("energy_cost", 0.0))
	move["energy_gain"] = float(raw.get("energy_gain", 0.0))
	move["ultimate_gain"] = float(raw.get("ultimate_gain", 0.0))
	move["cooldown"] = maxi(0, int(raw.get("cooldown", 0)))
	move["meter_required"] = float(raw.get("meter_required", 0.0))
	move["invulnerable_frames"] = maxi(0, int(raw.get("invulnerable_frames", 0)))
	move["move_speed"] = float(raw.get("move_speed", 0.0))
	move["air_ok"] = bool(raw.get("air_ok", false))
	move["heal"] = maxi(0, int(raw.get("heal", 0)))
	move["energy_gain_on_cast"] = float(raw.get("energy_gain_on_cast", 0.0))
	move["hitbox_offset_x"] = float(hitbox.get("offset_x", 0.0))
	move["hitbox_offset_y"] = float(hitbox.get("offset_y", 0.0))
	move["hitbox_size_x"] = float(hitbox.get("size_x", 0.0))
	move["hitbox_size_y"] = float(hitbox.get("size_y", 0.0))

	var knockback: Variant = raw.get("knockback", {})
	if typeof(knockback) == TYPE_DICTIONARY:
		move["knockback_x"] = float((knockback as Dictionary).get("x", 0.0))
		move["knockback_y"] = float((knockback as Dictionary).get("y", 0.0))

	if move["type"] != "support" and (move["hitbox_size_x"] <= 0.0 or move["hitbox_size_y"] <= 0.0):
		errors.append("Moveset '%s' move '%s' hitbox size must be positive." % [moveset_id, key])
		return {}

	var multi_hit: Variant = raw.get("multi_hit", [])
	if typeof(multi_hit) == TYPE_ARRAY:
		for entry in (multi_hit as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				warnings.append("Moveset '%s' move '%s' has a non-object multi_hit entry." % [moveset_id, key])
				continue
			var phase: Dictionary = entry as Dictionary
			move["multi_hit"].append({
				"start": maxi(0, int(phase.get("start", 0))),
				"length": maxi(1, int(phase.get("length", 1))),
				"damage": maxi(0, int(phase.get("damage", move["damage"]))),
			})

	var projectile: Variant = raw.get("projectile", {})
	if typeof(projectile) == TYPE_DICTIONARY and not (projectile as Dictionary).is_empty():
		var proj: Dictionary = projectile as Dictionary
		move["projectile"] = {
			"lifetime_ticks": maxi(0, int(proj.get("lifetime_ticks", 0))),
			"speed": float(proj.get("speed", 700.0)),
			"range": float(proj.get("range", 600.0)),
			"radius": float(proj.get("radius", 26.0)),
			"spawn_offset_x": float(proj.get("spawn_offset_x", 60.0)),
			"spawn_offset_y": float(proj.get("spawn_offset_y", -70.0)),
			"visual": str(proj.get("visual", "orb")),
		}

	var cancels: Variant = raw.get("cancel_windows", [])
	if typeof(cancels) == TYPE_ARRAY:
		for entry in (cancels as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var window: Dictionary = entry as Dictionary
			move["cancel_windows"].append({
				"from_frame": maxi(0, int(window.get("from_frame", 0))),
				"to_frame": maxi(0, int(window.get("to_frame", 0))),
				"into": window.get("into", []),
				"requires_hit": bool(window.get("requires_hit", false)),
			})

	move["total_frames"] = int(move["startup"]) + int(move["active"]) + int(move["recovery"])
	return move


func get_moveset(moveset_id: String) -> Dictionary:
	return movesets.get(moveset_id, {})


func has_moveset(moveset_id: String) -> bool:
	return movesets.has(moveset_id)


func list_movesets() -> Array:
	return movesets.values()


func summary() -> Dictionary:
	return {
		"count": movesets.size(),
		"ids": movesets.keys(),
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"ok": errors.is_empty(),
	}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("JSON parse error in %s: %s (line %d)" % [path, json.get_error_message(), json.get_error_line()])
		return null
	return json.data
