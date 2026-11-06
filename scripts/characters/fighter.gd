extends CharacterBody2D
## Fighter — the single 2D fighter controller shared by every mode.
##
## Design rules enforced here:
##  * the character is defined entirely by its moveset data (no name checks),
##  * every timer is expressed in 1/60 s simulation ticks, not rendered frames,
##  * all state changes go through the central state table,
##  * hitboxes and hurtboxes are derived from data, never from the drawn sprite,
##  * one attack instance can damage a target at most once per explicit phase.

const Consts = preload("res://scripts/core/constants.gd")
const States = preload("res://scripts/combat/fighter_states.gd")
const InputBuffer = preload("res://scripts/input/input_buffer.gd")
const FighterVisual = preload("res://scripts/characters/fighter_visual.gd")

signal hp_changed(current: int, maximum: int)
signal energy_changed(special: float, ultimate: float)
signal state_changed(new_state: int, old_state: int)
signal move_started(move_id: String, instance_id: int)
signal projectile_requested(move: Dictionary, instance_id: int)
signal hit_landed(move_id: String, damage: int, blocked: bool)
signal defeated()

const TICK: float = 1.0 / 60.0

## Configuration (filled by setup()).
var fighter_key: String = ""
var display_name: String = ""
var temporary: bool = true
var player_index: int = 0
var moveset: Dictionary = {}
var moves: Dictionary = {}
var config: Dictionary = {}
var intent_source = null
var opponent = null

## Vitals.
var max_hp: int = Consts.DEFAULT_HP
var hp: int = Consts.DEFAULT_HP
var special_energy: float = 0.0
var ultimate_meter: float = 0.0
var special_max: float = Consts.DEFAULT_SPECIAL_MAX
var ultimate_max: float = Consts.DEFAULT_ULTIMATE_MAX

## State.
var state: int = States.State.IDLE
var state_tick: int = 0
var facing: int = 1
var grounded: bool = true
var active: bool = false
var rounds_won: int = 0

var current_move: Dictionary = {}
var current_move_id: String = ""
var attack_instance: int = 0
var attack_hit_confirmed: bool = false
var current_phase: int = 0
var _projectile_fired: bool = false

var hitstun_ticks: int = 0
var blockstun_ticks: int = 0
var invulnerable_ticks: int = 0
var knockdown_pending: bool = false
var combo_count: int = 0
var combo_ticks: int = 0
var cooldowns: Dictionary = {}

## Arena.
var floor_y: float = 820.0
var bounds_left: float = 120.0
var bounds_right: float = 1800.0

## Animation (playback is delta-based, so it is refresh-rate independent).
var anim_clip: String = "idle"
var anim_time: float = 0.0
var anim_fps: float = 12.0
var anim_loop: bool = true
var anim_playing: bool = false
var _one_shot_ticks: int = 0

var visual = null
var buffer: InputBuffer
var _axis_hold_ticks: int = 0
var _last_hp_emitted: int = -1
var _last_intent: Dictionary = {}


func setup(p_moveset: Dictionary, entry: Dictionary, p_player_index: int, p_intent = null) -> void:
	moveset = p_moveset
	moves = p_moveset.get("moves", {})
	config = p_moveset.get("fighter", {})
	fighter_key = str(p_moveset.get("id", p_moveset.get("movesetId", "unknown")))
	display_name = str(entry.get("name", p_moveset.get("display_name", fighter_key)))
	temporary = bool(entry.get("temporary", p_moveset.get("temporary", true)))
	player_index = p_player_index
	intent_source = p_intent
	max_hp = int(config.get("hp", Consts.DEFAULT_HP))
	hp = max_hp
	buffer = InputBuffer.new()


func _ready() -> void:
	if config.is_empty():
		push_warning("Fighter '%s' has no fighter config; using defaults." % fighter_key)
	visual = FighterVisual.new()
	visual.name = "Visual"
	visual.fighter = self
	add_child(visual)
	_set_anim("idle", true)
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(special_energy, ultimate_meter)


func set_arena(p_floor_y: float, p_left: float, p_right: float) -> void:
	floor_y = p_floor_y
	bounds_left = p_left
	bounds_right = p_right


func respawn(x: float) -> void:
	global_position = Vector2(x, floor_y)
	velocity = Vector2.ZERO
	hp = max_hp
	special_energy = 0.0
	ultimate_meter = 0.0
	combo_count = 0
	cooldowns.clear()
	hitstun_ticks = 0
	blockstun_ticks = 0
	invulnerable_ticks = 0
	knockdown_pending = false
	current_move = {}
	current_move_id = ""
	current_phase = 0
	_projectile_fired = false
	grounded = true
	if buffer != null:
		buffer.clear()
	_enter(States.State.INTRO, true)
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(special_energy, ultimate_meter)


func start_round() -> void:
	_enter(States.State.INTRO, true)
	velocity = Vector2.ZERO
	grounded = true
	global_position.y = floor_y


## Forces a neutral state (used when a round actually starts) so the intro
## animation cannot delay the first actionable frame.
func enter_neutral() -> void:
	_enter(States.State.IDLE, true)


func set_active(value: bool) -> void:
	active = value
	if not value:
		velocity = Vector2.ZERO


# --- Simulation ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active:
		return
	_advance_timers()
	_last_intent = _poll_intent()
	_process_state(_last_intent)
	_apply_physics(delta)
	_update_animation(delta)
	if hp != _last_hp_emitted:
		_last_hp_emitted = hp
		if GameDebug != null:
			GameDebug.report_state("%s %s hp=%d" % [display_name, States.name_of(state), hp])


func _poll_intent() -> Dictionary:
	if intent_source == null:
		return {"axis": 0.0}
	return intent_source.poll(self, opponent)


func _advance_timers() -> void:
	if invulnerable_ticks > 0:
		invulnerable_ticks -= 1
	if blockstun_ticks > 0:
		blockstun_ticks -= 1
	if _one_shot_ticks > 0:
		_one_shot_ticks -= 1
	if combo_ticks > 0:
		combo_ticks -= 1
		if combo_ticks == 0:
			combo_count = 0
	for key in cooldowns.keys():
		cooldowns[key] = maxi(0, int(cooldowns[key]) - 1)
	if buffer != null:
		buffer.advance()


func _process_state(intent: Dictionary) -> void:
	state_tick += 1
	match state:
		States.State.INTRO:
			if state_tick >= int(States.DEFAULT_DURATIONS[States.State.INTRO]):
				_enter(States.State.IDLE)
		States.State.IDLE, States.State.WALK, States.State.RUN, States.State.CROUCH:
			_process_grounded_neutral(intent)
		States.State.BLOCK:
			_process_block(intent)
		States.State.JUMP, States.State.FALL:
			_process_air(intent)
		States.State.ATTACK, States.State.SPECIAL, States.State.ULTIMATE:
			_process_move(intent)
		States.State.HITSTUN:
			if hitstun_ticks > 0:
				hitstun_ticks -= 1
			if hitstun_ticks <= 0:
				if knockdown_pending:
					knockdown_pending = false
					_enter(States.State.KNOCKDOWN, true)
				elif not grounded:
					_enter(States.State.FALL)
				else:
					_enter(States.State.IDLE)
		States.State.KNOCKDOWN:
			if state_tick >= int(States.DEFAULT_DURATIONS[States.State.KNOCKDOWN]):
				if hp <= 0:
					_finish_defeat()
				else:
					_enter(States.State.GETUP, true)
					invulnerable_ticks = int(States.DEFAULT_DURATIONS[States.State.GETUP])
		States.State.GETUP:
			if state_tick >= int(States.DEFAULT_DURATIONS[States.State.GETUP]):
				_enter(States.State.IDLE)
		States.State.VICTORY, States.State.OUTRO, States.State.DEFEAT:
			pass


func _process_grounded_neutral(intent: Dictionary) -> void:
	# A buffered attack (pressed a few ticks too early) fires as soon as the
	# fighter becomes actionable again.
	var buffered: String = buffer.latest()
	if not buffered.is_empty() and States.is_actionable(state):
		if start_move(buffered):
			buffer.clear()
			return
	var axis: float = float(intent.get("axis", 0.0))
	if absf(axis) > 0.2:
		_axis_hold_ticks += 1
	else:
		_axis_hold_ticks = 0

	if _try_attack(intent):
		return

	if bool(intent.get("jump", false)) and grounded:
		grounded = false
		velocity.y = float(config.get("jump_velocity", -720.0))
		_enter(States.State.JUMP)
		return

	if bool(intent.get("crouch", false)) and grounded:
		_enter(States.State.CROUCH)
		return

	if bool(intent.get("block", false)) and grounded:
		_enter(States.State.BLOCK)
		return

	if absf(axis) > 0.2:
		if _axis_hold_ticks > 8 and absf(axis) > 0.8:
			_enter(States.State.RUN)
		else:
			_enter(States.State.WALK)
	else:
		_axis_hold_ticks = 0
		_enter(States.State.IDLE)


func _process_block(intent: Dictionary) -> void:
	if blockstun_ticks > 0:
		return
	if not bool(intent.get("block", false)):
		_enter(States.State.IDLE)
		return
	if bool(intent.get("crouch", false)):
		_enter(States.State.CROUCH)
		return
	# Blocking still allows an immediate attack input on the next tick.
	if bool(intent.get("light", false)) or bool(intent.get("heavy", false)):
		_enter(States.State.IDLE)


func _process_air(intent: Dictionary) -> void:
	var axis: float = float(intent.get("axis", 0.0))
	if grounded:
		_enter(States.State.IDLE)
		return
	if velocity.y > 0.0 and state != States.State.FALL:
		_enter(States.State.FALL)


func _process_move(intent: Dictionary) -> void:
	var move: Dictionary = current_move
	if move.is_empty():
		_enter(States.State.IDLE)
		return
	var startup: int = int(move.get("startup", 0))
	var active: int = int(move.get("active", 1))
	var total: int = int(move.get("total_frames", startup + active + int(move.get("recovery", 0))))

	if not _projectile_fired and (move.get("projectile", {}) as Dictionary).size() > 0 and state_tick >= startup:
		_projectile_fired = true
		projectile_requested.emit(move, attack_instance)

	# Cancel windows: only after the active frames, only into listed moves, and
	# only when the window's condition (usually "hit confirmed") is satisfied.
	if state_tick >= startup + active and _try_cancel(intent):
		return

	if state_tick >= total:
		current_move = {}
		current_move_id = ""
		_enter(States.State.IDLE)


func _try_attack(intent: Dictionary) -> bool:
	var order: Array = [
		["ultimate", "ultimate"],
		["special", "special"],
		["heavy", "heavy_attack"],
		["light", "light_attack"],
	]
	for pair in order:
		if bool(intent.get(pair[0], false)):
			if start_move(str(pair[1])):
				return true
			buffer.push(str(pair[1]))
	return false


func _try_cancel(intent: Dictionary) -> bool:
	var windows: Array = current_move.get("cancel_windows", [])
	if windows.is_empty():
		return false
	for window in windows:
		var entry: Dictionary = window
		if state_tick < int(entry.get("from_frame", 0)) or state_tick > int(entry.get("to_frame", 0)):
			continue
		if bool(entry.get("requires_hit", false)) and not attack_hit_confirmed:
			continue
		var into: Array = entry.get("into", [])
		for move_id in into:
			var key: String = str(move_id)
			var pressed: bool = false
			match key:
				"light_attack":
					pressed = bool(intent.get("light", false))
				"heavy_attack":
					pressed = bool(intent.get("heavy", false))
				"special":
					pressed = bool(intent.get("special", false))
				"ultimate":
					pressed = bool(intent.get("ultimate", false))
			if not pressed:
				continue
			if start_move(key):
				return true
	return false


func start_move(move_id: String) -> bool:
	if not moves.has(move_id):
		return false
	if not States.is_actionable(state):
		return false
	var move: Dictionary = moves[move_id]
	if int(cooldowns.get(move_id, 0)) > 0:
		return false
	if float(move.get("energy_cost", 0.0)) > special_energy:
		return false
	if float(move.get("meter_required", 0.0)) > ultimate_meter:
		return false
	if not grounded and not bool(move.get("air_ok", false)):
		return false

	special_energy = maxf(0.0, special_energy - float(move.get("energy_cost", 0.0)))
	if float(move.get("meter_required", 0.0)) > 0.0:
		ultimate_meter = maxf(0.0, ultimate_meter - float(move.get("meter_required", 0.0)))
	var cooldown: int = int(move.get("cooldown", 0))
	if cooldown > 0:
		cooldowns[move_id] = cooldown

	energy_changed.emit(special_energy, ultimate_meter)

	current_move = move
	current_move_id = move_id
	attack_instance += 1
	attack_hit_confirmed = false
	current_phase = 0
	_projectile_fired = false
	invulnerable_ticks = maxi(invulnerable_ticks, int(move.get("invulnerable_frames", 0)))

	var next_state: int = States.State.ATTACK
	if move_id == "special":
		next_state = States.State.SPECIAL
	elif move_id == "ultimate":
		next_state = States.State.ULTIMATE
	_enter(next_state, true)
	if float(move.get("move_speed", 0.0)) > 0.0:
		velocity.x = float(move.get("move_speed")) * facing
	else:
		velocity.x = 0.0
	_set_anim(str(move.get("animation_id", move_id)), true)
	move_started.emit(move_id, attack_instance)
	return true


## Hitbox for the current tick, or {} when no hitbox is active.
## `instance` identifies the attack *phase*, so a multi-hit move can hit once per
## declared phase and never repeatedly on the same tick.
func active_hit() -> Dictionary:
	if current_move.is_empty():
		return {}
	if state != States.State.ATTACK and state != States.State.SPECIAL and state != States.State.ULTIMATE:
		return {}
	var move: Dictionary = current_move
	var startup: int = int(move.get("startup", 0))
	var active: int = int(move.get("active", 1))
	if state_tick < startup:
		return {}

	var damage: int = int(move.get("damage", 0))
	var phase_index: int = 0
	var phases: Array = move.get("multi_hit", [])
	if phases.is_empty():
		if state_tick >= startup + active:
			return {}
	else:
		var found: bool = false
		for index in range(phases.size()):
			var phase: Dictionary = phases[index]
			var start: int = int(phase.get("start", 0))
			var length: int = int(phase.get("length", 1))
			if state_tick >= start and state_tick < start + length:
				damage = int(phase.get("damage", damage))
				phase_index = index
				found = true
				break
		if not found:
			return {}

	var size := Vector2(float(move.get("hitbox_size_x", 0.0)), float(move.get("hitbox_size_y", 0.0)))
	var offset := Vector2(float(move.get("hitbox_offset_x", 0.0)) * facing, float(move.get("hitbox_offset_y", 0.0)))
	var center := global_position + offset
	var rect := Rect2(center - size * 0.5, size)
	return {
		"instance": attack_instance * 100 + phase_index,
		"attack_instance": attack_instance,
		"phase": phase_index,
		"rect": rect,
		"damage": damage,
		"move": move,
		"move_id": current_move_id,
	}


func hurtbox() -> Rect2:
	var width: float = float(config.get("hurtbox_width", 48.0))
	var height: float = float(config.get("hurtbox_height", 122.0))
	if state == States.State.CROUCH:
		height *= 0.72
	elif state == States.State.KNOCKDOWN:
		height *= 0.48
	elif state == States.State.BLOCK:
		height *= 0.92
	return Rect2(global_position + Vector2(-width * 0.5, -height), Vector2(width, height))


func is_vulnerable() -> bool:
	if invulnerable_ticks > 0:
		return false
	if state == States.State.KNOCKDOWN or state == States.State.GETUP:
		return false
	if state == States.State.ULTIMATE:
		return false
	return States.is_vulnerable(state)


func is_blocking_toward(attacker_pos: Vector2) -> bool:
	if state != States.State.BLOCK or not grounded:
		return false
	var direction: float = signf(attacker_pos.x - global_position.x)
	if is_zero_approx(direction):
		return true
	return int(direction) == facing


func receive_hit(hit: Dictionary, attacker) -> Dictionary:
	var move: Dictionary = hit.get("move", {})
	var result: Dictionary = {
		"applied": false,
		"blocked": false,
		"damage": 0,
		"knockdown": false,
		"defeated": false,
	}
	if not is_vulnerable():
		result["reason"] = "invulnerable"
		return result

	var attacker_pos: Vector2 = attacker.global_position if attacker != null else global_position + Vector2(-facing, 0)
	var blocked: bool = is_blocking_toward(attacker_pos)
	var base_damage: int = int(hit.get("damage", int(move.get("damage", 0))))
	var damage: int = maxi(0, int(move.get("chip_damage", 0))) if blocked else base_damage

	hp = maxi(0, hp - damage)
	result["applied"] = true
	result["blocked"] = blocked
	result["damage"] = damage

	var weight: float = maxf(0.2, float(config.get("weight", 1.0)))
	var knockback := Vector2(
		float(move.get("knockback_x", 0.0)) / weight,
		float(move.get("knockback_y", 0.0)) / weight
	)

	if blocked:
		blockstun_ticks = maxi(blockstun_ticks, int(move.get("blockstun", 0)))
		velocity.x = (knockback.x * 0.35) * signf(global_position.x - attacker_pos.x)
		_set_anim("block_hit", true)
	else:
		hitstun_ticks = maxi(1, int(move.get("hitstun", 0)))
		velocity = Vector2(knockback.x * signf(global_position.x - attacker_pos.x), knockback.y)
		grounded = knockback.y >= 0.0 and grounded
		if knockback.y < -20.0:
			grounded = false
		if hp <= 0 or absf(knockback.y) >= 120.0:
			knockdown_pending = true
		_enter(States.State.HITSTUN, true)
		_set_anim("hit_reaction", true)
		special_energy = minf(special_max, special_energy + 2.0)

	if hp <= 0:
		knockdown_pending = true
		result["knockdown"] = true
		result["defeated"] = true
	hit_landed.emit(current_move_id, damage, blocked)
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(special_energy, ultimate_meter)
	return result


func gain_on_hit(move: Dictionary) -> void:
	special_energy = minf(special_max, special_energy + float(move.get("energy_gain", 0.0)))
	ultimate_meter = minf(ultimate_max, ultimate_meter + float(move.get("ultimate_gain", 0.0)))
	energy_changed.emit(special_energy, ultimate_meter)


func notify_hit_confirmed() -> void:
	attack_hit_confirmed = true


func register_combo() -> void:
	combo_count += 1
	combo_ticks = 90


func _finish_defeat() -> void:
	if state == States.State.DEFEAT:
		return
	_enter(States.State.DEFEAT, true)
	_set_anim("defeat", true)
	defeated.emit()


func celebrate() -> void:
	if hp <= 0:
		return
	_enter(States.State.VICTORY, true)
	_set_anim("victory", true)


func _enter(next_state: int, force: bool = false) -> void:
	if next_state == state and not force:
		return
	var previous: int = state
	if not force and not States.transition_allowed(previous, next_state):
		# Transitions that are not listed in the table are refused instead of
		# silently corrupting the fighter.
		push_warning("Illegal fighter transition %s -> %s" % [States.name_of(previous), States.name_of(next_state)])
		return
	state = next_state
	state_tick = 0
	_axis_hold_ticks = 0
	if next_state != States.State.ATTACK and next_state != States.State.SPECIAL and next_state != States.State.ULTIMATE:
		current_phase = 0
	state_changed.emit(next_state, previous)
	if _one_shot_ticks <= 0:
		_set_anim(States.animation_for(next_state), true)


func _apply_physics(delta: float) -> void:
	var axis: float = float(_last_intent.get("axis", 0.0))
	if _movement_allowed():
		var speed: float = float(config.get("walk_speed", 260.0))
		if state == States.State.RUN:
			speed = float(config.get("run_speed", 430.0))
		velocity.x = axis * speed
	elif state == States.State.HITSTUN:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	elif state == States.State.KNOCKDOWN or state == States.State.GETUP:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)

	if not grounded:
		velocity.y += float(ProjectSettings.get_setting("physics/2d/default_gravity", 1800.0)) * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if global_position.x < bounds_left:
		global_position.x = bounds_left
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > bounds_right:
		global_position.x = bounds_right
		velocity.x = minf(velocity.x, 0.0)

	if global_position.y >= floor_y:
		global_position.y = floor_y
		if not grounded:
			grounded = true
			velocity.y = 0.0
			if state == States.State.FALL or state == States.State.JUMP:
				_play_one_shot("landing", 4)
				_enter(States.State.IDLE)
	elif state != States.State.KNOCKDOWN:
		grounded = false

	var neutral: bool = (state == States.State.IDLE or state == States.State.WALK
		or state == States.State.RUN or state == States.State.CROUCH)
	if grounded and neutral:
		_auto_face()


func _movement_allowed() -> bool:
	return States.can_move(state) and grounded


func _auto_face() -> void:
	if opponent == null:
		return
	var direction: float = signf(opponent.global_position.x - global_position.x)
	if not is_zero_approx(direction) and int(direction) != facing:
		facing = int(direction)


# --- Animation -------------------------------------------------------------

func _set_anim(clip: String, restart: bool = false) -> void:
	if clip == anim_clip and not restart:
		return
	anim_clip = clip
	anim_time = 0.0
	var clip_data: Dictionary = {}
	if GameData != null and GameData.animations != null:
		var key: String = fighter_key
		var character_id: String = str(moveset.get("character_id", ""))
		if not character_id.is_empty():
			key = character_id
		clip_data = GameData.animations.get_clip(key, clip)
		if clip_data.is_empty():
			clip_data = GameData.animations.get_clip(str(moveset.get("animationKey", "")), clip)
	anim_fps = float(clip_data.get("fps", 12.0))
	anim_loop = bool(clip_data.get("loop", false))
	anim_playing = true


func _play_one_shot(clip: String, ticks: int) -> void:
	_set_anim(clip, true)
	_one_shot_ticks = ticks


func _update_animation(delta: float) -> void:
	if not anim_playing:
		return
	anim_time += delta
	if _one_shot_ticks == 0 and not anim_loop:
		# One-shot clips hold their last pose instead of looping.
		var duration: float = _anim_duration()
		if duration > 0.0 and anim_time > duration:
			anim_time = duration
	if visual != null:
		visual.queue_redraw()


func _anim_duration() -> float:
	if anim_fps <= 0.0:
		return 0.0
	var frames: float = 4.0
	if GameData != null and GameData.animations != null:
		var key: String = fighter_key
		var character_id: String = str(moveset.get("character_id", ""))
		if not character_id.is_empty():
			key = character_id
		var clip_data: Dictionary = GameData.animations.get_clip(key, anim_clip)
		if clip_data.is_empty():
			clip_data = GameData.animations.get_clip(str(moveset.get("animationKey", "")), anim_clip)
		if not clip_data.is_empty():
			frames = float(clip_data.get("frames", 4))
	return frames / anim_fps if anim_fps > 0.0 else 0.0


func animation_frame() -> int:
	if anim_fps <= 0.0:
		return 0
	return int(floor(anim_time * anim_fps))


func animation_progress() -> float:
	var duration: float = _anim_duration()
	if duration <= 0.0:
		return 0.0
	if anim_loop:
		return fmod(anim_time, duration) / duration
	return clampf(anim_time / duration, 0.0, 1.0)


# --- Helpers ---------------------------------------------------------------

func is_alive() -> bool:
	return hp > 0


func state_name() -> String:
	return States.name_of(state)


func fighter_color() -> Color:
	return Color(str(config.get("primary", "#4f8cff")))


func reset_hp() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	hp_changed.emit(hp, max_hp)
