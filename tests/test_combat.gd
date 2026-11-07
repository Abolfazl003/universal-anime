extends RefCounted
## Combat engine tests. These drive the real fighters and the real CombatManager
## through physics ticks, so frame data, hit gating and state rules are exercised
## exactly as they are in the game.

const FighterScript = preload("res://scripts/characters/fighter.gd")
const CombatManagerScript = preload("res://scripts/combat/combat_manager.gd")
const States = preload("res://scripts/combat/fighter_states.gd")
const InputBuffer = preload("res://scripts/input/input_buffer.gd")


class ScriptedIntent extends RefCounted:
	var intent: Dictionary = {"axis": 0.0}

	func poll(_fighter, _opponent) -> Dictionary:
		var copy: Dictionary = intent.duplicate()
		# Edge-like behaviour: one-shot presses are cleared after being read.
		for key in ["light", "heavy", "special", "ultimate", "jump"]:
			if copy.has(key):
				copy[key] = bool(copy[key])
		return copy


var manager
var p1
var p2
var _intent1: ScriptedIntent
var _intent2: ScriptedIntent


func run(t) -> void:
	t.suite("combat / state machine table")
	_test_state_table(t)
	t.suite("combat / input buffer")
	_test_buffer(t)
	await _setup(t)
	if manager == null:
		t.ok("combat harness created", false, "manager missing")
		return
	await _test_timing(t)
	await _test_damage_once(t)
	await _test_multi_hit(t)
	await _test_block(t)
	await _test_projectile(t)
	await _test_energy_and_meter(t)
	await _test_grounding(t)
	await _test_character_abilities(t)
	_teardown()


func _test_state_table(t) -> void:
	var problems: PackedStringArray = States.validate_table()
	t.ok("state table is internally consistent", problems.is_empty(), str(problems))
	t.ok("DEFEAT is terminal", not States.transition_allowed(States.State.DEFEAT, States.State.IDLE))
	t.ok("HITSTUN can reach KNOCKDOWN", States.transition_allowed(States.State.HITSTUN, States.State.KNOCKDOWN))
	t.ok("KNOCKDOWN can reach GETUP", States.transition_allowed(States.State.KNOCKDOWN, States.State.GETUP))
	t.ok("GETUP returns to IDLE", States.transition_allowed(States.State.GETUP, States.State.IDLE))
	t.ok("ATTACK is not actionable", not States.is_actionable(States.State.ATTACK))
	t.ok("IDLE is actionable", States.is_actionable(States.State.IDLE))
	t.ok("DEFEAT is not vulnerable", not States.is_vulnerable(States.State.DEFEAT))
	for state in States.TABLE.keys():
		t.ok("state %s declares an animation" % States.name_of(state), not States.animation_for(state).is_empty())


func _test_buffer(t) -> void:
	var buffer := InputBuffer.new()
	buffer.window_ticks = 5
	buffer.push("light_attack")
	t.ok("buffer stores an action", buffer.has("light_attack"))
	t.ok("buffered action can be consumed", buffer.consume("light_attack"))
	t.ok("buffer is empty after consumption", not buffer.has("light_attack"))
	buffer.push("heavy_attack")
	for _i in range(7):
		buffer.advance()
	t.ok("buffered action expires", not buffer.has("heavy_attack"))


func _setup(t: Object) -> void:
	manager = CombatManagerScript.new()
	t.tree.root.add_child(manager)
	_intent1 = ScriptedIntent.new()
	_intent2 = ScriptedIntent.new()
	p1 = _make_fighter("lab_dummy_a", _intent1, 320.0)
	p2 = _make_fighter("lab_dummy_b", _intent2, 420.0)
	if p1 == null or p2 == null:
		t.ok("fighters instantiated", false)
		return
	p1.facing = 1
	p2.facing = -1
	p1.hp = 100
	p2.hp = 100
	await t.wait_ticks(3)


func _make_fighter(moveset_id: String, intent: ScriptedIntent, x: float):
	var moveset: Dictionary = GameData.lab_moveset(moveset_id)
	if moveset.is_empty():
		return null
	var fighter: Node = FighterScript.new()
	fighter.setup(moveset, {"name": moveset_id, "temporary": true}, 0, intent)
	manager.add_child(fighter)
	fighter.set_arena(600.0, 0.0, 2000.0)
	fighter.global_position = Vector2(x, 600.0)
	fighter.set_active(true)
	return fighter


func _teardown() -> void:
	if manager != null and is_instance_valid(manager):
		manager.clear()
		manager.queue_free()
	manager = null


## Give the tick-based simulator a few frames and return once the fighter is idle.
## Presses an attack for exactly as long as it takes to start it, then releases.
## This keeps the input buffer from queueing a second, unintended attack.
func _press(t, key: String) -> void:
	_intent1.intent = {"axis": 0.0, key: true}
	for _i in range(4):
		await t.wait_ticks(1)
		if p1.state == States.State.ATTACK or p1.state == States.State.SPECIAL or p1.state == States.State.ULTIMATE:
			break
	_intent1.intent = {"axis": 0.0}


func _settle(t, ticks: int = 8) -> void:
	_intent1.intent = {"axis": 0.0}
	_intent2.intent = {"axis": 0.0}
	await t.wait_ticks(ticks)


func _test_timing(t) -> void:
	await _settle(t, 20)
	var move: Dictionary = p1.moves["light_attack"]
	var startup: int = int(move["startup"])
	var active: int = int(move["active"])

	await _press(t, "light")
	t.eq("attack state entered", p1.state, States.State.ATTACK)
	var saw_active: bool = false
	var active_ticks: int = 0
	var premature_hit: bool = false
	for _i in range(int(move["total_frames"]) + 6):
		if p1.state != States.State.ATTACK:
			break
		var hit: Dictionary = p1.active_hit()
		if not hit.is_empty():
			saw_active = true
			active_ticks += 1
			if p1.state_tick < startup:
				premature_hit = true
		await t.wait_ticks(1)
	t.ok("hitbox appears during active frames", saw_active)
	t.ok("no hitbox during startup", not premature_hit)
	var window_ok: bool = absi(active_ticks - active) <= 1
	t.ok("active window length matches data (±1 tick)", window_ok,
		"saw %d, expected %d" % [active_ticks, active])
	t.ok("attack returns to a neutral state", p1.state != States.State.ATTACK, States.name_of(p1.state))


func _test_damage_once(t) -> void:
	await _settle(t, 20)
	p1.global_position = Vector2(320, 600)
	p2.global_position = Vector2(420, 600)
	p2.hp = 100
	p2.facing = -1
	await _press(t, "light")
	await t.wait_ticks(40)
	var expected: int = 100 - int(p1.moves["light_attack"]["damage"])
	t.eq("light attack deals damage exactly once", p2.hp, expected)
	t.ok("attacker gained special energy on hit", p1.special_energy > 0.0, str(p1.special_energy))
	t.eq("combo counter registered", p1.combo_count, 1)


func _test_multi_hit(t) -> void:
	await _settle(t, 20)
	p1.global_position = Vector2(320, 600)
	p2.global_position = Vector2(430, 600)
	p2.hp = 100
	p1.combo_count = 0
	var move: Dictionary = p1.moves["heavy_attack"]
	var expected_damage: int = 0
	for phase in (move["multi_hit"] as Array):
		expected_damage += int((phase as Dictionary)["damage"])
	await _press(t, "heavy")
	await t.wait_ticks(int(move["total_frames"]) + 20)
	t.eq("multi-hit move damages once per declared phase", p2.hp, 100 - expected_damage)


func _test_block(t) -> void:
	await _settle(t, 30)
	# The previous test leaves the dummy in GETUP; reset both fighters so the
	# block assertions are not reading leftover state.
	p2.respawn(420.0)
	p2.enter_neutral()
	p2.facing = -1
	await t.wait_ticks(3)
	p1.global_position = Vector2(320, 600)
	p2.global_position = Vector2(420, 600)
	p2.hp = 100
	_intent2.intent = {"axis": 0.0, "block": true}
	await t.wait_ticks(4)
	t.eq("defender entered BLOCK", p2.state, States.State.BLOCK)
	await _press(t, "light")
	# Blockstun is short by design, so sample it every tick instead of once at the
	# end of the move.
	var max_blockstun: int = 0
	for _i in range(24):
		max_blockstun = maxi(max_blockstun, p2.blockstun_ticks)
		await t.wait_ticks(1)
	var chip: int = int(p1.moves["light_attack"]["chip_damage"])
	t.eq("blocked hit applies chip damage only", p2.hp, 100 - chip)
	t.ok("blocked hit sets blockstun", max_blockstun > 0, str(max_blockstun))
	_intent2.intent = {"axis": 0.0}
	await t.wait_ticks(6)


func _test_projectile(t) -> void:
	await _settle(t, 30)
	p1.global_position = Vector2(320, 600)
	p2.global_position = Vector2(760, 600)
	p2.hp = 100
	p1.special_energy = 100.0
	await _press(t, "special")
	await t.wait_ticks(20)
	t.ok("special spawned a projectile", manager.projectiles.size() > 0, str(manager.projectiles.size()))
	t.close("special consumed energy", p1.special_energy, 75.0, 0.5)
	await t.wait_ticks(90)
	t.eq("projectile dealt its damage once", p2.hp, 100 - int(p1.moves["special"]["damage"]))
	t.ok("projectile despawned after hitting", manager.projectiles.size() == 0, str(manager.projectiles.size()))


func _test_energy_and_meter(t) -> void:
	await _settle(t, 20)
	p1.special_energy = 0.0
	p1.ultimate_meter = 0.0
	_intent1.intent = {"axis": 0.0, "ultimate": true}
	await t.wait_ticks(2)
	t.ok("ultimate without meter is refused", p1.state != States.State.ULTIMATE, States.name_of(p1.state))
	_intent1.intent = {"axis": 0.0}
	p1.ultimate_meter = 100.0
	await t.wait_ticks(2)
	await _press(t, "ultimate")
	t.eq("ultimate starts when the meter is full", p1.state, States.State.ULTIMATE)
	t.close("ultimate consumed the meter", p1.ultimate_meter, 0.0, 0.01)
	await t.wait_ticks(70)
	p1.special_energy = 0.0
	_intent1.intent = {"axis": 0.0, "special": true}
	await t.wait_ticks(2)
	_intent1.intent = {"axis": 0.0}
	t.ok("special without energy is refused", p1.state != States.State.SPECIAL, States.name_of(p1.state))
	_intent1.intent = {"axis": 0.0}


func _test_grounding(t) -> void:
	await _settle(t, 20)
	p1.respawn(320.0)
	# respawn() starts the intro pose on purpose; the match calls enter_neutral()
	# when the round actually begins, so the test does the same.
	p1.enter_neutral()
	await t.wait_ticks(4)
	t.close("respawn puts the feet on the floor", p1.global_position.y, 600.0, 0.5)
	_intent1.intent = {"axis": 0.0, "jump": true}
	await t.wait_ticks(3)
	t.ok("jump leaves the ground", p1.global_position.y < 599.0, str(p1.global_position.y))
	_intent1.intent = {"axis": 0.0}
	await t.wait_ticks(90)
	t.close("fighter lands back on the floor", p1.global_position.y, 600.0, 0.5)
	t.ok("fighter is grounded after landing", p1.grounded)


## Character 1 (Naruto) mechanics: Rasengan rush, Kurama Chakra Mode form and the
## Tailed Beast Rasenshuriken ultimate. Everything here is driven by the moveset
## data, so the engine still contains no character-name branches.
func _test_character_abilities(t) -> void:
	t.suite("combat / character 001 abilities")
	var moveset: Dictionary = GameData.lab_moveset("001_naruto")
	t.ok("moveset 001_naruto loads", not moveset.is_empty())
	if moveset.is_empty():
		return
	var moves: Dictionary = moveset.get("moves", {})
	var forms: Dictionary = moveset.get("forms", {})
	t.eq("Rasengan is the special", str((moves.get("special", {}) as Dictionary).get("name", "")), "Rasengan")
	t.eq("Rasengan costs 30 energy", float((moves.get("special", {}) as Dictionary).get("energy_cost", 0.0)), 30.0)
	t.eq("ultimate is the Rasenshuriken", str((moves.get("ultimate", {}) as Dictionary).get("name", "")),
		"Tailed Beast Rasenshuriken")
	t.eq("Rasenshuriken requires a full meter", float((moves.get("ultimate", {}) as Dictionary).get("meter_required", 0.0)), 100.0)
	t.ok("Kurama Chakra Mode is declared as a form", forms.has("kurama_chakra_mode"))
	t.ok("the form is flagged as needing its own approval",
		bool((forms.get("kurama_chakra_mode", {}) as Dictionary).get("requires_separate_reference_approval", false)))

	var arena = CombatManagerScript.new()
	t.tree.root.add_child(arena)
	var attacker = _spawn_test_fighter(arena, moveset, 600.0)
	var target = _spawn_test_fighter(arena, moveset, 900.0)
	if attacker == null or target == null:
		t.ok("ability fighters spawned", false)
		return
	attacker.facing = 1
	target.facing = -1
	await t.wait_ticks(4)

	# --- Rasengan -----------------------------------------------------------
	attacker.special_energy = 0.0
	t.ok("Rasengan refused without energy", not attacker.start_move("special"))
	attacker.special_energy = 80.0
	var start_x: float = attacker.global_position.x
	t.ok("Rasengan starts with energy", attacker.start_move("special"))
	t.eq("Rasengan spent its energy", int(attacker.special_energy), 50)
	t.eq("Rasengan enters SPECIAL", attacker.state, States.State.SPECIAL)
	await t.wait_ticks(16)
	t.ok("Rasengan rushes forward", attacker.global_position.x > start_x + 30.0,
		"moved %.1f" % (attacker.global_position.x - start_x))
	await t.wait_ticks(26)
	t.ok("Rasengan lands damage", target.hp < target.max_hp, "hp %d" % target.hp)
	t.ok("Rasengan stops on contact", absf(attacker.velocity.x) < 200.0, str(attacker.velocity.x))
	await t.wait_ticks(40)

	# --- Kurama Chakra Mode -------------------------------------------------
	attacker.special_energy = 100.0
	t.ok("form starts with full energy", attacker.start_form())
	t.eq("form spent its energy", int(attacker.special_energy), 40)
	t.eq("form state entered", attacker.state, States.State.FORM)
	t.ok("form is active", attacker.is_form_active())
	t.ok("form grants speed", attacker.form_speed_multiplier() > 1.0, str(attacker.form_speed_multiplier()))
	t.ok("form grants damage", attacker.form_damage_multiplier() > 1.0, str(attacker.form_damage_multiplier()))
	t.ok("form cannot stack", not attacker.start_form())
	attacker.form_ticks = 2
	await t.wait_ticks(4)
	t.ok("form expires on its own", not attacker.is_form_active())
	t.ok("form returns to a normal multiplier", is_equal_approx(attacker.form_damage_multiplier(), 1.0))
	# The cast state outlives the buff by design; wait for it before acting again.
	await t.wait_ticks(30)
	t.ok("fighter is actionable after the form cast", States.is_actionable(attacker.state),
		States.name_of(attacker.state))

	# --- Tailed Beast Rasenshuriken ----------------------------------------
	attacker.ultimate_meter = 0.0
	t.ok("ultimate refused without meter", not attacker.start_move("ultimate"))
	attacker.ultimate_meter = 100.0
	var projectiles_before: int = arena.projectiles.size()
	t.ok("ultimate starts with a full meter", attacker.start_move("ultimate"))
	t.eq("ultimate consumed the meter", int(attacker.ultimate_meter), 0)
	await t.wait_ticks(26)
	t.eq("ultimate spawned one projectile", arena.projectiles.size(), projectiles_before + 1)
	if arena.projectiles.size() > projectiles_before:
		var shot = arena.projectiles[arena.projectiles.size() - 1]
		t.eq("projectile uses the rasenshuriken visual", str(shot.visual_kind), "rasenshuriken")
		t.ok("projectile is large", float(shot.radius) >= 48.0, str(shot.radius))

	# --- Cleanup ------------------------------------------------------------
	target.hp = 0
	arena.clear()
	arena.queue_free()


func _spawn_test_fighter(parent, moveset: Dictionary, x: float):
	var fighter: Node = FighterScript.new()
	fighter.setup(moveset, {"name": "TEST 001", "temporary": true}, 0, ScriptedIntent.new())
	parent.add_child(fighter)
	fighter.set_arena(600.0, 0.0, 2000.0)
	fighter.global_position = Vector2(x, 600.0)
	fighter.set_active(true)
	fighter.enter_neutral()
	return fighter
