extends Node2D
## Versus match controller: rounds, timer, HUD, pause, results.
## Both modes share the fighter controller and the combat manager; this file only
## owns *match* concerns (round flow, camera framing, bookkeeping).

const Consts = preload("res://scripts/core/constants.gd")
const FighterScript = preload("res://scripts/characters/fighter.gd")
const CombatManagerScript = preload("res://scripts/combat/combat_manager.gd")
const HumanIntent = preload("res://scripts/input/human_intent.gd")
const VersusAI = preload("res://scripts/ai/versus_ai.gd")
const VersusHUD = preload("res://scripts/ui/versus_hud.gd")
const ArenaBackground = preload("res://scripts/versus/arena_background.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

const ROUND_INTRO_TICKS: int = 80
const ROUND_END_TICKS: int = 130
const TEMP_IDLE_POSITIONS: Array[float] = [620.0, 1300.0]

enum Phase { INTRO, FIGHT, ROUND_END, MATCH_END }

var phase: int = Phase.INTRO
var phase_ticks: int = 0
var round_number: int = 1
var wins: Array[int] = [0, 0]
var time_left: float = 60.0
var match_winner: int = -1
var paused: bool = false

var stage: Dictionary = {}
var manager = null
var hud = null
var world = null
var background = null
var camera: Camera2D = null
var p1 = null
var p2 = null

var _intents: Array = [null, null]
var _error_label: Label = null
var _hud_tick: int = 0
var _round_pending_winner: int = -1
var _shake_ticks: int = 0


func _ready() -> void:
	process_priority = -5
	_build()


func _build() -> void:
	if Session == null or not Session.is_versus_ready():
		_show_error("No fighters configured. Go back to Versus Setup.")
		return

	stage = GameData.stage(Session.stage_id)
	if stage.is_empty():
		stage = GameData.stage("lab_arena")
	if stage.is_empty():
		stage = {
			"id": "fallback",
			"name": "LAB ARENA",
			"status": "TEMPORARY",
			"floor_y": 820.0,
			"bounds": {"left": 120.0, "right": 1800.0},
			"palette": {},
		}

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	background = ArenaBackground.new()
	background.name = "Background"
	world.add_child(background)
	background.setup(stage)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(960, 540)
	camera.enabled = true
	world.add_child(camera)
	camera.make_current()

	manager = CombatManagerScript.new()
	manager.name = "Combat"
	world.add_child(manager)
	manager.hit_resolved.connect(_on_hit_resolved)

	p1 = _spawn_fighter(0, Session.p1, true)
	p2 = _spawn_fighter(1, Session.p2, false)
	if p1 == null or p2 == null:
		return
	_intents = [p1.intent_source, p2.intent_source]

	hud = VersusHUD.new()
	add_child(hud)
	hud.bind(p1, p2)

	time_left = Session.round_time if Session.timer_enabled else 0.0
	_start_round()


func _spawn_fighter(slot: int, entry: Dictionary, left_side: bool):
	var moveset: Dictionary = {}
	if str(entry.get("kind", "")) == "lab":
		moveset = GameData.lab_moveset(str(entry.get("moveset", "lab_dummy_a")))
	else:
		moveset = GameData.moveset_for_character(int(entry.get("id", -1)))
	if moveset.is_empty():
		# Never invent a moveset: fall back to a clearly labelled dummy instead of
		# pretending the character is implemented.
		moveset = GameData.lab_moveset("lab_dummy_a")
		entry = entry.duplicate()
		entry["name"] = "%s (MISSING MOVESET)" % str(entry.get("name", "?"))
		entry["temporary"] = true

	var control: int = Session.p1_control if slot == 0 else Session.p2_control
	var intent = null
	if control == Consts.PlayerControl.HUMAN:
		intent = HumanIntent.new(slot)
	elif control == Consts.PlayerControl.AI:
		var ai := VersusAI.new(Session.ai_difficulty, 1000 + slot * 37 + int(Time.get_ticks_msec() % 1000))
		intent = ai

	var fighter = FighterScript.new()
	fighter.name = "P%d" % (slot + 1)
	fighter.setup(moveset, entry, slot, intent)
	manager.add_child(fighter)
	var bounds: Dictionary = stage.get("bounds", {})
	fighter.set_arena(
		float(stage.get("floor_y", 820.0)),
		float(bounds.get("left", 120.0)),
		float(bounds.get("right", 1800.0))
	)
	var spawn: Dictionary = stage.get("spawn", {})
	var spawn_key: String = "p1_x" if left_side else "p2_x"
	var fallback_x: float = TEMP_IDLE_POSITIONS[0] if left_side else TEMP_IDLE_POSITIONS[1]
	var x: float = float(spawn.get(spawn_key, fallback_x))
	fighter.global_position = Vector2(x, float(stage.get("floor_y", 820.0)))
	fighter.facing = 1 if left_side else -1
	fighter.set_active(false)
	return fighter


func _start_round() -> void:
	phase = Phase.INTRO
	phase_ticks = 0
	if Session.timer_enabled:
		time_left = Session.round_time
	var spawn: Dictionary = stage.get("spawn", {})
	p1.respawn(float(spawn.get("p1_x", TEMP_IDLE_POSITIONS[0])))
	p2.respawn(float(spawn.get("p2_x", TEMP_IDLE_POSITIONS[1])))
	p1.facing = 1
	p2.facing = -1
	p1.intent_source = _intents[0]
	p2.intent_source = _intents[1]
	p1.set_active(false)
	p2.set_active(false)
	if hud != null:
		hud.set_round(round_number, wins[0], wins[1])
		hud.set_timer(time_left, Session.timer_enabled)
		hud.set_message(Loc.t("match.intro"))
		hud.set_combo(0, false)


func _begin_fight() -> void:
	phase = Phase.FIGHT
	phase_ticks = 0
	p1.set_active(true)
	p2.set_active(true)
	p1.enter_neutral()
	p2.enter_neutral()
	if hud != null:
		hud.set_message(Loc.t("match.fight"))


func _physics_process(_delta: float) -> void:
	if _error_label != null:
		return
	phase_ticks += 1
	_hud_tick += 1
	if _shake_ticks > 0:
		_shake_ticks -= 1
		if camera != null:
			var strength: float = float(SettingsService.get_value("screen_shake"))
			camera.offset = Vector2(randf_range(-strength, strength) * 10.0, randf_range(-strength, strength) * 6.0)
	elif camera != null and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	match phase:
		Phase.INTRO:
			if phase_ticks >= ROUND_INTRO_TICKS:
				_begin_fight()
		Phase.FIGHT:
			if Session.timer_enabled:
				time_left = maxf(0.0, time_left - 1.0 / 60.0)
			_check_round_end()
		Phase.ROUND_END:
			if phase_ticks >= ROUND_END_TICKS:
				_advance_after_round()
		Phase.MATCH_END:
			pass

	if hud != null:
		hud.set_timer(time_left, Session.timer_enabled)
		if _hud_tick % 6 == 0:
			hud.refresh_states()
			var combo_source = p1 if p1.combo_count > 1 else p2
			hud.set_combo(combo_source.combo_count, combo_source == p2)
	if GameDebug != null:
		GameDebug.report_state("%s vs %s | %s" % [p1.state_name(), p2.state_name(), _phase_name()])


func _check_round_end() -> void:
	var p1_dead: bool = p1.hp <= 0
	var p2_dead: bool = p2.hp <= 0
	if p1_dead or p2_dead:
		if p1_dead and p2_dead:
			_end_round(-1, Loc.t("match.draw"))
		elif p2_dead:
			_end_round(0, Loc.t("hud.ko"))
		else:
			_end_round(1, Loc.t("hud.ko"))
		return
	if Session.timer_enabled and time_left <= 0.0:
		if p1.hp == p2.hp:
			_end_round(-1, Loc.t("match.time_up"))
		elif p1.hp > p2.hp:
			_end_round(0, Loc.t("match.time_up"))
		else:
			_end_round(1, Loc.t("match.time_up"))


func _end_round(winner_index: int, reason: String) -> void:
	phase = Phase.ROUND_END
	phase_ticks = 0
	_round_pending_winner = winner_index
	if winner_index >= 0:
		wins[winner_index] += 1
		var winner = p1 if winner_index == 0 else p2
		var loser = p2 if winner_index == 0 else p1
		winner.celebrate()
		loser.set_active(false)
		winner.set_active(false)
		if hud != null:
			hud.set_message("%s  %s" % [reason, Loc.t("match.round_win", [winner.display_name])])
	else:
		if hud != null:
			hud.set_message(reason)
	p1.set_active(false)
	p2.set_active(false)
	if hud != null:
		hud.set_round(round_number, wins[0], wins[1])


func _advance_after_round() -> void:
	if wins[0] >= Session.rounds_to_win or wins[1] >= Session.rounds_to_win:
		_finish_match()
		return
	round_number += 1
	_start_round()


func _finish_match() -> void:
	phase = Phase.MATCH_END
	match_winner = 0 if wins[0] > wins[1] else (1 if wins[1] > wins[0] else -1)
	var result: Dictionary = {
		"mode": "versus",
		"winner": match_winner,
		"p1": str(Session.p1.get("name", "P1")),
		"p2": str(Session.p2.get("name", "P2")),
		"wins": wins.duplicate(),
		"rounds": round_number,
		"temporary": bool(p1.temporary or p2.temporary),
	}
	SaveManager.record_result("versus", result)
	SceneRouter.change_scene("res://scenes/menus/results.tscn", result)


func _on_hit_resolved(_attacker, target, result: Dictionary, _move_id: String) -> void:
	if not bool(result.get("applied", false)):
		return
	if bool(result.get("blocked", false)):
		return
	if SettingsService.shake_enabled():
		_shake_ticks = 8
	if hud != null and target == p2:
		hud.set_combo(p1.combo_count, false)
	elif hud != null and target == p1:
		hud.set_combo(p2.combo_count, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not SceneRouter.has_overlay() and phase != Phase.MATCH_END:
		_open_pause()
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	SceneRouter.push_overlay("res://scenes/menus/pause_menu.tscn", {"context": "versus"})
	get_tree().paused = true


func _phase_name() -> String:
	match phase:
		Phase.INTRO:
			return "INTRO"
		Phase.FIGHT:
			return "FIGHT"
		Phase.ROUND_END:
			return "ROUND_END"
		_:
			return "MATCH_END"


func _show_error(message: String) -> void:
	_error_label = UIKit.label(message, 1.2, UIKit.DANGER)
	_error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_error_label)
	_physics_process_enabled(false)


func _physics_process_enabled(value: bool) -> void:
	set_physics_process(value)
