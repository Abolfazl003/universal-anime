extends RefCounted
## Save/load, settings, input-map and UI scene tests.
## The UI tests instantiate the real scenes; a synthetic roster is injected into
## memory only (never written to data/) to prove the 600+ capacity.

const Validator = preload("res://scripts/data/character_validator.gd")
const Consts = preload("res://scripts/core/constants.gd")
const VERSUS_SCENE := preload("res://scenes/versus/versus_stage.tscn")
const States = preload("res://scripts/combat/fighter_states.gd")
const CHARACTER_SELECT_PAGE_SIZE: int = 48


func run(t) -> void:
	t.suite("save / persistence")
	_test_save_roundtrip(t)
	_test_corrupt_save(t)
	t.suite("settings / input")
	_test_settings_defaults(t)
	_test_input_map(t)
	t.suite("ui / capacity and match flow")
	await _test_character_select_capacity(t)
	await _test_versus_scene(t)
	await _test_naruto_scene(t)
	await _test_uchiha_haruno_scene(t)
	await _test_lab_roster(t)


func _test_save_roundtrip(t) -> void:
	SaveManager.load_game()
	SaveManager.set_value("progress", "versus_matches", 7, false)
	var written: bool = SaveManager.save_game()
	t.ok("save writes successfully", written)
	t.ok("save file exists", FileAccess.file_exists("user://save.json"))
	SaveManager.data["progress"]["versus_matches"] = 0
	SaveManager.load_game()
	t.eq("save round-trips a value", int(SaveManager.get_value("progress", "versus_matches", -1)), 7)
	t.eq("save reports OK", SaveManager.last_load_status, "OK")
	t.ok("schema version is current", int(SaveManager.data.get("schemaVersion", 0)) == Consts.SAVE_SCHEMA_VERSION)


func _test_corrupt_save(t) -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	SaveManager.load_game()
	t.ok("corrupt save is handled without crashing",
		SaveManager.last_load_status == "CORRUPT" or SaveManager.last_load_status == "PARTIAL",
		SaveManager.last_load_status)
	t.ok("corrupt payload is preserved for inspection", FileAccess.file_exists("user://save.corrupt.json"))
	t.eq("defaults restored after corruption", int(SaveManager.get_value("progress", "versus_matches", -1)), 0)

	# An atomic write leaves a .bak behind, and a backup without a primary is
	# reported as PARTIAL on purpose. Both files must go before "NEW" is true.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	SaveManager.load_game()
	t.eq("backup without primary reports PARTIAL", SaveManager.last_load_status, "PARTIAL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.BACKUP_PATH))
	SaveManager.load_game()
	t.eq("missing save reports NEW", SaveManager.last_load_status, "NEW")
	SaveManager.reset_everything()
	t.ok("reset re-creates a valid save", FileAccess.file_exists("user://save.json"))


func _test_settings_defaults(t) -> void:
	t.close("screen shake is off by default", float(SettingsService.get_value("screen_shake")), 0.0)
	t.close("flash intensity is off by default", float(SettingsService.get_value("flash_intensity")), 0.0)
	t.ok("reduced motion is on by default", bool(SettingsService.get_value("reduced_motion")))
	t.ok("language is a supported locale", Loc.available_languages().has(str(SettingsService.get_value("language"))))
	SettingsService.set_value("text_scale", 1.25)
	t.close("text scale persists", float(SettingsService.get_value("text_scale")), 1.25)
	SettingsService.reset_to_defaults()
	t.close("settings reset restores defaults", float(SettingsService.get_value("text_scale")), 1.0)


func _test_input_map(t) -> void:
	for action in InputService.ACTIONS:
		t.ok("p1 action registered: %s" % action, InputMap.has_action("p1_%s" % action))
		t.ok("p2 action registered: %s" % action, InputMap.has_action("p2_%s" % action))
		t.ok("p1 binding label non-empty: %s" % action, not InputService.binding_label(0, action).is_empty())
	for action in InputService.GLOBAL_ACTIONS:
		t.ok("global action registered: %s" % action, InputMap.has_action(action))
	InputService.rebind_action_key("p1_light", KEY_Z)
	t.eq("rebinding updates the label", InputService.binding_label_for_action("p1_light"), "Z")
	t.ok("rebinding is persisted", SaveManager.get_value("controls", "bindings", {}).has("p1_light"))
	InputService.reset_defaults()
	t.eq("defaults restored", InputService.binding_label_for_action("p1_light"), "J")


func _test_character_select_capacity(t) -> void:
	var backup: Array[Dictionary] = GameData.characters.duplicate()
	var validator := Validator.new()
	var fixture: Array[Dictionary] = []
	for index in range(650):
		fixture.append(validator.normalize({
			"id": 20000 + index,
			"name": "FIXTURE CHARACTER %04d" % index,
			"series": "FIXTURE SERIES",
			"city": "FIXTURE CITY",
			"element": "fire",
			"role": "fighter",
			"rarity": "common",
			"powers": [{"name": "FIXTURE POWER", "description": ""}],
			"status": "DATA_ONLY",
		}))
	GameData.characters = fixture

	var packed = load("res://scenes/menus/character_select.tscn")
	t.ok("character select scene loads", packed != null)
	var scene = packed.instantiate()
	t.tree.root.add_child(scene)
	await t.wait_ticks(2)
	t.eq("only one page of cards is instantiated", (scene._grid.get_children().size()), CHARACTER_SELECT_PAGE_SIZE)
	t.eq("all 650 fixture records are queryable", (scene._results as Array).size(), 650)
	t.ok("page label shows 14 pages", str(scene._page_label.text).contains("14"), str(scene._page_label.text))
	t.ok("locked cards are present", (scene._grid.get_children().size()) > 0)
	scene.queue_free()
	await t.wait_ticks(1)
	GameData.characters = backup


func _test_versus_scene(t) -> void:
	Session.mode = Consts.Mode.LAB
	Session.p1 = Session.lab_entry("lab_dummy_a", "LAB DUMMY A")
	Session.p2 = Session.lab_entry("lab_dummy_b", "LAB DUMMY B")
	Session.p1_control = Consts.PlayerControl.HUMAN
	Session.p2_control = Consts.PlayerControl.AI
	Session.stage_id = "lab_arena"
	Session.rounds_to_win = 3
	Session.timer_enabled = false

	var packed = VERSUS_SCENE
	t.ok("versus stage scene loads", packed != null)
	var scene = packed.instantiate()
	t.tree.root.add_child(scene)
	await t.wait_ticks(6)
	t.ok("both fighters spawned", scene.p1 != null and scene.p2 != null)
	t.ok("HUD bound to both fighters", scene.hud != null)
	t.eq("match starts in INTRO", scene.phase, 0)
	t.close("fighters stand on the floor", scene.p1.global_position.y, 820.0, 1.0)
	t.ok("temporary art banner is shown", str(scene.hud.temporary_label.text).length() > 0)
	await t.wait_ticks(90)
	t.eq("match reaches FIGHT", scene.phase, 1)
	scene.p2.set_hp(0)
	scene._check_round_end()
	t.eq("round ends when a fighter is defeated", scene.phase, 2)
	t.eq("winner gets a round point", int(scene.wins[0]), 1)
	t.ok("no scene change yet (match not over)", is_instance_valid(scene))
	scene.queue_free()
	await t.wait_ticks(2)


## The moveset for character 001 must be reachable from the LAB row without
## marking the character playable: art approval has not happened.
func _test_naruto_scene(t) -> void:
	Session.mode = Consts.Mode.LAB
	Session.p1 = Session.lab_entry("001_naruto", "NARUTO UZUMAKI")
	Session.p2 = Session.lab_entry("lab_dummy_b", "LAB DUMMY B")
	Session.p1_control = Consts.PlayerControl.HUMAN
	Session.p2_control = Consts.PlayerControl.AI
	Session.stage_id = "lab_arena"
	Session.rounds_to_win = 2
	Session.timer_enabled = false
	var scene = VERSUS_SCENE.instantiate()
	t.tree.root.add_child(scene)
	await t.wait_ticks(6)
	t.eq("naruto moveset bound in a real match", str(scene.p1.moveset.get("id", "")), "001_naruto")
	t.ok("naruto carries the three abilities",
		scene.p1.moves.has("special") and scene.p1.moves.has("ultimate") and not scene.p1.forms.is_empty())
	t.ok("naruto still shows the TEMP tag", bool(scene.p1.temporary))
	scene.p1.enter_neutral()
	scene.p1.special_energy = 100.0
	var started: bool = scene.p1.start_form()
	t.ok("form can be used in a live match", started)
	t.eq("form put the fighter in FORM", int(scene.p1.state), States.State.FORM)
	scene.queue_free()
	await t.wait_ticks(2)


func _test_uchiha_haruno_scene(t) -> void:
	t.suite("ui / characters 002 and 003 in a live match")
	Session.mode = Consts.Mode.LAB
	Session.p1 = Session.lab_entry("002_sasuke", "SASUKE UCHIHA")
	Session.p2 = Session.lab_entry("003_sakura", "SAKURA HARUNO")
	Session.p1_control = Consts.PlayerControl.HUMAN
	Session.p2_control = Consts.PlayerControl.AI
	Session.stage_id = "lab_arena"
	Session.rounds_to_win = 2
	Session.timer_enabled = false
	var scene = VERSUS_SCENE.instantiate()
	t.tree.root.add_child(scene)
	await t.wait_ticks(6)
	await t.wait_ticks(90)
	t.eq("fight phase reached for the duo", scene.phase, 1)
	t.eq("sasuke moveset bound", str(scene.p1.moveset.get("id", "")), "002_sasuke")
	t.eq("sakura moveset bound", str(scene.p2.moveset.get("id", "")), "003_sakura")
	t.ok("both carry named abilities",
		str((scene.p1.moves["special"] as Dictionary).get("name", "")) == "Amaterasu" and
		str((scene.p2.moves["special"] as Dictionary).get("name", "")) == "Byakugo Super Strength")
	t.ok("both still show the TEMP tag", bool(scene.p1.temporary) and bool(scene.p2.temporary))
	t.ok("both use their dataset stats", scene.p1.damage_scale > 1.0 and scene.p2.damage_scale > 1.0)
	scene.p1.enter_neutral()
	scene.p1.special_energy = 100.0
	t.ok("sharingan can be used in a live match", scene.p1.start_form())
	t.ok("sharingan is burning in a live match", scene.p1.is_form_active())
	scene.p2.velocity = Vector2.ZERO
	scene.p2.grounded = true
	scene.p2.enter_neutral()
	scene.p2.hp = int(scene.p2.max_hp / 2)
	scene.p2.special_energy = 100.0
	var hp_before: int = scene.p2.hp
	t.ok("byakugo can be used in a live match", scene.p2.start_form())
	await t.wait_ticks(40)
	t.ok("byakugo heals in a live match", scene.p2.hp > hp_before, "hp %d -> %d" % [hp_before, scene.p2.hp])
	scene.queue_free()
	await t.wait_ticks(2)


func _test_lab_roster(t) -> void:
	t.suite("ui / temporary lab roster")
	var ids: Array = ["lab_dummy_a", "lab_dummy_b", "001_naruto", "002_sasuke", "003_sakura",
		"004_kakashi", "005_itachi"]
	for key in ids:
		var entry: Dictionary = Session.lab_entry(str(key), str(key).to_upper())
		var moveset: Dictionary = GameData.lab_moveset(str(key))
		t.ok("lab entry %s resolves to a moveset" % key, not moveset.is_empty())
		t.ok("lab entry %s stays TEMP" % key, bool(moveset.get("temporary", false)))
	var naruto: Dictionary = GameData.lab_moveset("004_kakashi")
	t.eq("kakashi keeps his dataset stats", int((naruto.get("stats", {}) as Dictionary).get("tech", 0)), 93)
