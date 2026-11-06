extends Node2D
## Stage rendering for the versus camera.
##
## Phase 2 rule: only temporary geometry is drawn, and anything that is not an
## approved environment is explicitly labelled as unapproved on screen. The
## renderer therefore never implies that a reinterpreted location is official.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var stage: Dictionary = {}
var bounds_left: float = 120.0
var bounds_right: float = 1800.0
var floor_y: float = 820.0


func setup(p_stage: Dictionary) -> void:
	stage = p_stage
	floor_y = float(stage.get("floor_y", 820.0))
	var bounds: Dictionary = stage.get("bounds", {})
	bounds_left = float(bounds.get("left", 120.0))
	bounds_right = float(bounds.get("right", 1800.0))
	queue_redraw()


func _draw() -> void:
	var palette: Dictionary = stage.get("palette", {})
	var sky_top := Color(str(palette.get("sky_top", "#101725")))
	var sky_bottom := Color(str(palette.get("sky_bottom", "#1b2436")))
	var ground := Color(str(palette.get("ground", "#222c3d")))
	var ground_line := Color(str(palette.get("ground_line", "#31405a")))
	var accent := Color(str(palette.get("accent", "#f5a623")))
	var status: String = str(stage.get("status", "PENDING")).to_upper()

	# Sky bands (cheap vertical gradient, no textures).
	var bands: int = 24
	var band_height: float = floor_y / float(bands)
	for index in range(bands):
		var t: float = float(index) / float(bands - 1)
		draw_rect(Rect2(0, index * band_height, 1920.0, band_height + 1.0), sky_top.lerp(sky_bottom, t), true)

	# Horizon silhouette + ground.
	draw_rect(Rect2(0, floor_y, 1920.0, 1080.0 - floor_y), ground, true)
	draw_line(Vector2(0, floor_y), Vector2(1920, floor_y), ground_line, 3.0)

	if status == "TEMPORARY":
		_draw_temporary_ground(ground_line, accent)
	else:
		_draw_pending_environment(accent)

	# Arena bounds markers, so the invisible walls are legible.
	draw_line(Vector2(bounds_left, 0), Vector2(bounds_left, floor_y), Color(accent.r, accent.g, accent.b, 0.18), 2.0)
	draw_line(Vector2(bounds_right, 0), Vector2(bounds_right, floor_y), Color(accent.r, accent.g, accent.b, 0.18), 2.0)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(48, 1044), "%s  ·  %s" % [str(stage.get("name", "STAGE")), status],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UIKit.MUTED.r, UIKit.MUTED.g, UIKit.MUTED.b, 0.9))


func _draw_temporary_ground(line_color: Color, accent: Color) -> void:
	# Ruler ticks make distances readable while testing frame data.
	for x in range(0, 1921, 120):
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y + 18), Color(line_color.r, line_color.g, line_color.b, 0.55), 2.0)
	for x in range(0, 1921, 480):
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y + 34), Color(accent.r, accent.g, accent.b, 0.5), 3.0)
	draw_line(Vector2(0, 940), Vector2(1920, 940), Color(line_color.r, line_color.g, line_color.b, 0.35), 2.0)


func _draw_pending_environment(accent: Color) -> void:
	# Unapproved environments get a neutral wireframe + explicit label, never
	# invented scenery that could pass for the final location.
	var grid_color := Color(0.55, 0.62, 0.75, 0.16)
	for x in range(0, 1960, 80):
		draw_line(Vector2(x, 240), Vector2(x, floor_y), grid_color, 1.0)
	for y in range(240, int(floor_y), 80):
		draw_line(Vector2(0, y), Vector2(1920, y), grid_color, 1.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(560, 420), "ENVIRONMENT NOT APPROVED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(accent.r, accent.g, accent.b, 0.55))
		draw_string(font, Vector2(560, 470), "PLACEHOLDER GEOMETRY — NO FINAL ART",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.85, 0.88, 0.95, 0.45))
