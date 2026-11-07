extends RefCounted
## Human input provider for a fighter slot.
## Reads the InputMap actions registered by InputMapService and converts them to
## the same intent dictionary the AI produces, so both go through identical
## buffering and state rules.

var player_index: int = 0


func _init(index: int = 0) -> void:
	player_index = index


func poll(_fighter, _opponent) -> Dictionary:
	if InputService == null:
		return {"axis": 0.0}
	return {
		"axis": InputService.move_axis(player_index),
		"jump": InputService.pressed_this_tick(player_index, "jump"),
		"crouch": InputService.is_pressed(player_index, "crouch"),
		"block": InputService.is_pressed(player_index, "block"),
		"light": InputService.pressed_this_tick(player_index, "light"),
		"heavy": InputService.pressed_this_tick(player_index, "heavy"),
		"special": InputService.pressed_this_tick(player_index, "special"),
		"ultimate": InputService.pressed_this_tick(player_index, "ultimate"),
		"form": InputService.pressed_this_tick(player_index, "form"),
	}
