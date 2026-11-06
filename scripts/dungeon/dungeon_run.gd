extends Node2D
## Dungeon run controller: seeded layout, rooms, doors, traps, loot, boss, result.
##
## Rules implemented here:
##  * doors are locked while a room fight is active and open when it is cleared,
##  * every spawned enemy comes from data and is labelled TEMP,
##  * traps telegraph before they fire,
##  * the boss cycles readable patterns with recovery gaps,
##  * the run reports the seed it used so a layout can be reproduced.

const Consts = preload("res://scripts/core/constants.gd")
const Generator = preload("res://scripts/dungeon/dungeon_generator.gd")
const AvatarScript = preload("res://scripts/dungeon/avatar.gd")
const EnemyScript = preload("res://scripts/dungeon/dungeon_enemy.gd")
const ProjectileScript = preload("res://scripts/dungeon/dungeon_projectile.gd")
const DungeonThemes = preload("res://scripts/dungeon/dungeon_themes.gd")
const DungeonHUD = preload("res://scripts/ui/dungeon_hud.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

const ENEMY_DATA_PATH: String = "res://data/dungeon/enemies_lab.json"
const WALL_THICKNESS: float = 24.0
const DOOR_WIDTH: float = 150.0
const ROOM_NAME_KEYS: Dictionary = {
	"start": "dungeon.room_start",
	"combat": "dungeon.room_combat",
	"trap": "dungeon.room_trap",
	"loot": "dungeon.room_loot",
	"rest": "dungeon.room_rest",
	"boss": "dungeon.room_boss",
}

var layout: Dictionary = {}
var generator
var seed_value: int = 0
## Chosen from the run seed (or the selected character's world) so a run has one
## consistent look and stays reproducible.
var theme: Dictionary = {}

var world
var camera
var player
var hud

var enemies: Array = []
var projectiles: Array = []
var chests: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var rest_pads: Array[Dictionary] = []
var door_bodies: Dictionary = {}

var enemy_defs: Dictionary = {}
var room_defs: Dictionary = {}
var loot_tables: Dictionary = {}

var current_room: int = -1
var cleared_rooms: Dictionary = {}
var spawned_rooms: Dictionary = {}
var loot_count: int = 0
var finished: bool = false
var boss_active: bool = false

var _tick: int = 0
var _status_message: String = ""
var _status_ticks: int = 0


func _ready() -> void:
	process_priority = -5
	seed_value = int(SceneRouter.payload().get("seed", Session.dungeon_seed))
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) % 100000
	Session.dungeon_seed = seed_value
	theme = DungeonThemes.pick(seed_value, _theme_hint())
	_load_data()
	generator = Generator.new()
	layout = generator.generate(seed_value, 7)
	if not bool(layout.get("ok", false)):
		push_warning("Dungeon layout failed validation: %s" % str(layout.get("errors", [])))
	_build_world()
	_build_player()
	_build_hud()
	_enter_room(int(layout.get("start_id", 0)), true)
	queue_redraw()


func _load_data() -> void:
	enemy_defs.clear()
	room_defs.clear()
	loot_tables.clear()
	if not FileAccess.file_exists(ENEMY_DATA_PATH):
		push_warning("Dungeon enemy data missing: %s" % ENEMY_DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(ENEMY_DATA_PATH)) != OK:
		push_warning("Dungeon enemy data is not valid JSON.")
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		return
	var root: Dictionary = json.data as Dictionary
	if typeof(root.get("enemies")) == TYPE_DICTIONARY:
		enemy_defs = root["enemies"]
	if typeof(root.get("rooms")) == TYPE_DICTIONARY:
		room_defs = root["rooms"]
	if typeof(root.get("loot")) == TYPE_DICTIONARY:
		loot_tables = root["loot"]


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	for room in layout.get("rooms", []):
		var room_id: int = int(room["id"])
		door_bodies[room_id] = []
		_build_room_walls(room)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	world.add_child(camera)
	camera.make_current()


func _build_room_walls(room: Dictionary) -> void:
	var rect: Rect2 = room["rect"]
	var neighbors: Array = room["neighbors"]
	var center: Vector2 = rect.position + rect.size * 0.5

	var sides: Array[Dictionary] = [
		_side_rects(rect, center, Vector2i(0, -1)),
		_side_rects(rect, center, Vector2i(0, 1)),
		_side_rects(rect, center, Vector2i(-1, 0)),
		_side_rects(rect, center, Vector2i(1, 0)),
	]

	var cell: Vector2i = room["cell"]
	for side in sides:
		var dir: Vector2i = side["dir"]
		var neighbor_cell: Vector2i = cell + dir
		var has_neighbor: bool = false
		for other in layout.get("rooms", []):
			if (other["cell"] as Vector2i) == neighbor_cell:
				has_neighbor = true
				break
		if not has_neighbor:
			_add_wall_body(side["full"])
			continue
		_add_wall_body(side["gap_a"])
		_add_wall_body(side["gap_b"])
		var door: StaticBody2D = _add_wall_body(side["door"])
		var entry: Dictionary = {"body": door, "rect": side["door"]}
		(door_bodies[int(room["id"])] as Array).append(entry)
		# Doors start closed for rooms that still need clearing.
		var is_cleared: bool = bool(room["cleared"])
		_set_door_open(entry, is_cleared)


## Builds the wall segments for one side of a room: a solid wall, or two
## segments with a door-sized gap in the middle when the side is shared.
func _side_rects(rect: Rect2, center: Vector2, dir: Vector2i) -> Dictionary:
	var thickness: float = WALL_THICKNESS
	var half_gap: float = DOOR_WIDTH * 0.5
	match dir:
		Vector2i(0, -1):
			return {
				"dir": dir,
				"full": Rect2(rect.position.x, rect.position.y, rect.size.x, thickness),
				"gap_a": Rect2(rect.position.x, rect.position.y, center.x - rect.position.x - half_gap, thickness),
				"gap_b": Rect2(center.x + half_gap, rect.position.y, rect.end.x - center.x - half_gap, thickness),
				"door": Rect2(center.x - half_gap, rect.position.y, DOOR_WIDTH, thickness),
			}
		Vector2i(0, 1):
			return {
				"dir": dir,
				"full": Rect2(rect.position.x, rect.end.y - thickness, rect.size.x, thickness),
				"gap_a": Rect2(rect.position.x, rect.end.y - thickness, center.x - rect.position.x - half_gap, thickness),
				"gap_b": Rect2(center.x + half_gap, rect.end.y - thickness, rect.end.x - center.x - half_gap, thickness),
				"door": Rect2(center.x - half_gap, rect.end.y - thickness, DOOR_WIDTH, thickness),
			}
		Vector2i(-1, 0):
			return {
				"dir": dir,
				"full": Rect2(rect.position.x, rect.position.y, thickness, rect.size.y),
				"gap_a": Rect2(rect.position.x, rect.position.y, thickness, center.y - rect.position.y - half_gap),
				"gap_b": Rect2(rect.position.x, center.y + half_gap, thickness, rect.end.y - center.y - half_gap),
				"door": Rect2(rect.position.x, center.y - half_gap, thickness, DOOR_WIDTH),
			}
		_:
			return {
				"dir": dir,
				"full": Rect2(rect.end.x - thickness, rect.position.y, thickness, rect.size.y),
				"gap_a": Rect2(rect.end.x - thickness, rect.position.y, thickness, center.y - rect.position.y - half_gap),
				"gap_b": Rect2(rect.end.x - thickness, center.y + half_gap, thickness, rect.end.y - center.y - half_gap),
				"door": Rect2(rect.end.x - thickness, center.y - half_gap, DOOR_WIDTH, thickness),
			}


func _add_wall_body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body


func _set_door_open(entry: Dictionary, open: bool) -> void:
	var body: StaticBody2D = entry["body"]
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		if child is CollisionShape2D:
			# Deferred: doors are toggled from inside physics processing.
			(child as CollisionShape2D).set_deferred("disabled", open)
	entry["open"] = open


func _build_player() -> void:
	player = AvatarScript.new()
	player.name = "Avatar"
	world.add_child(player)
	player.attack_swung.connect(_on_player_attack)
	player.special_fired.connect(_on_player_special)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	var start_room: Dictionary = generator.room(int(layout.get("start_id", 0)))
	var rect: Rect2 = start_room["rect"]
	player.global_position = rect.position + rect.size * 0.5
	camera.global_position = player.global_position


func _build_hud() -> void:
	hud = DungeonHUD.new()
	add_child(hud)
	hud.build(seed_value, (layout.get("rooms", []) as Array).size())
	hud.set_hp(player.hp, player.max_hp)
	hud.set_loot(loot_count)


func _physics_process(_delta: float) -> void:
	if finished:
		return
	_tick += 1
	if _status_ticks > 0:
		_status_ticks -= 1
		if _status_ticks == 0:
			hud.flash_message("")
	if camera != null and player != null:
		camera.global_position = player.global_position
	_update_current_room()
	_update_enemies()
	_update_projectiles()
	_update_traps()
	_update_pickups()
	hud.set_energy(player.energy)
	hud.set_hp(player.hp, player.max_hp)
	_sync_doors()
	if _tick % 8 == 0:
		queue_redraw()


func _update_current_room() -> void:
	var room_id: int = generator.room_at(player.global_position)
	if room_id < 0 or room_id == current_room:
		return
	_enter_room(room_id, false)


func _enter_room(room_id: int, first: bool) -> void:
	current_room = room_id
	var room: Dictionary = generator.room(room_id)
	if room.is_empty():
		return
	var room_type: String = str(room["type"])
	hud.set_area(room_id + 1, (layout.get("rooms", []) as Array).size(), _room_name(room_type),
		_room_name(room_type))
	_status_message = "%s: %s" % [Loc.t("dungeon.room"), _room_name(room_type)]
	_status_ticks = 90
	hud.flash_message(_status_message)
	if not first and not spawned_rooms.has(room_id):
		_spawn_contents(room)
	queue_redraw()


func _spawn_contents(room: Dictionary) -> void:
	var room_id: int = int(room["id"])
	spawned_rooms[room_id] = true
	var room_type: String = str(room["type"])
	var definition: Dictionary = room_defs.get(room_type, {})
	var rect: Rect2 = room["rect"]

	match room_type:
		"combat", "trap":
			var spawns: Array = definition.get("spawns", [])
			var index: int = 0
			for enemy_key in spawns:
				var enemy_data: Dictionary = enemy_defs.get(str(enemy_key), {})
				if enemy_data.is_empty():
					continue
				var angle: float = TAU * float(index) / float(maxi(1, spawns.size()))
				var offset: Vector2 = Vector2(cos(angle), sin(angle)) * (rect.size.x * 0.22)
				_spawn_enemy(enemy_data, rect.position + rect.size * 0.5 + offset, rect)
				index += 1
			if room_type == "trap":
				_arm_traps(rect, definition)
		"boss":
			var boss_key: String = str(definition.get("boss", "lab_warden"))
			var boss_data: Dictionary = enemy_defs.get(boss_key, {})
			if not boss_data.is_empty():
				var boss = _spawn_enemy(boss_data, rect.position + rect.size * 0.5 + Vector2(0, -40), rect)
				boss_active = true
				hud.set_boss(true, boss.hp, boss.max_hp)
		"loot":
			chests.append({
				"position": rect.position + rect.size * 0.5,
				"rect": Rect2(rect.position + rect.size * 0.5 - Vector2(22, 22), Vector2(44, 44)),
				"taken": false,
				"table": str(definition.get("loot_table", "lab_cache")),
			})
			cleared_rooms[room_id] = true
			room["cleared"] = true
		"rest":
			rest_pads.append({
				"position": rect.position + rect.size * 0.5,
				"rect": Rect2(rect.position + rect.size * 0.5 - Vector2(46, 46), Vector2(92, 92)),
				"used": false,
				"heal": int(definition.get("heal", 25)),
			})
			cleared_rooms[room_id] = true
			room["cleared"] = true
		_:
			cleared_rooms[room_id] = true
			room["cleared"] = true
	queue_redraw()


func _spawn_enemy(definition: Dictionary, position: Vector2, rect: Rect2):
	var enemy = EnemyScript.new()
	enemy.setup(definition, rect)
	enemy.global_position = position
	world.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.projectile_requested.connect(_on_enemy_projectile)
	enemies.append(enemy)
	return enemy


func _arm_traps(rect: Rect2, definition: Dictionary) -> void:
	var damage: int = int(definition.get("trap_damage", 10))
	var telegraph: int = int(definition.get("trap_telegraph_ticks", 45))
	for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var center: Vector2 = rect.position + rect.size * 0.5 + offset * (rect.size * 0.22)
		traps.append({
			"rect": Rect2(center - Vector2(40, 40), Vector2(80, 80)),
			"damage": damage,
			"telegraph_ticks": telegraph,
			"telegraph": 0,
			"cooldown": 60,
			"timer": 60 + int(offset.x * 20) + 90,
		})


func _update_enemies() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < (float(enemy.radius) + float(player.radius) + 2.0):
			if player.take_damage(int(enemy.touch_damage), enemy.global_position):
				pass
		if bool(enemy.is_boss):
			hud.set_boss(true, enemy.hp, enemy.max_hp)
	var alive_enemies: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			alive_enemies.append(enemy)
	enemies = alive_enemies


func _update_projectiles() -> void:
	var alive: Array = []
	for projectile in projectiles:
		if not is_instance_valid(projectile) or not projectile.alive:
			continue
		alive.append(projectile)
		if projectile.from_player:
			for enemy in enemies:
				if not is_instance_valid(enemy) or not enemy.alive:
					continue
				if projectile.rect().intersects(Rect2(enemy.global_position - Vector2(enemy.radius, enemy.radius),
						Vector2(enemy.radius, enemy.radius) * 2.0)):
					enemy.take_damage(int(projectile.damage), projectile.global_position)
					player.gain_energy(8.0)
					projectile.alive = false
					projectile.queue_free()
					break
		else:
			if projectile.rect().intersects(Rect2(player.global_position - Vector2(player.radius, player.radius),
					Vector2(player.radius, player.radius) * 2.0)):
				player.take_damage(int(projectile.damage), projectile.global_position)
				projectile.alive = false
				projectile.queue_free()
	projectiles = alive


func _update_traps() -> void:
	for trap in traps:
		if int(trap["telegraph"]) > 0:
			trap["telegraph"] = int(trap["telegraph"]) - 1
			if int(trap["telegraph"]) == 0:
				var rect: Rect2 = trap["rect"]
				if rect.has_point(player.global_position):
					player.take_damage(int(trap["damage"]), rect.get_center())
				trap["cooldown"] = 150
		elif int(trap["cooldown"]) > 0:
			trap["cooldown"] = int(trap["cooldown"]) - 1
		else:
			trap["timer"] = int(trap["timer"]) - 1
			if int(trap["timer"]) <= 0:
				trap["telegraph"] = int(trap["telegraph_ticks"])
				trap["timer"] = 210


func _update_pickups() -> void:
	for chest in chests:
		if bool(chest["taken"]):
			continue
		if (chest["rect"] as Rect2).has_point(player.global_position):
			chest["taken"] = true
			var table: Array = (loot_tables.get(str(chest["table"]), []) as Array)
			var gained: int = 0
			for entry in table:
				gained += int((entry as Dictionary).get("value", 0))
				var heal: int = int((entry as Dictionary).get("heal", 0))
				if heal > 0:
					player.heal(heal)
			if table.is_empty():
				gained = 10
			loot_count += gained
			hud.set_loot(loot_count)
			hud.flash_message(Loc.t("dungeon.loot", [str(gained)]))
	for pad in rest_pads:
		if bool(pad["used"]):
			continue
		if (pad["rect"] as Rect2).has_point(player.global_position):
			pad["used"] = true
			player.heal(int(pad["heal"]))
			hud.flash_message("+%d HP" % int(pad["heal"]))


func _sync_doors() -> void:
	for room_id in door_bodies.keys():
		var room: Dictionary = generator.room(int(room_id))
		if room.is_empty():
			continue
		var open: bool = bool(room["cleared"]) or int(room_id) != current_room
		for entry in (door_bodies[room_id] as Array):
			if bool(entry.get("open", false)) != open:
				_set_door_open(entry, open)
	# The room the player is inside keeps its doors locked until cleared.
	if current_room >= 0:
		var current: Dictionary = generator.room(current_room)
		if not current.is_empty() and not bool(current["cleared"]):
			for entry in (door_bodies.get(current_room, []) as Array):
				if bool(entry.get("open", false)):
					_set_door_open(entry, false)
	hud.set_doors(current_room >= 0 and not bool(generator.room(current_room).get("cleared", true)))


func _on_enemy_died(enemy) -> void:
	if bool(enemy.is_boss):
		boss_active = false
		hud.set_boss(false)
		_finish(true)
		return
	var room: Dictionary = generator.room(current_room)
	if room.is_empty():
		return
	var remaining: bool = false
	for other in enemies:
		if is_instance_valid(other) and other != enemy and other.alive:
			remaining = true
			break
	if not remaining:
		room["cleared"] = true
		cleared_rooms[int(room["id"])] = true
		hud.flash_message(Loc.t("dungeon.cleared"))


func _on_player_attack(rect: Rect2, damage: int) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var enemy_rect := Rect2(enemy.global_position - Vector2(enemy.radius, enemy.radius),
			Vector2(enemy.radius, enemy.radius) * 2.0)
		if rect.intersects(enemy_rect):
			enemy.take_damage(damage, player.global_position)
			player.gain_energy(10.0)


func _on_player_special(origin: Vector2, direction: Vector2) -> void:
	var projectile = ProjectileScript.new()
	projectile.setup(origin + direction * 26.0, direction.normalized() * 520.0, 16, 12.0, Color("f5a623"), true)
	world.add_child(projectile)
	projectiles.append(projectile)


func _on_enemy_projectile(origin: Vector2, velocity: Vector2, damage: int, color: Color) -> void:
	var projectile = ProjectileScript.new()
	projectile.setup(origin, velocity, damage, 9.0, color, false)
	world.add_child(projectile)
	projectiles.append(projectile)


func _on_player_hp(current: int, maximum: int) -> void:
	if hud != null:
		hud.set_hp(current, maximum)


func _on_player_died() -> void:
	_finish(false)


func _finish(won: bool) -> void:
	if finished:
		return
	finished = true
	get_tree().paused = false
	var result: Dictionary = {
		"mode": "dungeon",
		"won": won,
		"seed": seed_value,
		"floor": current_room + 1,
		"loot": loot_count,
		"temporary": true,
	}
	SaveManager.record_result("dungeon", result)
	SceneRouter.change_scene("res://scenes/menus/results.tscn", result)


func _room_name(room_type: String) -> String:
	var key: String = str(ROOM_NAME_KEYS.get(room_type, ""))
	if key.is_empty():
		return room_type
	return Loc.t(key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not SceneRouter.has_overlay():
		SceneRouter.push_overlay("res://scenes/menus/pause_menu.tscn", {"context": "dungeon"})
		get_tree().paused = true
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var rooms: Array = layout.get("rooms", [])
	for room in rooms:
		var rect: Rect2 = room["rect"]
		var room_type: String = str(room["type"])
		var tint: Color = _room_tint(room_type)
		draw_rect(rect, tint, true)
		draw_rect(rect.grow(-WALL_THICKNESS), Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15, 1.0), true)
		if not theme.is_empty():
			# A thin accent band reads as the theme at a glance without needing art.
			var accent: Color = DungeonThemes.color_of(theme, "accent", "#7f8ca8")
			draw_rect(
				Rect2(rect.position + Vector2(WALL_THICKNESS, WALL_THICKNESS), Vector2(rect.size.x - WALL_THICKNESS * 2.0, 3.0)),
				Color(accent.r, accent.g, accent.b, 0.5), true)
		# Door gaps, drawn as openings in the wall band.
		for entry in (door_bodies.get(int(room["id"]), []) as Array):
			var door_rect: Rect2 = entry["rect"]
			var open: bool = bool(entry.get("open", false))
			draw_rect(door_rect, Color(0.08, 0.09, 0.13, 0.9) if open else Color("e5484d"), true)
	if not traps.is_empty():
		for trap in traps:
			var rect: Rect2 = trap["rect"]
			var armed: bool = int(trap["telegraph"]) > 0
			draw_rect(rect, Color(0.9, 0.2, 0.2, 0.25) if armed else Color(0.5, 0.35, 0.2, 0.2), true)
			draw_rect(rect, Color("e5484d") if armed else Color(0.6, 0.5, 0.35, 0.6), false, 2.0)
	for chest in chests:
		if bool(chest["taken"]):
			continue
		var position: Vector2 = chest["position"]
		draw_rect(Rect2(position - Vector2(20, 16), Vector2(40, 32)), Color("f5a623"), true)
		draw_rect(Rect2(position - Vector2(20, 16), Vector2(40, 32)), Color(0, 0, 0, 0.6), false, 2.0)
	for pad in rest_pads:
		var position: Vector2 = pad["position"]
		var color: Color = Color("46a758") if not bool(pad["used"]) else Color(0.3, 0.4, 0.32, 0.4)
		draw_circle(position, 44.0, Color(color.r, color.g, color.b, 0.22))
		draw_arc(position, 44.0, 0.0, TAU, 32, color, 3.0)


## The selected character's world is only a hint: a Sand Village run leans sandy,
## but the seed still decides when the hint does not match any theme.
func _theme_hint() -> String:
	var entry: Dictionary = Session.p1
	var character_id: int = int(entry.get("id", 0))
	if str(entry.get("kind", "")) != "character" or character_id <= 0:
		return ""
	var character: Dictionary = GameData.get_character(character_id)
	return str(character.get("world", ""))


func _room_tint(room_type: String) -> Color:
	var base: Color = _room_tint_base(room_type)
	if theme.is_empty():
		return base
	var floor_color: Color = DungeonThemes.color_of(theme, "floor", "#1d2433")
	return base.lerp(floor_color, 0.45)


func _room_tint_base(room_type: String) -> Color:
	match room_type:
		"start":
			return Color("1d2433")
		"combat":
			return Color("232b3d")
		"trap":
			return Color("2a2320")
		"loot":
			return Color("242d24")
		"rest":
			return Color("1e2a2e")
		"boss":
			return Color("2c1f26")
		_:
			return Color("1d2433")
