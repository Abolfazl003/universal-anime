extends Control
## Controls screen: shows keyboard + gamepad binding labels and allows rebinding.
## Rebinding only replaces the keyboard binding; gamepad bindings are kept.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _awaiting_player: int = -1
var _awaiting_action: String = ""
var _awaiting_global: bool = false
var _hint: Label


func _ready() -> void:
	# Also used as a pause overlay, where the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.theme()
	_build()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("controls.title"), Loc.t("controls.subtitle"))

	_hint = UIKit.label("", 0.9, UIKit.WARN)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := UIKit.hbox(24)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_action_column(Loc.t("controls.p1"), 0, false))
	content.add_child(_action_column(Loc.t("controls.p2"), 1, false))
	content.add_child(_action_column(Loc.t("controls.global"), 0, true))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.label("%s: %s" % [Loc.t("controls.device"),
		Loc.t("controls.gamepad") if InputService.gamepad_count() > 0 else Loc.t("controls.keyboard")], 0.85, UIKit.MUTED))
	footer.add_child(UIKit.expander())
	footer.add_child(_hint)
	footer.add_child(UIKit.button(Loc.t("controls.reset"), _reset, 260))
	footer.add_child(UIKit.button(Loc.t("common.back"), func() -> void: SceneRouter.go_back(), 220, true))
	footer.add_child(UIKit.label(Loc.t("controls.menu_note"), 0.7, UIKit.MUTED))
	UIKit.focus_first(self)


func _action_column(title: String, player_index: int, global_actions: bool) -> PanelContainer:
	var panel := UIKit.panel()
	panel.custom_minimum_size = Vector2(520, 0)
	var column := UIKit.vbox(6)
	panel.add_child(column)
	column.add_child(UIKit.label(title, 1.15, UIKit.ACCENT))
	column.add_child(UIKit.divider())
	var actions: PackedStringArray = InputService.GLOBAL_ACTIONS if global_actions else InputService.ACTIONS
	for action in actions:
		var row := UIKit.hbox(8)
		column.add_child(row)
		var key: String = str(InputService.ACTION_LABEL_KEYS.get(action, action))
		var label := UIKit.label(Loc.t(key), 0.9, UIKit.MUTED)
		label.custom_minimum_size = Vector2(240, 0)
		row.add_child(label)
		var binding: String = InputService.binding_label_for_action(action) if global_actions \
			else InputService.binding_label(player_index, action)
		var binding_label := UIKit.label(binding if not binding.is_empty() else "-", 0.9, UIKit.TEXT)
		binding_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(binding_label)
		var action_name: String = action if global_actions else InputService.action_name(player_index, action)
		row.add_child(UIKit.tiny_button(Loc.t("controls.rebind"),
			func() -> void: _begin_rebind(player_index, action, global_actions, action_name), 150))
	return panel


func _begin_rebind(player_index: int, action: String, global_action: bool, action_name: String) -> void:
	_awaiting_player = player_index
	_awaiting_action = action_name
	_awaiting_global = global_action
	if _hint != null:
		_hint.text = "%s — %s" % [Loc.t("controls.press_key"), action]


func _input(event: InputEvent) -> void:
	if _awaiting_action.is_empty():
		return
	if not (event is InputEventKey) or not event.is_pressed() or (event as InputEventKey).echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE:
		_awaiting_action = ""
		_hint.text = ""
		get_viewport().set_input_as_handled()
		return
	InputService.rebind_action_key(_awaiting_action, key_event.physical_keycode)
	_awaiting_action = ""
	_rebuild()
	get_viewport().set_input_as_handled()


func _reset() -> void:
	InputService.reset_defaults()
	_rebuild()
