extends CharacterBody2D
## TEMPORARY dungeon avatar.
##
## The dungeon uses its own top-down controller (as required: the movement
## controller and camera are per-mode), but it consumes the same input map and the
## same damage numbers as the versus mode. No anime character is represented here
## because no character has an approved top-down sheet yet.

signal attack_swung(rect: Rect2, damage: int)
signal special_fired(origin: Vector2, direction: Vector2)
signal hp_changed(current: int, maximum: int)
signal died()

const SPEED: float = 330.0
const ATTACK_COOLDOWN_TICKS: int = 26
const ATTACK_DURATION_TICKS: int = 10
const IFRAMES_TICKS: int = 36

var max_hp: int = 100
var hp: int = 100
var energy: float = 0.0
var energy_max: float = 100.0
var radius: float = 16.0
var facing: Vector2 = Vector2.RIGHT
var blocking: bool = false
var attacking_ticks: int = 0
var invulnerable_ticks: int = 0
var attack_cooldown: int = 0
var alive: bool = true

var _tick: int = 0


func _ready() -> void:
	add_to_group("dungeon_player")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	collision_layer = 1
	collision_mask = 1
	hp_changed.emit(hp, max_hp)


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	_tick += 1
	if invulnerable_ticks > 0:
		invulnerable_ticks -= 1
	if attack_cooldown > 0:
		attack_cooldown -= 1
	if attacking_ticks > 0:
		attacking_ticks -= 1

	var direction := Vector2(
		InputService.move_axis(0),
		Input.get_axis(InputService.action_name(0, "move_up"), InputService.action_name(0, "move_down"))
	)
	if direction.length() > 1.0:
		direction = direction.normalized()
	if direction.length() > 0.1:
		facing = direction.normalized()

	blocking = InputService.is_pressed(0, "block") and attacking_ticks == 0 and attack_cooldown == 0
	var speed: float = SPEED * (0.55 if blocking else 1.0)
	velocity = Vector2.ZERO if attacking_ticks > 0 else direction * speed
	move_and_slide()

	if InputService.pressed_this_tick(0, "light") or InputService.pressed_this_tick(0, "heavy"):
		_try_attack()
	if InputService.pressed_this_tick(0, "special") and energy >= 25.0:
		energy -= 25.0
		special_fired.emit(global_position, facing)
	queue_redraw()


func _try_attack() -> void:
	if attack_cooldown > 0 or not alive:
		return
	attack_cooldown = ATTACK_COOLDOWN_TICKS
	attacking_ticks = ATTACK_DURATION_TICKS
	var reach: float = 64.0
	var center: Vector2 = global_position + facing * (reach * 0.5 + radius)
	var rect := Rect2(center - Vector2(reach, 34) * 0.5, Vector2(reach, 68))
	attack_swung.emit(rect, 9)


func take_damage(amount: int, from: Vector2) -> bool:
	if not alive or invulnerable_ticks > 0:
		return false
	var damage: int = amount
	if blocking:
		damage = int(ceil(float(amount) * 0.3))
	hp = maxi(0, hp - damage)
	invulnerable_ticks = IFRAMES_TICKS
	var push: Vector2 = (global_position - from)
	if push.length() > 0.001:
		global_position += push.normalized() * 14.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		alive = false
		velocity = Vector2.ZERO
		died.emit()
	return true


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func gain_energy(amount: float) -> void:
	energy = minf(energy_max, energy + amount)


func _draw() -> void:
	# Placeholder body: ring + facing wedge, deliberately abstract.
	var body_color := Color("4f8cff")
	draw_circle(Vector2.ZERO, radius + 4.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, Color(0.75, 0.85, 1.0, 0.5), 2.0)
	if blocking:
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 32, Color("f5a623"), 5.0)
	if attacking_ticks > 0:
		var tip: Vector2 = facing * (radius + 46.0)
		draw_line(facing * radius, tip, Color("e8eaf2"), 5.0)
		draw_circle(tip, 7.0, Color("f5a623"))
	var eye: Vector2 = facing * (radius * 0.45)
	draw_circle(eye, 4.0, Color("0b0d14"))
	if invulnerable_ticks > 0:
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 28, Color(1, 1, 1, 0.35), 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-22, -radius - 14.0), "TEMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f5a623"))
