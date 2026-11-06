extends Node2D
## Rectangle/circle projectile used by dungeon enemies and the player special.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 5
var radius: float = 8.0
var color: Color = Color("8b5cf6")
var lifetime_ticks: int = 240
var from_player: bool = false
var alive: bool = true


func setup(p_position: Vector2, p_velocity: Vector2, p_damage: int, p_radius: float, p_color: Color, p_from_player: bool) -> void:
	global_position = p_position
	velocity = p_velocity
	damage = p_damage
	radius = p_radius
	color = p_color
	from_player = p_from_player


func _physics_process(delta: float) -> void:
	if not alive:
		return
	lifetime_ticks -= 1
	global_position += velocity * delta
	if lifetime_ticks <= 0:
		alive = false
		queue_free()
	queue_redraw()


func rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.75))
