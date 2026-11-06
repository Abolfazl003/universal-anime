extends Node2D
## CombatManager — authoritative hit resolution for side-view fights.
##
## Guarantees required by the spec:
##  * hitboxes/hurtboxes come from data, never from the drawn sprite,
##  * a single attack phase can damage the same target at most once,
##  * multi-hit moves use explicit phases with their own instance ids,
##  * blocking changes damage/stun/knockback through data,
##  * body collision is resolved separately from combat boxes.

signal hit_resolved(attacker: Node, target: Node, result: Dictionary, move_id: String)
signal projectile_spawned(projectile: Node)

const ProjectileScript = preload("res://scripts/combat/projectile.gd")
const States = preload("res://scripts/combat/fighter_states.gd")

var fighters: Array = []
var projectiles: Array = []

var _hit_registry: Dictionary = {}
var _tick: int = 0
var _hitbox_count: int = 0

## Registry entries expire quickly; they only need to outlive the attack phase.
const REGISTRY_LIFETIME_TICKS: int = 40


func _ready() -> void:
	process_priority = 20  # run after fighters have moved
	# Fighters are plain children of this node in both modes, so registration is
	# automatic: forgetting an explicit call would silently disable all combat.
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	for child in get_children():
		_on_child_entered_tree(child)


func _on_child_entered_tree(node: Node) -> void:
	if node == null or not node.has_method("active_hit"):
		return
	add_fighter(node)


func _on_child_exiting_tree(node: Node) -> void:
	if fighters.has(node):
		fighters.erase(node)
	_sync_opponents()


func add_fighter(fighter) -> void:
	if fighter == null or fighters.has(fighter):
		return
	fighters.append(fighter)
	if fighter.has_signal("projectile_requested") and not fighter.projectile_requested.is_connected(_on_projectile_requested):
		fighter.projectile_requested.connect(_on_projectile_requested)
	_sync_opponents()


func clear() -> void:
	fighters.clear()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
	_hit_registry.clear()


func _sync_opponents() -> void:
	for fighter in fighters:
		for other in fighters:
			if other != fighter:
				fighter.opponent = other


func _physics_process(_delta: float) -> void:
	_tick += 1
	_prune_registry()
	_resolve_hits()
	_resolve_projectiles()
	_resolve_body_collision()
	if GameDebug != null:
		GameDebug.report_hitbox_count(_hitbox_count)


func _prune_registry() -> void:
	var expired: Array = []
	for key in _hit_registry.keys():
		if int(_hit_registry[key]) < _tick:
			expired.append(key)
	for key in expired:
		_hit_registry.erase(key)


func _register(key: String) -> void:
	_hit_registry[key] = _tick + REGISTRY_LIFETIME_TICKS


func _already_hit(key: String) -> bool:
	return _hit_registry.has(key)


func _resolve_hits() -> void:
	_hitbox_count = 0
	for attacker in fighters:
		if not is_instance_valid(attacker) or not attacker.is_alive():
			continue
		var hit: Dictionary = attacker.active_hit()
		if hit.is_empty():
			continue
		_hitbox_count += 1
		var rect: Rect2 = hit["rect"]
		for target in fighters:
			if target == attacker or not is_instance_valid(target):
				continue
			if not target.is_vulnerable():
				continue
			if not rect.intersects(target.hurtbox()):
				continue
			var key: String = "%d:%d" % [int(hit["instance"]), int(target.get_instance_id())]
			if _already_hit(key):
				continue
			_register(key)
			var was_stunned: bool = target.state == States.State.HITSTUN
			var result: Dictionary = target.receive_hit(hit, attacker)
			if not bool(result.get("applied", false)):
				continue
			var move: Dictionary = hit.get("move", {})
			attacker.notify_hit_confirmed()
			if not bool(result.get("blocked", false)):
				if was_stunned:
					attacker.register_combo()
				else:
					attacker.combo_count = 0
					attacker.register_combo()
				attacker.gain_on_hit(move)
			else:
				attacker.gain_on_hit(move)
			hit_resolved.emit(attacker, target, result, str(hit.get("move_id", "")))


func _on_projectile_requested(move: Dictionary, instance_id: int) -> void:
	var owner_fighter = null
	# The signal is emitted by the owning fighter; find it among our fighters.
	for fighter in fighters:
		if fighter.attack_instance == instance_id and fighter.current_move_id == str(move.get("id", "")):
			owner_fighter = fighter
			break
	if owner_fighter == null:
		return
	var projectile := ProjectileScript.new()
	projectile.setup(owner_fighter, move, int(owner_fighter.facing), instance_id)
	add_child(projectile)
	projectiles.append(projectile)
	projectile_spawned.emit(projectile)


func _resolve_projectiles() -> void:
	var alive_list: Array = []
	for projectile in projectiles:
		if not is_instance_valid(projectile) or not projectile.alive:
			continue
		alive_list.append(projectile)
		var rect: Rect2 = projectile.rect()
		var consumed: bool = false
		for target in fighters:
			if target == projectile.owner_fighter or not is_instance_valid(target):
				continue
			if not target.is_vulnerable():
				continue
			if not rect.intersects(target.hurtbox()):
				continue
			var key: String = "p%d:%d" % [int(projectile.instance_id), int(target.get_instance_id())]
			if _already_hit(key):
				continue
			_register(key)
			var hit: Dictionary = {
				"instance": int(projectile.instance_id) * 100,
				"rect": rect,
				"damage": int(projectile.move.get("damage", 0)),
				"move": projectile.move,
				"move_id": str(projectile.move.get("id", "")),
			}
			var was_stunned: bool = target.state == States.State.HITSTUN
			var result: Dictionary = target.receive_hit(hit, projectile.owner_fighter)
			if bool(result.get("applied", false)):
				projectile.owner_fighter.notify_hit_confirmed()
				if not bool(result.get("blocked", false)):
					if was_stunned:
						projectile.owner_fighter.register_combo()
					else:
						projectile.owner_fighter.combo_count = 0
						projectile.owner_fighter.register_combo()
				hit_resolved.emit(projectile.owner_fighter, target, result, str(hit["move_id"]))
			consumed = true
			break
		if consumed:
			projectile.despawn()
	projectiles = alive_list


func _resolve_body_collision() -> void:
	# Fighters cannot occupy the same space: symmetric push on the x axis.
	if fighters.size() < 2:
		return
	for i in range(fighters.size()):
		for j in range(i + 1, fighters.size()):
			var a = fighters[i]
			var b = fighters[j]
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var ra: Rect2 = a.hurtbox()
			var rb: Rect2 = b.hurtbox()
			if not ra.intersects(rb):
				continue
			var overlap: float = minf(ra.position.x + ra.size.x, rb.position.x + rb.size.x) - maxf(ra.position.x, rb.position.x)
			if overlap <= 0.0:
				continue
			var direction: float = signf(b.global_position.x - a.global_position.x)
			if is_zero_approx(direction):
				direction = 1.0
			var push: float = overlap * 0.5
			a.global_position.x -= push * direction
			b.global_position.x += push * direction


func active_hitbox_count() -> int:
	return _hitbox_count
