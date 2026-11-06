extends RefCounted
## Side-view AI opponent.
##
## Fairness rules:
##  * it perceives the opponent through a delayed snapshot queue (never the
##    current frame),
##  * it may only press the same buttons a human can, through the same intent
##    dictionary and the same buffer,
##  * its cadence is quantised to decision intervals, so it cannot react between
##    two simulation ticks.

const States = preload("res://scripts/combat/fighter_states.gd")

var difficulty: int = 1
var reaction_ticks: int = 8
var decision_interval: int = 8
var aggression: float = 0.55

var rng := RandomNumberGenerator.new()
var _tick: int = 0
var _snapshots: Array[Dictionary] = []
var _decision: Dictionary = {}
var _pending_attack: String = ""
var _hold_axis: float = 0.0
var _hold_ticks: int = 0


func _init(difficulty_level: int = 1, seed_value: int = 12345) -> void:
	set_difficulty(difficulty_level)
	rng.seed = seed_value


func set_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, 2)
	match difficulty:
		0:
			reaction_ticks = 14
			decision_interval = 12
			aggression = 0.35
		2:
			reaction_ticks = 5
			decision_interval = 5
			aggression = 0.75
		_:
			reaction_ticks = 9
			decision_interval = 8
			aggression = 0.55


func poll(fighter, opponent) -> Dictionary:
	_tick += 1
	if opponent != null and is_instance_valid(opponent):
		_snapshots.append({
			"tick": _tick,
			"x": opponent.global_position.x,
			"y": opponent.global_position.y,
			"state": opponent.state,
			"hp": opponent.hp,
			"facing": opponent.facing,
			"energy": opponent.special_energy,
		})
	# Drop very old snapshots to keep the queue tiny.
	while not _snapshots.is_empty() and _tick - int(_snapshots[0]["tick"]) > 120:
		_snapshots.pop_front()

	var observed: Dictionary = _delayed_snapshot()
	if _decision.is_empty() or _tick % decision_interval == 0:
		_decide(fighter, observed)

	var intent: Dictionary = {
		"axis": _hold_axis,
		"jump": false,
		"crouch": false,
		"block": bool(_decision.get("block", false)),
		"light": false,
		"heavy": false,
		"special": false,
		"ultimate": false,
	}
	if not _pending_attack.is_empty():
		intent[_pending_attack] = true
		_pending_attack = ""
	if bool(_decision.get("jump_pending", false)):
		intent["jump"] = true
		_decision["jump_pending"] = false
	if bool(_decision.get("crouch", false)):
		intent["crouch"] = true
	return intent


func _delayed_snapshot() -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var target_tick: int = _tick - reaction_ticks
	for index in range(_snapshots.size() - 1, -1, -1):
		if int(_snapshots[index]["tick"]) <= target_tick:
			return _snapshots[index]
	return _snapshots[0]

func _decide(fighter, observed: Dictionary) -> void:
	_decision = {"block": false, "crouch": false, "jump_pending": false}
	if fighter == null or observed.is_empty():
		_hold_axis = 0.0
		return

	var distance: float = observed["x"] - fighter.global_position.x
	var abs_distance: float = absf(distance)
	var toward: float = signf(distance)
	var opponent_state: int = int(observed["state"])
	var opponent_attacking: bool = (
		opponent_state == States.State.ATTACK
		or opponent_state == States.State.SPECIAL
		or opponent_state == States.State.ULTIMATE
	)
	var opponent_stunned: bool = opponent_state == States.State.HITSTUN or opponent_state == States.State.KNOCKDOWN
	var low_hp: bool = fighter.hp < fighter.max_hp * 0.3

	# Defensive reaction first: this is the only place the AI "reads" an attack,
	# and it only reacts to a perception that is reaction_ticks old.
	if opponent_attacking and abs_distance < 230.0:
		var block_chance: float = 0.35 + 0.25 * float(difficulty)
		if low_hp:
			block_chance += 0.1
		if rng.randf() < block_chance:
			_decision["block"] = true
			_hold_axis = 0.0
			return

	if opponent_stunned and abs_distance < 260.0:
		_pick_attack(fighter, abs_distance, true)
		_hold_axis = toward if abs_distance > 120.0 else 0.0
		return

	# Ranged tools when far, melee when close.
	if abs_distance > 420.0 and fighter.special_energy >= 25.0 and rng.randf() < 0.25 + 0.2 * float(difficulty):
		_pending_attack = "special"
		_hold_axis = 0.0
		return
	if fighter.ultimate_meter >= 100.0 and abs_distance > 180.0 and abs_distance < 720.0 and rng.randf() < 0.12:
		_pending_attack = "ultimate"
		_hold_axis = 0.0
		return

	if abs_distance < 190.0:
		if rng.randf() < aggression:
			_pick_attack(fighter, abs_distance, false)
			_hold_axis = 0.0
			return
		if abs_distance < 90.0 and rng.randf() < 0.3:
			_hold_axis = -toward  # step back out of point-blank
			return
		_hold_axis = toward * 0.4
		return

	_hold_axis = toward
	if abs_distance > 240.0 and rng.randf() < 0.02 + 0.03 * float(difficulty) and fighter.grounded:
		_decision["jump_pending"] = true


func _pick_attack(fighter, distance: float, punish: bool) -> void:
	if fighter.ultimate_meter >= 100.0 and rng.randf() < 0.2:
		_pending_attack = "ultimate"
		return
	if distance > 130.0 and fighter.special_energy >= 25.0 and rng.randf() < 0.45:
		_pending_attack = "special"
		return
	if distance < 130.0 and rng.randf() < (0.65 if punish else 0.45):
		_pending_attack = "heavy"
	else:
		_pending_attack = "light"
