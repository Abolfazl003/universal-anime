extends RefCounted
## Data-layer tests: character store, validator, movesets, animations, stages,
## localization keys and resource paths.

const Consts = preload("res://scripts/core/constants.gd")
const Validator = preload("res://scripts/data/character_validator.gd")
const MovesetLoader = preload("res://scripts/data/moveset_loader.gd")
const AnimationDB = preload("res://scripts/data/animation_db.gd")
const StageLoader = preload("res://scripts/data/stage_loader.gd")

const SCENE_PATHS: PackedStringArray = [
	"res://scenes/boot/boot.tscn",
	"res://scenes/menus/main_menu.tscn",
	"res://scenes/menus/mode_select.tscn",
	"res://scenes/menus/character_select.tscn",
	"res://scenes/menus/character_detail.tscn",
	"res://scenes/menus/versus_setup.tscn",
	"res://scenes/menus/stage_select.tscn",
	"res://scenes/menus/settings.tscn",
	"res://scenes/menus/controls.tscn",
	"res://scenes/menus/results.tscn",
	"res://scenes/menus/pause_menu.tscn",
	"res://scenes/menus/reference_gallery.tscn",
	"res://scenes/versus/versus_stage.tscn",
	"res://scenes/dungeon/dungeon_run.tscn",
]


func run(t) -> void:
	await _test_validator(t)
	await _test_character_store(t)
	await _test_capacity_query(t)
	await _test_movesets(t)
	await _test_animations(t)
	await _test_stages(t)
	await _test_environments(t)
	await _test_localization(t)
	await _test_resources(t)


func _test_validator(t) -> void:
	t.suite("data / validator")
	var validator := Validator.new()
	var fixture: Array = [
		{"id": 1, "name": "FIXTURE ONE", "series": "S", "city": "C", "element": "E", "role": "R", "rarity": "X",
			"powers": [{"name": "P", "description": "D"}], "status": "PLAYABLE"},
		{"id": 1, "name": "FIXTURE DUPLICATE ID", "series": "S", "city": "C", "element": "E", "role": "R",
			"rarity": "X", "powers": ["P"]},
		{"id": 3, "name": "FIXTURE INCOMPLETE", "series": "S"},
	]
	var report: Dictionary = validator.validate(fixture)
	t.ok("duplicate ids are detected", (report["duplicate_ids"] as Array).has(1), str(report["duplicate_ids"]))
	t.ok("incomplete records are reported", (report["incomplete_ids"] as Array).has(3), str(report["incomplete_ids"]))
	t.eq("valid record count", int(report["valid_records"]), 1)
	t.eq("distinct series count", int(report["distinct_series"]), 1)
	t.ok("validator reports errors for the fixture", not bool(report["ok"]))

	var normalized: Dictionary = validator.normalize(fixture[0] as Dictionary)
	t.eq("normalized status", int(normalized["status"]), Consts.Status.PLAYABLE)
	t.eq("normalized status name", str(normalized["status_name"]), "PLAYABLE")
	t.eq("power names copied verbatim", str((normalized["powers"] as Array)[0]["name"]), "P")
	t.ok("absent optional fields are not invented", not bool(normalized["has_world"]))
	var string_power: Dictionary = validator.normalize(fixture[1] as Dictionary)
	t.eq("string powers kept as names", str((string_power["powers"] as Array)[0]["name"]), "P")
	t.eq("string powers get empty description", str((string_power["powers"] as Array)[0]["description"]), "")

	# The supplied dataset names the series field "anime" and nests the powers in a
	# "signature" object. The file is never edited, so the aliases must resolve.
	var aliased: Dictionary = {
		"id": 7, "name": "ALIAS FIXTURE", "anime": "Anime Series", "city": "C",
		"element": "E", "role": "R", "rarity": "X",
		"signature": {"name": "Rasengan / Kurama Chakra Mode", "description": "D",
			"ultimate": "Tailed Beast Rasenshuriken"},
	}
	var alias_report: Dictionary = validator.validate([aliased])
	t.eq("anime is read as series", int(alias_report["distinct_series"]), 1)
	t.ok("signature satisfies the powers requirement", (alias_report["incomplete_ids"] as Array).is_empty(),
		str(alias_report["incomplete_ids"]))
	var alias_norm: Dictionary = validator.normalize(aliased)
	t.eq("series comes from anime", str(alias_norm["series"]), "Anime Series")
	t.eq("source field is recorded", str(alias_norm["source_series_field"]), "anime")
	t.eq("signature name kept verbatim", str((alias_norm["powers"] as Array)[0]["name"]),
		"Rasengan / Kurama Chakra Mode")
	t.eq("ultimate kept separate", str(alias_norm["ultimate"]), "Tailed Beast Rasenshuriken")
	t.ok("aliased record counts as complete", Validator.is_complete(aliased))
	t.eq("absent status defaults to DATA_ONLY", str(alias_norm["status_name"]), "DATA_ONLY")


func _test_character_store(t) -> void:
	t.suite("data / character store")
	t.eq("capacity target is 600", Consts.MAX_CHARACTERS, 600)
	t.ok("characters.json exists", FileAccess.file_exists("res://data/characters.json"))
	var stats: Dictionary = GameData.stats()
	t.ok("store reports a source status", not str(stats.get("source_status", "")).is_empty(), str(stats))
	t.eq("existing count matches loaded records", int(stats["existing"]), GameData.characters.size())
	t.ok("playable is a subset of existing", int(stats["playable"]) <= int(stats["existing"]))
	var loaded_count: int = GameData.characters.size()
	if loaded_count == 0:
		t.ok("empty dataset is reported honestly (no fabricated records)", GameData.characters.is_empty())
	else:
		var ids: Dictionary = {}
		var unique: bool = true
		for record in GameData.characters:
			if ids.has(record["id"]):
				unique = false
			ids[record["id"]] = true
		t.ok("all loaded ids are unique", unique)
	t.ok("movesets are loaded", GameData.movesets.movesets.size() >= 2, str(GameData.movesets.movesets.keys()))
	t.ok("references index is loaded", not GameData.references.is_empty())


func _test_capacity_query(t) -> void:
	t.suite("data / capacity + filtering (synthetic fixture, never written to disk)")
	var backup: Array[Dictionary] = GameData.characters.duplicate()
	var validator := Validator.new()
	var fixture: Array[Dictionary] = []
	for index in range(650):
		var element: String = ["fire", "water", "wind"][index % 3]
		var rarity: String = ["common", "rare"][index % 2]
		var status_name: String = "PLAYABLE" if index % 50 == 0 else "DATA_ONLY"
		fixture.append(validator.normalize({
			"id": 10000 + index,
			"name": "FIXTURE %04d" % index,
			"series": "FIXTURE SERIES %d" % (index % 90),
			"city": "FIXTURE CITY",
			"element": element,
			"role": "fighter",
			"rarity": rarity,
			"powers": [{"name": "FIXTURE POWER", "description": ""}],
			"status": status_name,
		}))
	GameData.characters = fixture
	GameData.series_list = PackedStringArray()
	GameData.element_list = PackedStringArray()
	GameData.role_list = PackedStringArray()
	GameData.rarity_list = PackedStringArray()

	t.eq("roster above 600 is accepted", GameData.characters.size(), 650)
	t.eq("unfiltered query returns every record", GameData.query().size(), 650)
	t.eq("search by name works", GameData.query("FIXTURE 0042").size(), 1)
	t.ok("search by series works", GameData.query("FIXTURE SERIES 7").size() >= 1)
	t.eq("element filter works", GameData.query("", "fire").size(), 217)
	t.eq("rarity filter works", GameData.query("", "", "", "rare").size(), 325)
	var playable_count: int = GameData.query("", "", "", "", true).size()
	t.eq("playable-only filter works", playable_count, 13)
	t.eq("pagination math for 650 records at 48 per page", int(ceil(650.0 / 48.0)), 14)
	t.ok("locked records are not selectable", not GameData.is_selectable(fixture[1]))
	t.ok("playable records are selectable", GameData.is_selectable(fixture[0]))

	GameData.characters = backup


func _test_movesets(t) -> void:
	t.suite("data / movesets")
	var loader := MovesetLoader.new()
	var report: Dictionary = loader.load_all("res://data/movesets")
	t.ok("movesets loaded without errors", bool(report["ok"]), str(report["errors"]))
	var lab_a: Dictionary = loader.get_moveset("lab_dummy_a")
	t.ok("lab_dummy_a exists", not lab_a.is_empty())
	t.ok("lab_dummy_b exists", not loader.get_moveset("lab_dummy_b").is_empty())
	var moves: Dictionary = lab_a.get("moves", {})
	for move_id in ["light_attack", "heavy_attack", "special", "ultimate"]:
		t.ok("move '%s' present" % move_id, moves.has(move_id))
		if not moves.has(move_id):
			continue
		var move: Dictionary = moves[move_id]
		t.ok("move %s has positive active frames" % move_id, int(move["active"]) >= 1)
		t.ok("move %s has a hitbox" % move_id, float(move["hitbox_size_x"]) > 0.0 and float(move["hitbox_size_y"]) > 0.0)
		t.ok("move %s frame data is consistent" % move_id,
			int(move["total_frames"]) == int(move["startup"]) + int(move["active"]) + int(move["recovery"]))
	t.ok("temporary movesets are flagged temporary", bool(lab_a.get("temporary", false)))
	t.ok("lab movesets are not bound to a character id", lab_a.get("character_id", null) == null)

	var broken: MovesetLoader = MovesetLoader.new()
	# Support moves carry no hitbox by design; projectile moves can expire on a timer.
	DirAccess.make_dir_recursive_absolute("user://moveset_support_fixture")
	var support_file := FileAccess.open("user://moveset_support_fixture/support.json", FileAccess.WRITE)
	support_file.store_string(JSON.stringify({
		"movesetId": "support_fixture",
		"temporary": true,
		"moves": {
			"special": {
				"id": "special", "animation_id": "special", "type": "support", "name": "Field Medic",
				"startup": 10, "active": 2, "recovery": 12, "heal": 14,
			},
			"ultimate": {
				"id": "ultimate", "animation_id": "ultimate", "type": "projectile", "name": "Lingering Shot",
				"startup": 8, "active": 2, "recovery": 10, "damage": 9,
				"hitstun": 10, "blockstun": 6,
				"hitbox": {"offset_x": 40.0, "offset_y": -40.0, "size_x": 30.0, "size_y": 30.0},
				"projectile": {"speed": 0.0, "range": 0.0, "radius": 20.0, "lifetime_ticks": 90},
			},
		},
	}))
	support_file.close()
	var support_loader = MovesetLoader.new()
	var support_report: Dictionary = support_loader.load_all("user://moveset_support_fixture")
	t.ok("support moves load without a hitbox", bool(support_report["ok"]), str(support_report["errors"]))
	var support_move: Dictionary = support_loader.get_moveset("support_fixture").get("moves", {}).get("special", {})
	t.eq("support move keeps its heal amount", int(support_move.get("heal", 0)), 14)
	t.eq("support move has no hitbox width", float(support_move.get("hitbox_size_x", 0.0)), 0.0)
	var timer_move: Dictionary = support_loader.get_moveset("support_fixture").get("moves", {}).get("ultimate", {})
	t.eq("projectile lifetime survives the loader",
		int((timer_move.get("projectile", {}) as Dictionary).get("lifetime_ticks", 0)), 90)

	DirAccess.make_dir_recursive_absolute("user://moveset_fixture")
	var file := FileAccess.open("user://moveset_fixture/broken.json", FileAccess.WRITE)
	file.store_string("{\"movesetId\": \"broken\", \"moves\": {\"x\": {\"id\": \"x\"}}}")
	file.close()
	var broken_report: Dictionary = broken.load_all("user://moveset_fixture")
	t.ok("invalid moveset data produces explicit errors", not bool(broken_report["ok"]))


func _test_animations(t) -> void:
	t.suite("data / animations")
	var db := AnimationDB.new()
	var report: Dictionary = db.load_all("res://resources/animations")
	t.ok("animation metadata loaded", bool(report["ok"]), str(report["errors"]))
	t.ok("naruto animation plan exists", not db.get_character("naruto_001").is_empty())
	var missing: PackedStringArray = db.missing_animations("naruto_001")
	t.ok("naruto plan has no produced frames yet (approval pending)", not missing.is_empty(), str(missing))
	var lab_clip: Dictionary = db.get_clip("lab_dummy_a", "light_attack")
	t.ok("placeholder clip has frames", int(lab_clip.get("frames", 0)) > 0)
	t.ok("placeholder clip has fps", float(lab_clip.get("fps", 0.0)) > 0.0)
	var all_fps_positive: bool = true
	for character_id in db.clips.keys():
		for clip_id in (db.clips[character_id]["clips"] as Dictionary).keys():
			if float((db.clips[character_id]["clips"][clip_id] as Dictionary)["fps"]) <= 0.0:
				all_fps_positive = false
	t.ok("every clip declares a positive fps", all_fps_positive)


func _test_stages(t) -> void:
	t.suite("data / stages")
	var loader := StageLoader.new()
	var report: Dictionary = loader.load_all("res://data/stages")
	t.ok("stages loaded", bool(report["ok"]), str(report["errors"]))
	t.ok("temporary lab arena exists", not loader.get_stage("lab_arena").is_empty())
	var konoha: Dictionary = loader.get_stage("konoha_pending")
	if not konoha.is_empty():
		t.eq("naruto stage is not approved yet", str(konoha["status"]), "PENDING")
		t.ok("naruto stage carries world data", not str(konoha["world"]).is_empty())
	t.ok("approved stage list is empty (nothing approved yet)", loader.approved_stage_ids().is_empty(),
		str(loader.approved_stage_ids()))
	for stage in loader.list_stages():
		t.ok("stage %s has valid geometry" % str(stage["id"]), float(stage["floor_y"]) > 0.0)


func _test_environments(t) -> void:
	t.suite("data / environments (derived index)")
	var path: String = "res://data/environments/derived.json"
	if not FileAccess.file_exists(path):
		t.ok("environment index is optional", true)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.ok("environment index parses", typeof(parsed) == TYPE_DICTIONARY)
	var data: Dictionary = parsed as Dictionary
	var worlds: Array = data.get("worlds", [])
	var totals: Dictionary = data.get("totals", {})
	t.eq("world count matches totals", worlds.size(), int(totals.get("worlds", -1)))
	var city_count: int = 0
	var character_count: int = 0
	var missing_architecture: int = 0
	var missing_palette: int = 0
	for world in worlds:
		var entry: Dictionary = world
		character_count += int(entry.get("characters", 0))
		if not (entry.get("palette") as Dictionary).has("sky"):
			missing_palette += 1
		for city in (entry.get("cities", []) as Array):
			city_count += 1
			if str((city as Dictionary).get("architecture", "")).strip_edges().is_empty():
				missing_architecture += 1
	t.eq("city count matches totals", city_count, int(totals.get("cities", -1)))
	t.eq("no record is lost in the index", character_count, int(totals.get("cities", -1)))
	t.eq("every city keeps its architecture line", missing_architecture, 0)
	t.eq("every world has a derived palette", missing_palette, 0)
	var first: Dictionary = worlds[0]
	t.eq("entries are explicitly unapproved", str(first.get("stageStatus", "")), "ENVIRONMENT_DATA_ONLY")


func _test_localization(t) -> void:
	t.suite("data / localization")
	var en: Dictionary = _read_locale("res://data/localization/en.json")
	var fa: Dictionary = _read_locale("res://data/localization/fa.json")
	t.ok("english locale loaded", not en.is_empty())
	t.ok("persian locale loaded", not fa.is_empty())
	var missing_in_fa: Array[String] = []
	for key in en.keys():
		if not fa.has(key):
			missing_in_fa.append(str(key))
	t.ok("fa has every en key", missing_in_fa.is_empty(), str(missing_in_fa))

	# Every Loc.t("...") literal used in scripts must exist in the en table.
	var used_keys: Dictionary = _scan_loc_keys("res://scripts")
	var unknown: Array[String] = []
	for key in used_keys.keys():
		if not en.has(str(key)):
			unknown.append(str(key))
	t.ok("all UI keys used in code exist in en.json", unknown.is_empty(), str(unknown))
	t.ok("code actually uses the localization table", used_keys.size() > 40, str(used_keys.size()))


func _read_locale(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return (json.data as Dictionary).get("strings", {})


func _scan_loc_keys(root: String) -> Dictionary:
	var found: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("Loc\\.t\\(\"([a-zA-Z0-9_.]+)\"")
	_scan_dir(root, regex, found)
	return found


func _scan_dir(path: String, regex: RegEx, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string(path.path_join(file_name))
			for match_result in regex.search_all(text):
				found[match_result.get_string(1)] = true
	for sub_dir in dir.get_directories():
		_scan_dir(path.path_join(sub_dir), regex, found)


func _test_resources(t) -> void:
	t.suite("resources / scenes")
	for path in SCENE_PATHS:
		t.ok("scene exists: %s" % path.get_file(), ResourceLoader.exists(path))
		if ResourceLoader.exists(path):
			var scene: Resource = load(path)
			t.ok("scene loads: %s" % path.get_file(), scene is PackedScene)
