extends CanvasLayer
## Dungeon HUD: health, energy, current area, seed, door state and boss health.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var hp_bar: ProgressBar
var hp_text: Label
var energy_bar: ProgressBar
var area_label: Label
var room_label: Label
var door_label: Label
var loot_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label
var temporary_label: Label
var _room_total: int = 0


func _ready() -> void:
	layer = 10


func build(seed_value: int, total_rooms: int) -> void:
	_room_total = total_rooms
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := UIKit.panel(Color(0.05, 0.06, 0.1, 0.86), UIKit.OUTLINE)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 28
	panel.offset_top = 24
	panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(panel)
	var column := UIKit.vbox(6)
	panel.add_child(column)

	area_label = UIKit.label("", 1.0, UIKit.TEXT)
	column.add_child(area_label)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.custom_minimum_size = Vector2(460, 26)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIKit.OK
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("11151d")
	bg.set_corner_radius_all(6)
	bg.border_color = UIKit.OUTLINE
	bg.set_border_width_all(2)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("background", bg)
	column.add_child(hp_bar)
	hp_text = UIKit.label("", 0.8, UIKit.MUTED)
	column.add_child(hp_text)
	energy_bar = ProgressBar.new()
	energy_bar.show_percentage = false
	energy_bar.max_value = 100
	energy_bar.custom_minimum_size = Vector2(300, 12)
	var energy_fill := StyleBoxFlat.new()
	energy_fill.bg_color = UIKit.ACCENT
	energy_fill.set_corner_radius_all(6)
	energy_bar.add_theme_stylebox_override("fill", energy_fill)
	energy_bar.add_theme_stylebox_override("background", bg)
	column.add_child(energy_bar)
	room_label = UIKit.label("", 0.85, UIKit.WARN)
	column.add_child(room_label)
	door_label = UIKit.label("", 0.8, UIKit.DANGER)
	column.add_child(door_label)
	loot_label = UIKit.label("", 0.8, UIKit.OK)
	column.add_child(loot_label)

	boss_panel = UIKit.panel(Color(0.12, 0.06, 0.08, 0.9), UIKit.DANGER)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -360
	boss_panel.offset_right = 360
	boss_panel.offset_top = 40
	root.add_child(boss_panel)
	var boss_column := UIKit.vbox(4)
	boss_panel.add_child(boss_column)
	boss_label = UIKit.label(Loc.t("dungeon.boss"), 0.95, UIKit.DANGER)
	boss_column.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.max_value = 100
	boss_bar.custom_minimum_size = Vector2(680, 22)
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = UIKit.DANGER
	boss_fill.set_corner_radius_all(6)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_column.add_child(boss_bar)
	boss_panel.visible = false

	temporary_label = UIKit.label("%s · %s · %s" % [
		Loc.t("dungeon.temporary"), Loc.t("common.art_temporary"),
		Loc.t("dungeon.seed", [str(seed_value)])
	], 0.72, UIKit.MUTED)
	temporary_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	temporary_label.offset_left = 28
	temporary_label.offset_top = -52
	root.add_child(temporary_label)

	var hint := UIKit.label("%s · %s" % [Loc.t("match.pause_hint"), Loc.t("menu.debug_hint")], 0.72, UIKit.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -700
	hint.offset_top = -52
	hint.offset_right = -28
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	area_label.text = Loc.t("dungeon.title")


func set_hp(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_text.text = "%d / %d" % [current, maximum]


func set_energy(value: float) -> void:
	energy_bar.value = value


func set_area(index: int, total: int, room_type: String, room_name: String) -> void:
	_room_total = maxi(_room_total, total)
	area_label.text = "%s  ·  %s" % [Loc.t("dungeon.floor", [str(index), str(total)]), room_name]
	room_label.text = "%s: %s" % [Loc.t("dungeon.room"), room_type]


func set_doors(locked: bool) -> void:
	door_label.text = Loc.t("dungeon.door_locked") if locked else ""
	door_label.visible = locked


func set_loot(count: int) -> void:
	loot_label.text = Loc.t("dungeon.loot", [str(count)])


func set_boss(visible_state: bool, current: int = 0, maximum: int = 1) -> void:
	boss_panel.visible = visible_state
	if visible_state:
		boss_bar.max_value = maximum
		boss_bar.value = current


func flash_message(text: String) -> void:
	room_label.text = text
