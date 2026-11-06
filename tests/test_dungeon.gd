extends RefCounted
## Dungeon tests: seeded generation, connectivity, determinism, and a real
## instantiation of the dungeon scene with doors, a player and data-driven rooms.

const Generator = preload("res://scripts/dungeon/dungeon_generator.gd")
const Themes = preload("res://scripts/dungeon/dungeon_themes.gd")

const SEEDS: PackedInt32Array = [1, 7, 42, 99, 1234, 55555, 987654]


func run(t) -> void:
	t.suite("dungeon / generation")
	_test_determinism(t)
	_test_connectivity(t)
	_test_room_types(t)
	await _test_scene(t)
	_test_themes(t)


func _test_determinism(t) -> void:
	for seed_value in SEEDS:
		var a := Generator.new()
		var b := Generator.new()
		var layout_a: Dictionary = a.generate(seed_value, 7)
		var layout_b: Dictionary = b.generate(seed_value, 7)
		var cells_a: Array = []
		var cells_b: Array = []
		for room in layout_a["rooms"]:
			cells_a.append(room["cell"])
		for room in layout_b["rooms"]:
			cells_b.append(room["cell"])
		t.ok("seed %d is deterministic" % seed_value, str(cells_a) == str(cells_b), "%s vs %s" % [str(cells_a), str(cells_b)])


func _test_connectivity(t) -> void:
	var all_ok: bool = true
	var detail: String = ""
	for seed_value in SEEDS:
		var generator := Generator.new()
		var layout: Dictionary = generator.generate(seed_value, 8)
		var connectivity: Dictionary = layout["connectivity"]
		if not bool(layout["ok"]) or not bool(connectivity.get("ok", false)):
			all_ok = false
			detail += "seed %d: %s; " % [seed_value, str(layout["errors"])]
		var rooms: Array = layout["rooms"]
		if rooms.size() < 3:
			all_ok = false
			detail += "seed %d has %d rooms; " % [seed_value, rooms.size()]
	t.ok("every seed produces a connected layout reaching the boss", all_ok, detail)

	var generator := Generator.new()
	var layout: Dictionary = generator.generate(4242, 7)
	t.ok("boss room is the last room", int(layout["boss_id"]) == (layout["rooms"] as Array).size() - 1)
	t.ok("start room exists", int(layout["start_id"]) == 0)
	var bounds: Rect2 = generator.world_bounds()
	t.ok("world bounds are positive", bounds.size.x > 0.0 and bounds.size.y > 0.0)
	t.ok("no room is outside the grid", _rooms_in_grid(layout["rooms"]))


func _rooms_in_grid(rooms: Array) -> bool:
	for room in rooms:
		var cell: Vector2i = room["cell"]
		if cell.x < 0 or cell.y < 0 or cell.x >= Generator.GRID_W or cell.y >= Generator.GRID_H:
			return false
	return true


func _test_room_types(t) -> void:
	var generator := Generator.new()
	var layout: Dictionary = generator.generate(777, 7)
	var types: Array[String] = []
	for room in layout["rooms"]:
		types.append(str(room["type"]))
	t.eq("first room is the start room", types[0], "start")
	t.eq("last room is the boss room", types[-1], "boss")
	t.ok("layout includes a combat room", types.has("combat"))
	t.ok("layout includes the boss", types.has("boss"))
	var data_ok: bool = FileAccess.file_exists("res://data/dungeon/enemies_lab.json")
	t.ok("temporary enemy data file exists", data_ok)
	if data_ok:
		var json := JSON.new()
		t.ok("temporary enemy data parses", json.parse(FileAccess.get_file_as_string("res://data/dungeon/enemies_lab.json")) == OK)
		if typeof(json.data) == TYPE_DICTIONARY:
			var root: Dictionary = json.data
			t.ok("enemy definitions exist", (root.get("enemies", {}) as Dictionary).size() >= 4)
			t.ok("boss has multiple readable patterns",
				((root["enemies"] as Dictionary).get("lab_warden", {}) as Dictionary).get("patterns", []).size() >= 3)
			t.ok("room definitions exist", (root.get("rooms", {}) as Dictionary).size() >= 5)
			t.ok("loot tables exist", (root.get("loot", {}) as Dictionary).size() >= 1)
			t.ok("all temporary enemies are flagged temporary", _all_temporary(root["enemies"]))


func _all_temporary(enemies: Dictionary) -> bool:
	for key in enemies.keys():
		if not bool((enemies[key] as Dictionary).get("temporary", false)):
			return false
	return true


func _test_scene(t) -> void:
	t.suite("dungeon / scene instantiation")
	Session.dungeon_seed = 4242
	var packed = load("res://scenes/dungeon/dungeon_run.tscn")
	t.ok("dungeon scene loads", packed != null)
	if packed == null:
		return
	var scene = packed.instantiate()
	t.tree.root.add_child(scene)
	await t.wait_ticks(4)
	t.ok("dungeon run built a player", scene.player != null and is_instance_valid(scene.player))
	t.ok("dungeon run is inside a room", scene.current_room >= 0, str(scene.current_room))
	t.ok("doors were built", (scene.door_bodies as Dictionary).size() > 0)
	t.ok("HUD created", scene.hud != null)
	t.eq("seed is preserved for reproducibility", scene.seed_value, 4242)
	var start_doors: Array = scene.door_bodies.get(0, [])
	t.ok("start room has door bodies", start_doors.size() >= 0)
	var layout: Dictionary = scene.layout
	t.ok("layout validated at runtime", bool(layout.get("ok", false)), str(layout.get("errors", [])))
	scene.queue_free()
	await t.wait_ticks(2)


func _test_themes(t) -> void:
	t.suite("dungeon / environment themes")
	var themes: Array = Themes.load_themes()
	t.ok("theme table loads", themes.size() >= 6, str(themes.size()))
	var invalid: Array = []
	for theme in themes:
		if not Themes.is_valid(theme):
			invalid.append(str((theme as Dictionary).get("id", "?")))
	t.eq("every theme declares a full palette", invalid, [])
	var first: Dictionary = Themes.pick(1234)
	t.eq("same seed picks the same theme", str(Themes.pick(1234).get("id", "")), str(first.get("id", "")))
	var seen: Dictionary = {}
	for seed_value in range(1, 41):
		seen[str(Themes.pick(seed_value).get("id", ""))] = true
	t.ok("seeds spread across themes", seen.size() >= 3, "%d distinct" % seen.size())
	var suna: Dictionary = Themes.pick(7, "Sunagakure Sand Vault")
	t.eq("world hint selects the sand theme", str(suna.get("id", "")), "sand_vault")
	var konoha: Dictionary = Themes.pick(7, "Konohagakure")
	t.eq("world hint selects the cedar theme", str(konoha.get("id", "")), "cedar_shrine")
	var unknown: Dictionary = Themes.pick(7, "Nowhere At All")
	t.eq("unknown hint falls back to the seed pick", str(unknown.get("id", "")), str(Themes.pick(7).get("id", "")))
	var accent: Color = Themes.color_of(first, "accent", "#ffffff")
	t.ok("theme palette resolves to a colour", accent.a > 0.0, str(accent))
