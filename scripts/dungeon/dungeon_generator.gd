extends RefCounted
## Seeded dungeon layout generator.
##
## Rooms are grid cells laid out edge to edge, so a door on a shared wall leads
## directly into the neighbouring room and there is never an empty corridor that
## the player can fall out of. The layout is a random walk, which is connected by
## construction — and the connectivity is still verified, because "by
## construction" is not a test.

const ROOM_W: float = 720.0
const ROOM_H: float = 540.0
const GRID_W: int = 4
const GRID_H: int = 3
const WALL_THICKNESS: float = 24.0
const DOOR_WIDTH: float = 140.0

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var seed_value: int = 0
var rooms: Array[Dictionary] = []
var start_id: int = -1
var boss_id: int = -1
var errors: Array[String] = []
var warnings: Array[String] = []

var _rng := RandomNumberGenerator.new()


func generate(p_seed: int, room_count: int = 7) -> Dictionary:
	seed_value = p_seed
	_rng.seed = p_seed
	rooms.clear()
	errors.clear()
	warnings.clear()

	var used: Dictionary = {}
	var cells: Array[Vector2i] = [Vector2i(0, 1)]
	used[Vector2i(0, 1)] = true
	var guard: int = 0
	while cells.size() < clampi(room_count, 3, GRID_W * GRID_H) and guard < 400:
		guard += 1
		var current: Vector2i = cells[-1]
		var options: Array[Vector2i] = []
		for offset in NEIGHBOR_OFFSETS:
			var candidate: Vector2i = current + offset
			if candidate.x < 0 or candidate.y < 0 or candidate.x >= GRID_W or candidate.y >= GRID_H:
				continue
			if used.has(candidate):
				continue
			if cells.size() > 1 and _would_touch_only_dead_end(candidate, used):
				continue
			options.append(candidate)
		if options.is_empty():
			break
		var chosen: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
		cells.append(chosen)
		used[chosen] = true

	var types: Array[String] = _assign_types(cells.size())
	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		rooms.append({
			"id": index,
			"cell": cell,
			"rect": Rect2(cell.x * ROOM_W, cell.y * ROOM_H, ROOM_W, ROOM_H),
			"type": types[index],
			"neighbors": [],
			"cleared": types[index] == "start" or types[index] == "loot" or types[index] == "rest",
			"spawned": false,
		})
	start_id = 0
	boss_id = cells.size() - 1

	_link_neighbors()
	var connectivity: Dictionary = validate_connectivity()
	if not bool(connectivity.get("ok", false)):
		errors.append("Generated layout failed connectivity check: %s" % str(connectivity.get("error", "")))
	return {
		"seed": seed_value,
		"rooms": rooms,
		"start_id": start_id,
		"boss_id": boss_id,
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"connectivity": connectivity,
		"room_size": Vector2(ROOM_W, ROOM_H),
		"ok": errors.is_empty(),
	}


func _would_touch_only_dead_end(candidate: Vector2i, used: Dictionary) -> bool:
	# Keep the walk from creating a room that only touches the end of the chain
	# through a corner (looks broken in-game and adds nothing).
	var touching: int = 0
	for offset in NEIGHBOR_OFFSETS:
		if used.has(candidate + offset):
			touching += 1
	return touching > 1


func _assign_types(count: int) -> Array[String]:
	var types: Array[String] = []
	var middle_cycle: Array[String] = ["combat", "trap", "combat", "loot", "rest"]
	for index in range(count):
		if index == 0:
			types.append("start")
		elif index == count - 1:
			types.append("boss")
		else:
			types.append(middle_cycle[(index - 1) % middle_cycle.size()])
	return types


func _link_neighbors() -> void:
	for room in rooms:
		var cell: Vector2i = room["cell"]
		var neighbors: Array = []
		for other in rooms:
			if other["id"] == room["id"]:
				continue
			var delta: Vector2i = (other["cell"] as Vector2i) - cell
			if absi(delta.x) + absi(delta.y) == 1:
				neighbors.append(other["id"])
		room["neighbors"] = neighbors


func validate_connectivity() -> Dictionary:
	if rooms.is_empty():
		return {"ok": false, "error": "no rooms"}
	var visited: Dictionary = {}
	var queue: Array[int] = [start_id]
	visited[start_id] = true
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in (rooms[current]["neighbors"] as Array):
			if not visited.has(int(neighbor)):
				visited[int(neighbor)] = true
				queue.append(int(neighbor))
	if not visited.has(boss_id):
		return {"ok": false, "error": "boss room unreachable", "reachable": visited.size()}
	if visited.size() != rooms.size():
		return {"ok": false, "error": "unreachable rooms", "reachable": visited.size(), "total": rooms.size()}
	return {"ok": true, "reachable": visited.size()}


func room_at(world_position: Vector2) -> int:
	for room in rooms:
		if (room["rect"] as Rect2).has_point(world_position):
			return int(room["id"])
	return -1


func room(id: int) -> Dictionary:
	for entry in rooms:
		if int(entry["id"]) == id:
			return entry
	return {}


func world_bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for room in rooms:
		var rect: Rect2 = room["rect"]
		min_point = min_point.min(rect.position)
		max_point = max_point.max(rect.position + rect.size)
	return Rect2(min_point, max_point - min_point)
