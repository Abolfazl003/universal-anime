extends CanvasLayer
## Versus HUD. Values are mirrored as numbers as well as bars, so information is
## never carried by colour alone.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var p1_name: Label
var p2_name: Label
var p1_hp: ProgressBar
var p2_hp: ProgressBar
var p1_hp_text: Label
var p2_hp_text: Label
var p1_special: ProgressBar
var p2_special: ProgressBar
var p1_ultimate: ProgressBar
var p2_ultimate: ProgressBar
var timer_label: Label
var round_label: Label
var wins_label: Label
var message_label: Label
var combo_label: Label
var temporary_label: Label

var _p1 = null
var _p2 = null


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Player 1 block (left).
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 40
	left.offset_top = 26
	left.custom_minimum_size = Vector2(720, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	p1_name = UIKit.label("", 1.1, UIKit.TEXT)
	left.add_child(p1_name)
	p1_hp = _bar(UIKit.INFO, 34)
	left.add_child(p1_hp)
	p1_hp_text = UIKit.label("", 0.8, UIKit.MUTED)
	left.add_child(p1_hp_text)
	var left_meters := UIKit.hbox(10)
	left.add_child(left_meters)
	p1_special = _bar(UIKit.WARN, 12)
	p1_special.custom_minimum_size = Vector2(300, 12)
	left_meters.add_child(p1_special)
	p1_ultimate = _bar(UIKit.ACCENT, 12)
	p1_ultimate.custom_minimum_size = Vector2(300, 12)
	left_meters.add_child(p1_ultimate)

	# Player 2 block (right).
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -760
	right.offset_top = 26
	right.offset_right = -40
	right.custom_minimum_size = Vector2(720, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	p2_name = UIKit.label("", 1.1, UIKit.TEXT)
	p2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(p2_name)
	p2_hp = _bar(UIKit.DANGER, 34)
	right.add_child(p2_hp)
	p2_hp_text = UIKit.label("", 0.8, UIKit.MUTED)
	p2_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(p2_hp_text)
	var right_meters := UIKit.hbox(10)
	right_meters.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(right_meters)
	p2_special = _bar(UIKit.WARN, 12)
	p2_special.custom_minimum_size = Vector2(300, 12)
	right_meters.add_child(p2_special)
	p2_ultimate = _bar(UIKit.ACCENT, 12)
	p2_ultimate.custom_minimum_size = Vector2(300, 12)
	right_meters.add_child(p2_ultimate)

	# Centre: timer + round.
	var centre := VBoxContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	centre.offset_top = 18
	centre.offset_left = -160
	centre.offset_right = 160
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 2)
	root.add_child(centre)
	timer_label = UIKit.label("99", 2.1, UIKit.TEXT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(timer_label)
	round_label = UIKit.label("", 0.85, UIKit.MUTED)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(round_label)
	wins_label = UIKit.label("", 0.8, UIKit.ACCENT)
	wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(wins_label)

	# Centre message (READY / FIGHT / K.O.).
	message_label = UIKit.label("", 2.4, UIKit.ACCENT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.offset_left = -520
	message_label.offset_right = 520
	message_label.offset_top = -170
	message_label.offset_bottom = -40
	root.add_child(message_label)

	# Combo counter.
	combo_label = UIKit.label("", 1.3, UIKit.WARN)
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	combo_label.offset_left = 120
	combo_label.offset_top = 260
	root.add_child(combo_label)

	temporary_label = UIKit.label("", 0.72, UIKit.WARN)
	temporary_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	temporary_label.offset_left = 40
	temporary_label.offset_top = -56
	temporary_label.offset_bottom = -24
	root.add_child(temporary_label)


func _bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("11151d")
	bg.set_corner_radius_all(6)
	bg.border_color = UIKit.OUTLINE
	bg.set_border_width_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func bind(fighter1, fighter2) -> void:
	_p1 = fighter1
	_p2 = fighter2
	if fighter1 != null:
		p1_name.text = _decorate(fighter1)
		p1_hp.max_value = fighter1.max_hp
		p1_special.max_value = fighter1.special_max
		p1_ultimate.max_value = fighter1.ultimate_max
		fighter1.hp_changed.connect(_on_p1_hp)
		fighter1.energy_changed.connect(_on_p1_energy)
		_on_p1_hp(fighter1.hp, fighter1.max_hp)
		_on_p1_energy(fighter1.special_energy, fighter1.ultimate_meter)
	if fighter2 != null:
		p2_name.text = _decorate(fighter2)
		p2_hp.max_value = fighter2.max_hp
		p2_special.max_value = fighter2.special_max
		p2_ultimate.max_value = fighter2.ultimate_max
		fighter2.hp_changed.connect(_on_p2_hp)
		fighter2.energy_changed.connect(_on_p2_energy)
		_on_p2_hp(fighter2.hp, fighter2.max_hp)
		_on_p2_energy(fighter2.special_energy, fighter2.ultimate_meter)
	var temp_parts: PackedStringArray = []
	for fighter in [fighter1, fighter2]:
		if fighter != null and fighter.temporary:
			temp_parts.append("%s = %s" % [fighter.display_name, Loc.t("hud.temporary")])
	if not temp_parts.is_empty():
		temporary_label.text = "%s · %s" % [Loc.t("common.art_temporary"), ", ".join(temp_parts)]
	else:
		temporary_label.text = ""


func _decorate(fighter) -> String:
	var suffix: String = ""
	if fighter.temporary:
		suffix = "  [%s]" % Loc.t("common.temporary")
	return "%s%s" % [fighter.display_name, suffix]


func _on_p1_hp(current: int, maximum: int) -> void:
	p1_hp.value = current
	p1_hp_text.text = "%d / %d" % [current, maximum]
	if _p1 != null:
		p1_hp_text.text += "  ·  %s" % _p1.state_name()


func _on_p2_hp(current: int, maximum: int) -> void:
	p2_hp.value = current
	p2_hp_text.text = "%d / %d" % [current, maximum]
	if _p2 != null:
		p2_hp_text.text = "%s  ·  %d / %d" % [_p2.state_name(), current, maximum]


func _on_p1_energy(special: float, ultimate: float) -> void:
	p1_special.value = special
	p1_ultimate.value = ultimate


func _on_p2_energy(special: float, ultimate: float) -> void:
	p2_special.value = special
	p2_ultimate.value = ultimate


func set_round(number: int, wins1: int, wins2: int) -> void:
	round_label.text = Loc.t("hud.round", [str(number)])
	wins_label.text = "%s  ·  %s" % [Loc.t("hud.wins", [str(wins1)]), Loc.t("hud.wins", [str(wins2)])]


func set_timer(seconds: float, enabled: bool) -> void:
	if not enabled:
		timer_label.text = "∞"
		return
	timer_label.text = "%02d" % int(ceil(maxf(seconds, 0.0)))


func set_message(text: String) -> void:
	message_label.text = text


func set_combo(count: int, to_right: bool) -> void:
	if count <= 1:
		combo_label.text = ""
		return
	combo_label.text = Loc.t("hud.combo", [str(count)])
	combo_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_RIGHT if to_right else Control.PRESET_CENTER_LEFT
	)
	combo_label.offset_left = -320 if to_right else 120
	combo_label.offset_right = -120 if to_right else 320
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if to_right else HORIZONTAL_ALIGNMENT_LEFT


func refresh_states() -> void:
	if _p1 != null:
		p1_hp_text.text = "%d / %d  ·  %s" % [_p1.hp, _p1.max_hp, _p1.state_name()]
	if _p2 != null:
		p2_hp_text.text = "%s  ·  %d / %d" % [_p2.state_name(), _p2.hp, _p2.max_hp]
