extends Node2D
## TEMPORARY ART — procedural placeholder rig.
##
## This is NOT character art. It exists so that movement, hitboxes, timing and
## camera behaviour can be judged before a single approved sprite frame exists.
## It is drawn in code on purpose: no image is imported, and nothing here can be
## mistaken for an approved anime design.
##
## The rig always draws exactly two arms, two legs, one head and one torso, which
## makes limb-count drift impossible inside the placeholder. That says nothing
## about final sprite consistency — that still requires human review.

const States = preload("res://scripts/combat/fighter_states.gd")

var fighter = null

const HURTBOX_COLOR := Color("46a758")
const HITBOX_COLOR := Color("e5484d")


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if fighter != null:
		queue_redraw()


func _draw() -> void:
	if fighter == null:
		return
	var clip: String = str(fighter.anim_clip)
	var t: float = float(fighter.animation_progress())
	var facing: int = int(fighter.facing)
	var pose: Dictionary = _pose_for(clip, t, facing)

	var primary: Color = fighter.fighter_color()
	var secondary: Color = Color(str(fighter.config.get("secondary", "#1b2f57")))
	var accent: Color = Color(str(fighter.config.get("accent", "#cfe0ff")))
	var outline: Color = Color(0.05, 0.06, 0.09, 0.85)

	var hip := Vector2(0, pose["hip_y"])
	var shoulder := Vector2(0, pose["shoulder_y"])

	# Ground contact shadow (fixed; the feet anchor defines the true ground point).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	draw_circle(Vector2(0, -2), 26.0, Color(0, 0, 0, 0.30))

	if bool(pose.get("prone", false)):
		_draw_prone(primary, secondary, accent, outline, facing)
	else:
		# Back leg / arm first, then torso, then front limb on top.
		_draw_leg(hip, float(pose["leg_back"]), secondary, outline, facing)
		_draw_arm(shoulder, float(pose["arm_back"]), secondary, outline, facing, 9.0)
		_draw_torso(hip, shoulder, primary, outline, float(pose["lean"]), facing)
		_draw_leg(hip, float(pose["leg_front"]), primary.darkened(0.12), outline, facing)
		_draw_arm(shoulder, float(pose["arm_front"]), primary.lightened(0.06), outline, facing, 10.0)
		_draw_head(shoulder, primary, accent, outline, facing, float(pose["head_tilt"]))

	if fighter.temporary:
		_draw_tag(accent)

	if GameDebug != null and GameDebug.show_hurtboxes:
		_draw_boxes()


func _draw_leg(hip: Vector2, angle: float, color: Color, outline: Color, facing: int) -> void:
	var knee := _bend(hip, angle * facing, 38.0, -0.35 * facing)
	var foot := _bend(knee, (angle * 0.4 - 4.0) * facing, 40.0, 0.15 * facing)
	draw_line(hip, knee, outline, 17.0, true)
	draw_line(hip, knee, color, 12.0, true)
	draw_line(knee, foot, outline, 15.0, true)
	draw_line(knee, foot, color, 10.0, true)
	draw_circle(foot + Vector2(facing * 4.0, 1.0), 7.0, outline)
	draw_circle(foot + Vector2(facing * 4.0, 0.0), 5.0, color.darkened(0.25))


func _draw_arm(shoulder: Vector2, angle: float, color: Color, outline: Color, facing: int, width: float) -> void:
	var elbow := _bend(shoulder, angle * facing, 26.0, 0.20 * facing)
	var hand := _bend(elbow, (angle * 1.15 + 8.0) * facing, 24.0, 0.30 * facing)
	draw_line(shoulder, elbow, outline, width + 5.0, true)
	draw_line(shoulder, elbow, color, width, true)
	draw_line(elbow, hand, outline, width + 3.0, true)
	draw_line(elbow, hand, color, width - 1.0, true)
	draw_circle(hand, 6.5, outline)
	draw_circle(hand, 4.5, color.lightened(0.1))


func _draw_torso(hip: Vector2, shoulder: Vector2, color: Color, outline: Color, lean: float, facing: int) -> void:
	var offset := Vector2(lean * facing, 0)
	var points := PackedVector2Array([
		hip + Vector2(-14, 4),
		shoulder + Vector2(-17, -2) + offset,
		shoulder + Vector2(17, -2) + offset,
		hip + Vector2(14, 4),
	])
	draw_colored_polygon(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, 2.5, true)
	# Waist band, keeps the silhouette readable at small sizes.
	draw_line(hip + Vector2(-13, -2), hip + Vector2(13, -2), outline.darkened(0.1), 3.0)


func _draw_head(shoulder: Vector2, primary: Color, accent: Color, outline: Color, facing: int, tilt: float) -> void:
	var center: Vector2 = shoulder + Vector2((tilt * 4.0) * facing, -17.0)
	draw_circle(center, 15.0, outline)
	draw_circle(center, 13.0, Color("e6c3a5").lerp(primary, 0.15))
	# Hair / headband band drawn as a single accent stripe (placeholder only).
	draw_line(center + Vector2(-13, -4), center + Vector2(13, -4), accent, 5.0, true)
	draw_circle(center + Vector2(facing * 5.0, 1.0), 2.0, outline)


func _draw_prone(primary: Color, secondary: Color, accent: Color, outline: Color, facing: int) -> void:
	# Lying pose: body horizontal, feet toward -facing.
	var hip := Vector2(facing * -10.0, -16.0)
	var shoulder := Vector2(facing * 26.0, -18.0)
	draw_line(hip, shoulder, outline, 26.0, true)
	draw_line(hip, shoulder, primary, 21.0, true)
	draw_line(Vector2(facing * -10.0, -16.0), Vector2(facing * -46.0, -8.0), secondary, 12.0, true)
	draw_line(Vector2(facing * 26.0, -18.0), Vector2(facing * 46.0, -6.0), secondary, 10.0, true)
	draw_circle(Vector2(facing * 38.0, -20.0), 12.0, outline)
	draw_circle(Vector2(facing * 38.0, -20.0), 10.0, accent)


func _draw_tag(accent: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text: String = "TEMP"
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(-width * 0.5, -156.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	draw_line(Vector2(-width * 0.5, -152.0), Vector2(width * 0.5, -152.0), Color(accent.r, accent.g, accent.b, 0.5), 1.0)


func _draw_boxes() -> void:
	var to_local := func(rect: Rect2) -> Rect2:
		return Rect2(rect.position - fighter.global_position, rect.size)
	var hurt: Rect2 = to_local.call(fighter.hurtbox())
	draw_rect(hurt, Color(HURTBOX_COLOR.r, HURTBOX_COLOR.g, HURTBOX_COLOR.b, 0.10), true)
	draw_rect(hurt, HURTBOX_COLOR, false, 1.5)
	var hit: Dictionary = fighter.active_hit()
	if not hit.is_empty():
		var rect: Rect2 = to_local.call(hit["rect"])
		draw_rect(rect, Color(HITBOX_COLOR.r, HITBOX_COLOR.g, HITBOX_COLOR.b, 0.20), true)
		draw_rect(rect, HITBOX_COLOR, false, 2.0)
		if GameDebug != null:
			GameDebug.report_hitbox_count(1)


func _bend(origin: Vector2, angle_degrees: float, length: float, bend: float) -> Vector2:
	var direction := Vector2(sin(deg_to_rad(angle_degrees)), cos(deg_to_rad(angle_degrees)))
	var mid := origin + direction * (length * 0.5)
	var bend_dir := direction.rotated(bend)
	return origin + (mid - origin) + bend_dir * (length * 0.5)


# --- Pose table ------------------------------------------------------------

func _base_pose() -> Dictionary:
	return {
		"hip_y": -46.0,
		"shoulder_y": -96.0,
		"lean": 0.0,
		"arm_front": 14.0,
		"arm_back": -8.0,
		"leg_front": 12.0,
		"leg_back": -12.0,
		"head_tilt": 0.0,
		"prone": false,
	}


func _pose_for(clip: String, t: float, _facing: int) -> Dictionary:
	var pose: Dictionary = _base_pose()
	var wave: float = sin(t * TAU)
	match clip:
		"idle":
			pose["hip_y"] = -46.0 + wave * 1.5
			pose["arm_front"] = 16.0 + wave * 3.0
			pose["arm_back"] = -10.0 - wave * 3.0
		"walk":
			pose["leg_front"] = 24.0 * wave
			pose["leg_back"] = -24.0 * wave
			pose["arm_front"] = 18.0 - 14.0 * wave
			pose["arm_back"] = -14.0 + 14.0 * wave
			pose["hip_y"] = -46.0 + absf(wave) * 2.0
		"run":
			pose["lean"] = 6.0
			pose["leg_front"] = 40.0 * wave
			pose["leg_back"] = -40.0 * wave
			pose["arm_front"] = 34.0 - 26.0 * wave
			pose["arm_back"] = -30.0 + 26.0 * wave
			pose["hip_y"] = -44.0 + absf(wave) * 3.0
		"jump_start":
			pose["hip_y"] = -38.0
			pose["leg_front"] = 26.0
			pose["leg_back"] = -18.0
			pose["arm_front"] = -30.0
		"jump_loop", "fall":
			pose["hip_y"] = -52.0
			pose["leg_front"] = 34.0
			pose["leg_back"] = -26.0
			pose["arm_front"] = -46.0
			pose["arm_back"] = 28.0
		"landing":
			pose["hip_y"] = -34.0
			pose["leg_front"] = 30.0
			pose["leg_back"] = -22.0
			pose["lean"] = 8.0
		"crouch":
			pose["hip_y"] = -28.0
			pose["shoulder_y"] = -70.0
			pose["leg_front"] = 46.0
			pose["leg_back"] = -40.0
			pose["lean"] = 10.0
		"block":
			pose["arm_front"] = 74.0
			pose["arm_back"] = 52.0
			pose["lean"] = -6.0
			pose["hip_y"] = -42.0
		"block_hit":
			pose["arm_front"] = 88.0
			pose["arm_back"] = 66.0
			pose["lean"] = -16.0
			pose["hip_y"] = -40.0
		"light_attack":
			var extend: float = clampf(t * 2.2, 0.0, 1.0)
			pose["arm_front"] = lerpf(20.0, 96.0, extend)
			pose["lean"] = 10.0 * extend
			pose["leg_front"] = 18.0
			pose["arm_back"] = -24.0
		"heavy_attack":
			var swing: float = clampf(t * 1.6, 0.0, 1.0)
			pose["arm_front"] = lerpf(-10.0, 118.0, swing)
			pose["lean"] = 16.0 * swing
			pose["leg_front"] = 28.0
			pose["leg_back"] = -26.0
			pose["hip_y"] = -42.0
		"special":
			var push: float = clampf((t - 0.35) * 2.4, 0.0, 1.0)
			pose["arm_front"] = lerpf(50.0, 92.0, push)
			pose["arm_back"] = lerpf(30.0, 78.0, push)
			pose["lean"] = 8.0 * push
			pose["hip_y"] = -42.0 - 3.0 * push
		"ultimate":
			var unleash: float = clampf(t * 1.5, 0.0, 1.0)
			pose["arm_front"] = lerpf(-40.0, 86.0, unleash)
			pose["arm_back"] = lerpf(-50.0, 70.0, unleash)
			pose["lean"] = -10.0 * (1.0 - unleash) + 12.0 * unleash
		"hit_reaction":
			pose["lean"] = -18.0
			pose["arm_front"] = -22.0
			pose["arm_back"] = -40.0
			pose["hip_y"] = -44.0
			pose["head_tilt"] = -10.0
		"knockdown":
			pose["prone"] = true
		"defeat":
			pose["prone"] = true
		"get_up":
			pose["hip_y"] = -30.0
			pose["leg_front"] = 34.0
			pose["leg_back"] = -30.0
			pose["lean"] = 14.0
		"victory":
			pose["arm_front"] = -158.0 + wave * 6.0
			pose["arm_back"] = -150.0 - wave * 6.0
			pose["hip_y"] = -48.0 - absf(wave) * 2.0
		_:
			pass
	return pose
