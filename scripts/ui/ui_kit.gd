extends RefCounted
## UIKit — one shared visual language for every screen, built in code.
##
## Why code: the project must stay reviewable and diff-able while no final art
## exists. Menus only contain layout + widgets; all text comes from Loc, all
## numbers come from data.

const BG := Color("0b0d14")
const PANEL := Color("151a26")
const PANEL_ALT := Color("1d2433")
const OUTLINE := Color("2b3446")
const TEXT := Color("e8eaf2")
const MUTED := Color("99a1b3")
const ACCENT := Color("f5a623")
const DANGER := Color("e5484d")
const OK := Color("46a758")
const WARN := Color("f5d90a")
const INFO := Color("5b9dff")

static var _theme_cache: Dictionary = {}
## Mirrors SettingsService.text_scale. Kept as a static mirror so this UI module
## never touches autoloads from a static context.
static var text_scale: float = 1.0


static func set_text_scale(value: float) -> void:
	if is_equal_approx(value, text_scale):
		return
	text_scale = value
	_theme_cache.clear()


static func theme() -> Theme:
	return theme_for_scale(text_scale)


static func theme_for_scale(scale: float) -> Theme:
	var key: String = str(scale)
	if _theme_cache.has(key):
		return _theme_cache[key]
	var built: Theme = _build_theme(scale)
	_theme_cache[key] = built
	return built


static func invalidate_theme_cache() -> void:
	_theme_cache.clear()


static func _build_theme(scale: float) -> Theme:
	var t := Theme.new()
	var base_size: int = int(round(20.0 * scale))
	t.default_font_size = base_size

	t.set_color("font_color", "Label", TEXT)

	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_pressed_color", "Button", Color("11151d"))
	t.set_color("font_focus_color", "Button", Color("ffffff"))
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", base_size)
	t.set_stylebox("normal", "Button", _button_box(PANEL_ALT, OUTLINE))
	t.set_stylebox("hover", "Button", _button_box(Color("263043"), ACCENT))
	t.set_stylebox("pressed", "Button", _button_box(ACCENT, ACCENT))
	t.set_stylebox("focus", "Button", _focus_box())
	t.set_stylebox("disabled", "Button", _button_box(Color("141922"), Color("202634")))

	t.set_stylebox("panel", "PanelContainer", _button_box(PANEL, OUTLINE))
	t.set_stylebox("panel", "Panel", _button_box(PANEL, OUTLINE))

	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_font_size("font_size", "LineEdit", base_size)
	t.set_stylebox("normal", "LineEdit", _button_box(Color("10141d"), OUTLINE))
	t.set_stylebox("focus", "LineEdit", _focus_box())

	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckBox", base_size)
	t.set_font_size("font_size", "CheckButton", base_size)

	t.set_stylebox("panel", "PopupMenu", _button_box(PANEL, OUTLINE))
	t.set_font_size("font_size", "PopupMenu", base_size)
	t.set_color("font_color", "PopupMenu", TEXT)

	t.set_stylebox("background", "ProgressBar", _button_box(Color("0e121a"), OUTLINE))
	t.set_stylebox("fill", "ProgressBar", _button_box(ACCENT, ACCENT))
	t.set_font_size("font_size", "ProgressBar", int(base_size * 0.8))

	t.set_stylebox("scroll", "VScrollBar", _button_box(Color("10141d"), Color("10141d")))
	t.set_stylebox("grabber", "VScrollBar", _button_box(Color("39455c"), Color("39455c")))
	t.set_stylebox("grabber_highlight", "VScrollBar", _button_box(ACCENT, ACCENT))
	t.set_stylebox("grabber_pressed", "VScrollBar", _button_box(ACCENT, ACCENT))

	return t


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = ACCENT
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.draw_center = false
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


# --- Layout helpers --------------------------------------------------------

static func screen_root(script_host: Control) -> VBoxContainer:
	script_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	script_host.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	script_host.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	return column


static func header(column: VBoxContainer, title_text: String, subtitle_text: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := label(title_text, 1.6, TEXT)
	box.add_child(title)
	if not subtitle_text.is_empty():
		box.add_child(label(subtitle_text, 0.95, MUTED))
	column.add_child(box)
	var rule := ColorRect.new()
	rule.color = OUTLINE
	rule.custom_minimum_size = Vector2(0, 2)
	column.add_child(rule)
	return box


static func label(text: String, size_scale: float = 1.0, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not is_equal_approx(size_scale, 1.0):
		var base: int = int(round(20.0 * _text_scale()))
		node.add_theme_font_size_override("font_size", maxi(10, int(round(base * size_scale))))
	return node


static func _text_scale() -> float:
	return text_scale


static func button(text: String, callback: Callable, min_width: int = 320, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, 0)
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.focus_mode = Control.FOCUS_ALL
	if primary:
		node.add_theme_color_override("font_color", ACCENT)
	node.pressed.connect(callback)
	return node


static func tiny_button(text: String, callback: Callable, min_width: int = 0) -> Button:
	var node := button(text, callback, min_width)
	node.add_theme_font_size_override("font_size", int(round(16.0 * _text_scale())))
	node.custom_minimum_size = Vector2(min_width, 40)
	return node


static func panel(fill: Color = PANEL, border: Color = OUTLINE) -> PanelContainer:
	var node := PanelContainer.new()
	var box := _button_box(fill, border)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	node.add_theme_stylebox_override("panel", box)
	return node


static func vbox(spacing: int = 10) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", spacing)
	return node


static func hbox(spacing: int = 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", spacing)
	return node


static func spacer(height: float = 12.0) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


static func expander() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func divider() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = OUTLINE
	rect.custom_minimum_size = Vector2(0, 1)
	return rect


static func key_value_row(key_text: String, value_text: String) -> HBoxContainer:
	var row := hbox(12)
	var key_label := label(key_text, 0.95, MUTED)
	key_label.custom_minimum_size = Vector2(280, 0)
	row.add_child(key_label)
	row.add_child(label(value_text, 0.95, TEXT))
	return row


static func status_color(status: int) -> Color:
	match status:
		6:
			return OK
		5:
			return Color("7dd3a0")
		4:
			return INFO
		3:
			return WARN
		2:
			return Color("c9a227")
		1:
			return MUTED
		_:
			return Color("6b7280")


static func tag(text: String, color: Color) -> PanelContainer:
	var node := PanelContainer.new()
	var box := _button_box(Color(color.r, color.g, color.b, 0.16), color)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.set_corner_radius_all(6)
	node.add_theme_stylebox_override("panel", box)
	node.add_child(label(text, 0.75, color))
	return node


static func focus_first(root: Node) -> void:
	var found: Control = _find_focusable(root)
	if found != null:
		found.grab_focus()


static func _find_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Button and (child as Button).visible and not (child as Button).disabled:
			return child as Button
		var nested: Control = _find_focusable(child)
		if nested != null:
			return nested
	return null


static func fill_background(host: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	return bg
