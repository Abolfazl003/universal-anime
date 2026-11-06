extends Control
## Settings: audio, display, accessibility. Everything is persisted through
## SettingsService → SaveManager. Safe defaults: shake and flash are off.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _overlay_mode: bool = false


func _ready() -> void:
	_overlay_mode = bool(SceneRouter.payload().get("overlay", false))
	if _overlay_mode:
		process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.theme()
	_build()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	if _overlay_mode:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.65)
		add_child(bg)
		move_child(bg, 0)
	UIKit.header(column, Loc.t("settings.title"), Loc.t("settings.safe_default"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := UIKit.vbox(16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_section(Loc.t("settings.audio")))
	content.add_child(_slider_row(Loc.t("settings.master"), "master_volume", 0.0, 1.0, 0.05))
	content.add_child(_slider_row(Loc.t("settings.music"), "music_volume", 0.0, 1.0, 0.05))
	content.add_child(_slider_row(Loc.t("settings.sfx"), "sfx_volume", 0.0, 1.0, 0.05))
	content.add_child(UIKit.label(Loc.t("settings.music_note"), 0.75, UIKit.MUTED))

	content.add_child(_section(Loc.t("settings.display")))
	content.add_child(_cycle_row(Loc.t("settings.window_mode"), str(SettingsService.get_value("window_mode")),
		func(delta: int) -> void: SettingsService.cycle_window_mode(delta)))
	content.add_child(_cycle_row(Loc.t("settings.resolution"), str(SettingsService.get_value("resolution")),
		func(delta: int) -> void: SettingsService.cycle_resolution(delta)))
	var language_row := UIKit.hbox(12)
	language_row.add_child(UIKit.label(Loc.t("settings.language"), 0.95, UIKit.MUTED))
	var languages: PackedStringArray = Loc.available_languages()
	var language_option := OptionButton.new()
	for index in range(languages.size()):
		language_option.add_item(str(languages[index]), index)
	language_option.selected = maxi(0, languages.find(Loc.language))
	language_option.item_selected.connect(func(index: int) -> void:
		Loc.set_language(str(languages[index]))
		_rebuild())
	language_row.add_child(language_option)
	content.add_child(language_row)

	content.add_child(_section(Loc.t("settings.accessibility")))
	content.add_child(_slider_row(Loc.t("settings.text_scale"), "text_scale", 0.8, 1.6, 0.05))
	content.add_child(_slider_row(Loc.t("settings.screen_shake"), "screen_shake", 0.0, 1.0, 0.05))
	content.add_child(_slider_row(Loc.t("settings.flash"), "flash_intensity", 0.0, 1.0, 0.05))
	var reduced := CheckButton.new()
	reduced.text = Loc.t("settings.reduced_motion")
	reduced.button_pressed = bool(SettingsService.get_value("reduced_motion"))
	reduced.toggled.connect(func(value: bool) -> void:
		SettingsService.set_value("reduced_motion", value))
	content.add_child(reduced)

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.button(Loc.t("settings.reset"), _reset, 300))
	footer.add_child(UIKit.expander())
	footer.add_child(UIKit.button(Loc.t("common.back"), _back, 220, true))
	UIKit.focus_first(self)


func _section(title: String) -> VBoxContainer:
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(title, 1.15, UIKit.ACCENT))
	box.add_child(UIKit.divider())
	return box


func _slider_row(title: String, key: String, minimum: float, maximum: float, step: float) -> HBoxContainer:
	var row := UIKit.hbox(14)
	var label := UIKit.label(title, 0.95, UIKit.MUTED)
	label.custom_minimum_size = Vector2(300, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(420, 32)
	slider.value = float(SettingsService.get_value(key))
	row.add_child(slider)
	var value_label := UIKit.label(_format_value(key, slider.value), 0.9, UIKit.TEXT)
	value_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		SettingsService.set_value(key, value)
		value_label.text = _format_value(key, value)
		if key == "text_scale":
			UIKit.invalidate_theme_cache()
			theme = UIKit.theme()
			_rebuild())
	return row


func _format_value(key: String, value: float) -> String:
	if key == "text_scale":
		return "%.0f%%" % (value * 100.0)
	return "%d%%" % int(round(value * 100.0))


func _cycle_row(title: String, value: String, callback: Callable) -> HBoxContainer:
	var row := UIKit.hbox(12)
	var label := UIKit.label(title, 0.95, UIKit.MUTED)
	label.custom_minimum_size = Vector2(300, 0)
	row.add_child(label)
	row.add_child(UIKit.tiny_button("−", callback.bind(-1), 60))
	row.add_child(UIKit.label(value, 0.95, UIKit.TEXT))
	row.add_child(UIKit.tiny_button("+", callback.bind(1), 60))
	return row


func _reset() -> void:
	SettingsService.reset_to_defaults()
	UIKit.invalidate_theme_cache()
	_rebuild()


func _back() -> void:
	if _overlay_mode:
		SceneRouter.close_overlay()
		return
	SceneRouter.go_back()
