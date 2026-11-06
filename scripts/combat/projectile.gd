extends Node2D
## Simple, data-driven projectile (used by the placeholder special / ultimate).
## Collision is resolved by CombatManager against data hitboxes, not by the
## PhysicsServer, so damage stays deterministic and testable headless.

var owner_fighter = null
var direction: int = 1
var speed: float = 700.0
var max_range: float = 700.0
var radius: float = 24.0
var move: Dictionary = {}
var instance_id: int = 0
var visual_kind: String = "orb"
var traveled: float = 0.0
var alive: bool = true

var _previous_position: Vector2 = Vector2.ZERO


func setup(p_owner, p_move: Dictionary, p_direction: int, p_instance: int) -> void:
	owner_fighter = p_owner
	move = p_move
	direction = p_direction
	instance_id = p_instance
	var projectile: Dictionary = move.get("projectile", {})
	speed = float(projectile.get("speed", 700.0))
	max_range = float(projectile.get("range", 700.0))
	radius = float(projectile.get("radius", 24.0))
	visual_kind = str(projectile.get("visual", "orb"))
	global_position = p_owner.global_position + Vector2(
		float(projectile.get("spawn_offset_x", 60.0)) * p_direction,
		float(projectile.get("spawn_offset_y", -70.0))
	)
	_previous_position = global_position


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var step: float = speed * delta
	global_position.x += step * direction
	traveled += step
	if traveled >= max_range:
		despawn()
		return
	queue_redraw()


func rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func despawn() -> void:
	alive = false
	queue_free()


func _draw() -> void:
	var big: bool = visual_kind == "big_orb"
	var core := Color("cfe0ff") if not big else Color("ffdca8")
	var glow := Color("4f8cff") if not big else Color("f5a623")
	draw_circle(Vector2.ZERO, radius, Color(glow.r, glow.g, glow.b, 0.28))
	draw_circle(Vector2.ZERO, radius * 0.72, glow)
	draw_circle(Vector2.ZERO, radius * 0.42, core)
	if big:
		draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 32, Color(core.r, core.g, core.b, 0.45), 2.0)
