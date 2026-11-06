extends Control
## Animation review tool (development aid).
##
## Requirements it serves: pause, slow playback, frame-by-frame stepping and a
## per-clip frame counter. It runs on the TEMPORARY procedural rig, which is the
## only thing that exists before a design is approved — so it reviews *timing*,
## never final art quality.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FighterScript = preload("res://scripts/characters/fighter.gd")
const States = preload("res://scripts/combat/fighter_states.gd")

const SPEEDS: Array[float] = [1.0, 0.5, 0.25, 0.0]

var _fighter
var _viewport: Control
var _clip_label: Label
var _frame_label: Label
var _playing: bool = true
var _speed_index: int = 0
var _clip: String = "idle"


func _ready() -> void:
	theme = UIKit.theme()
	_build()
	_spawn_fighter()


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("review.title"), Loc.t("review.subtitle"))

	var stage_panel := UIKit.panel(Color("101725"), UIKit.OUTLINE)
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage_panel)
	_viewport = Control.new()
	_viewport.custom_minimum_size = Vector2(900, 460)
	_viewport.clip_contents = true
	stage_panel.add_child(_viewport)

	var info := UIKit.hbox(24)
	column.add_child(info)
	_clip_label = UIKit.label("", 0.95, UIKit.TEXT)
	info.add_child(_clip_label)
	_frame_label = UIKit.label("", 0.95, UIKit.ACCENT)
	info.add_child(_frame_label)
	info.add_child(UIKit.label(Loc.t("review.placeholder"), 0.78, UIKit.WARN))

	var controls := UIKit.hbox(10)
	column.add_child(controls)
	controls.add_child(UIKit.tiny_button(Loc.t("review.pause"), _toggle_play, 160))
	controls.add_child(UIKit.tiny_button(Loc.t("review.step_back"), _step_back, 160))
	controls.add_child(UIKit.tiny_button(Loc.t("review.step_forward"), _step_forward, 160))
	controls.add_child(UIKit.tiny_button(Loc.t("review.speed"), _cycle_speed, 160))
	controls.add_child(UIKit.expander())
	controls.add_child(UIKit.button(Loc.t("common.back"), func() -> void: SceneRouter.change_scene(SceneRouter.MAIN_MENU), 220))

	var clips := UIKit.hbox(8)
	column.add_child(clips)
	clips.add_child(UIKit.label(Loc.t("review.clip"), 0.8, UIKit.MUTED))
	for clip in ["idle", "walk", "run", "jump_start", "crouch", "block", "light_attack",
			"heavy_attack", "special", "ultimate", "hit_reaction", "knockdown", "get_up", "victory", "defeat"]:
		var clip_name: String = clip
		clips.add_child(UIKit.tiny_button(clip_name, func() -> void: _select_clip(clip_name), 0))


func _spawn_fighter() -> void:
	_fighter = FighterScript.new()
	var moveset: Dictionary = GameData.lab_moveset("lab_dummy_a")
	_fighter.setup(moveset, {"name": "LAB DUMMY A", "temporary": true}, 0, null)
	_viewport.add_child(_fighter)
	_fighter.set_physics_process(false)
	_fighter.global_position = Vector2(450, 380)
	_fighter.facing = 1
	_fighter._set_anim(_clip, true)
	_update_labels()


func _toggle_play() -> void:
	_playing = not _playing


func _step_back() -> void:
	_advance_frames(-1)


func _step_forward() -> void:
	_advance_frames(1)


func _advance_frames(delta_frames: int) -> void:
	_playing = false
	var fps: float = maxf(1.0, float(_fighter.anim_fps))
	_fighter.anim_time = maxf(0.0, _fighter.anim_time + float(delta_frames) / fps)
	if _fighter.visual != null:
		_fighter.visual.queue_redraw()
	_update_labels()


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_playing = SPEEDS[_speed_index] > 0.0


func _select_clip(clip: String) -> void:
	_clip = clip
	_fighter._set_anim(clip, true)
	_update_labels()


func _process(delta: float) -> void:
	if _fighter == null:
		return
	if _playing:
		var speed: float = SPEEDS[_speed_index]
		_fighter.anim_time += delta * speed
		var duration: float = _fighter._anim_duration()
		if duration > 0.0 and _fighter.anim_time > duration:
			_fighter.anim_time = 0.0 if _fighter.anim_loop else duration
		if _fighter.visual != null:
			_fighter.visual.queue_redraw()
	_update_labels()


func _update_labels() -> void:
	if _fighter == null or _clip_label == null:
		return
	_clip_label.text = "%s: %s   ·   %.0f fps   ·   %s" % [
		Loc.t("review.clip"), _fighter.anim_clip, float(_fighter.anim_fps),
		"loop" if _fighter.anim_loop else "one-shot"
	]
	_frame_label.text = "%s %d   ·   x%.2f   ·   %s" % [
		"frame", _fighter.animation_frame(), SPEEDS[_speed_index],
		"playing" if _playing else Loc.t("review.pause")
	]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		KEY_COMMA:
			_step_back()
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			_step_forward()
			get_viewport().set_input_as_handled()
