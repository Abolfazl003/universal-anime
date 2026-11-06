extends Node2D
## TEMPORARY dungeon enemy.
##
## Behaviour comes from data (approacher / ranged / defender / boss patterns).
## These are abstract shapes with an explicit TEMP label — they are not anime
## characters and are never presented as such.

signal died(enemy: Node)
signal projectile_requested(origin: Vector2, velocity: Vector2, damage: int, color: Color)

var data: Dictionary = {}
var hp: int = 20
var max_hp: int = 20
var speed: float = 120.0
var radius: float = 18.0
var color: Color = Color("e5484d")
var shape_name: String = "circle"
var behavior: String = "approacher"
var touch_damage: int = 6
var is_boss: bool = false
var alive: bool = true
var room_rect: Rect2 = Rect2()
var display_name: String = "TEMP"

var _tick: int = 0
var _shoot_cooldown: int = 0
var _pattern_index: int = 0
var _pattern_timer: int = 0
var _telegraph: int = 0
var _charge_ticks: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _blocking: bool = false
var _hit_flash: int = 0


func setup(definition: Dictionary, p_room_rect: Rect2) -> void:
	data = definition
	max_hp = int(definition.get("hp", 20))
	hp = max_hp
	speed = float(definition.get("speed", 120.0))
	radius = float(definition.get("radius", 18.0))
	color = Color(str(definition.get("color", "#e5484d")))
	shape_name = str(definition.get("shape", "circle"))
	behavior = str(definition.get("behavior", "approacher"))
	touch_damage = int(definition.get("touch_damage", 6))
	is_boss = bool(definition.get("is_boss", false))
	display_name = str(definition.get("displayName", "TEMP"))
	room_rect = p_room_rect
	_shoot_cooldown = int(definition.get("cooldown_ticks", 90)) / 2


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_tick += 1
	if _hit_flash > 0:
		_hit_flash -= 1
	var player = _find_player()
	if player == null:
		queue_redraw()
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT

	if is_boss:
		_process_boss(delta, player, direction, distance)
	else:
		match behavior:
			"ranged":
				_process_ranged(player, direction, distance)
			"defender":
				_process_defender(direction, distance)
			_:
				_process_approacher(direction, distance)

	# Enemies never leave their room: the room is convex, so clamping is enough.
	var margin: float = radius + 26.0
	global_position.x = clampf(global_position.x, room_rect.position.x + margin, room_rect.end.x - margin)
	global_position.y = clampf(global_position.y, room_rect.position.y + margin, room_rect.end.y - margin)
	queue_redraw()


func _process_approacher(direction: Vector2, distance: float) -> void:
	if distance > radius + 26.0:
		global_position += direction * speed / 60.0


func _process_ranged(player, direction: Vector2, distance: float) -> void:
	var preferred: float = float(data.get("preferred_range", 320.0))
	if distance > preferred + 40.0:
		global_position += direction * speed / 60.0
	elif distance < preferred - 40.0:
		global_position -= direction * speed / 60.0
	_shoot_cooldown -= 1
	if _shoot_cooldown <= 0 and distance < 620.0:
		_shoot_cooldown = int(data.get("cooldown_ticks", 90))
		var projectile_speed: float = float(data.get("projectile_speed", 320.0))
		projectile_requested.emit(global_position, direction * projectile_speed,
			int(data.get("projectile_damage", 7)), color)
	# Keep the player position argument meaningful for future line-of-sight work.
	if player == null:
		return


func _process_defender(direction: Vector2, distance: float) -> void:
	if distance > radius + 30.0:
		global_position += direction * speed / 60.0
	_blocking = _tick % 120 > 70


func _process_boss(_delta: float, player, direction: Vector2, distance: float) -> void:
	var patterns: Array = data.get("patterns", [])
	if patterns.is_empty():
		_process_approacher(direction, distance)
		return

	var pattern: Dictionary = patterns[_pattern_index % patterns.size()]
	_pattern_timer += 1
	var telegraph_ticks: int = int(pattern.get("telegraph_ticks", 45))
	var period: int = int(pattern.get("period_ticks", 240))

	if _charge_ticks > 0:
		_charge_ticks -= 1
		global_position += _charge_dir * float(pattern.get("speed", 600.0)) / 60.0
		if _charge_ticks == 0:
			_pattern_timer = 0
			_pattern_index += 1
		return

	if _telegraph > 0:
		_telegraph -= 1
		if _telegraph == 0:
			_fire_pattern(pattern, direction)
		return

	if _pattern_timer >= period:
		_pattern_timer = 0
		_pattern_index += 1
	elif _pattern_timer == maxi(1, period - telegraph_ticks):
		_telegraph = telegraph_ticks
		_charge_dir = direction

	if distance > 260.0:
		var move_dir: Vector2 = _charge_dir.normalized() if _charge_dir != Vector2.ZERO else direction
		global_position += move_dir * speed / 60.0
	if player == null:
		return


func _fire_pattern(pattern: Dictionary, direction: Vector2) -> void:
	var kind: String = str(pattern.get("kind", "radial_burst"))
	var damage: int = int(pattern.get("damage", 8))
	var projectile_speed: float = float(pattern.get("speed", 240.0))
	match kind:
		"radial_burst":
			var count: int = int(pattern.get("projectiles", 8))
			for index in range(count):
				var angle: float = TAU * float(index) / float(count)
				projectile_requested.emit(global_position, Vector2.RIGHT.rotated(angle) * projectile_speed, damage, color)
		"ring":
			var count: int = int(pattern.get("projectiles", 12))
			for index in range(count):
				var angle: float = TAU * float(index) / float(count) + _tick * 0.01
				projectile_requested.emit(global_position, Vector2.RIGHT.rotated(angle) * projectile_speed, damage, color)
		"charge":
			_charge_ticks = int(pattern.get("duration_ticks", 40))
			_charge_dir = direction
		_:
			pass


func _find_player():
	var players: Array = get_tree().get_nodes_in_group("dungeon_player")
	for player in players:
		if is_instance_valid(player) and bool(player.alive):
			return player
	return null


func take_damage(amount: int, from_position: Vector2) -> bool:
	if not alive:
		return false
	var damage: int = amount
	if behavior == "defender" and _blocking:
		var player = _find_player()
		var to_attacker: Vector2 = (from_position - global_position).normalized()
		var guard_dir: Vector2 = Vector2.ZERO
		if player != null:
			guard_dir = (player.global_position - global_position).normalized()
		if to_attacker.dot(guard_dir) > 0.2:
			damage = int(ceil(float(amount) * 0.3))
	hp -= damage
	_hit_flash = 8
	if hp <= 0:
		alive = false
		died.emit(self)
		queue_free()
	return true


func is_blocking() -> bool:
	return _blocking


func telegraphing() -> bool:
	return _telegraph > 0


func _draw() -> void:
	var base: Color = color if _hit_flash == 0 else Color("ffffff")
	draw_circle(Vector2.ZERO, radius + 5.0, Color(0, 0, 0, 0.28))
	match shape_name:
		"triangle":
			var points := PackedVector2Array([
				Vector2(0, -radius), Vector2(radius, radius * 0.8), Vector2(-radius, radius * 0.8)
			])
			draw_colored_polygon(points, base)
		"square":
			draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), base, true)
		"hexagon":
			var points := PackedVector2Array()
			for index in range(6):
				var angle: float = TAU * float(index) / 6.0
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, base)
		_:
			draw_circle(Vector2.ZERO, radius, base)

	if _blocking:
		draw_arc(Vector2.ZERO, radius + 8.0, -1.2, 1.2, 16, Color("9ae6b4"), 4.0)
	if _telegraph > 0:
		var progress: float = 1.0 - float(_telegraph) / 50.0
		draw_arc(Vector2.ZERO, radius + 12.0 + progress * 40.0, 0.0, TAU, 32,
			Color(1.0, 0.35, 0.3, 0.7), 3.0)

	if hp < max_hp:
		var width: float = radius * 2.0
		draw_rect(Rect2(-width * 0.5, -radius - 14.0, width, 5.0), Color(0, 0, 0, 0.6), true)
		draw_rect(Rect2(-width * 0.5, -radius - 14.0, width * float(hp) / float(max_hp), 5.0), Color("e5484d"), true)

	var font: Font = ThemeDB.fallback_font
	if font != null and is_boss:
		draw_string(font, Vector2(-radius, -radius - 20.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f5a623"))
