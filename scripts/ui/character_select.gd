extends Control
## Character select — built for a 600+ roster.
##
## Only the current page is instantiated (48 cards), portraits are never loaded
## in bulk and no animation is loaded at all, so a large roster stays cheap.
## Characters whose status is not PLAYABLE are visible but locked.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Consts = preload("res://scripts/core/constants.gd")

const PAGE_SIZE: int = 48

var _purpose: String = "browse"
var _slot: int = 1
var _search: String = ""
var _element: String = ""
var _role: String = ""
var _rarity: String = ""
var _only_playable: bool = false
var _page: int = 0
var _results: Array = []

var _grid: GridContainer
var _page_label: Label
var _count_label: Label
var _empty_label: Label
var _scroll: ScrollContainer
var _search_edit: LineEdit
var _element_option: OptionButton
var _element_values: PackedStringArray = PackedStringArray()
var _role_option: OptionButton
var _rarity_option: OptionButton


func _ready() -> void:
	var payload: Dictionary = SceneRouter.payload()
	_purpose = str(payload.get("purpose", "browse"))
	_slot = int(payload.get("slot", 1))
	theme = UIKit.theme()
	_build()
	refresh()
	UIKit.focus_first(self)


func _build() -> void:
	var column := UIKit.screen_root(self)
	UIKit.header(column, Loc.t("chars.title"), Loc.t("chars.subtitle", [str(Consts.MAX_CHARACTERS)]))

	var filters := UIKit.hbox(12)
	column.add_child(filters)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = Loc.t("chars.search_placeholder")
	_search_edit.custom_minimum_size = Vector2(420, 44)
	_search_edit.text_changed.connect(_on_search_changed)
	filters.add_child(_search_edit)

	_element_values = GameData.element_list
	_element_option = _filter_option(Loc.t("chars.filter_element"), _element_values, _on_element_changed)
	filters.add_child(_element_option)
	_role_option = _filter_option(Loc.t("chars.filter_role"), GameData.role_list, _on_role_changed)
	filters.add_child(_role_option)
	_rarity_option = _filter_option(Loc.t("chars.filter_rarity"), GameData.rarity_list, _on_rarity_changed)
	filters.add_child(_rarity_option)

	var playable_toggle := CheckButton.new()
	playable_toggle.text = Loc.t("chars.only_playable")
	playable_toggle.toggled.connect(_on_playable_toggled)
	filters.add_child(playable_toggle)

	var lab_row := UIKit.hbox(10)
	column.add_child(lab_row)
	lab_row.add_child(UIKit.label("TEMPORARY LAB ENTITIES", 0.8, UIKit.WARN))
	var lab_entries: Array = [
		["lab_dummy_a", "LAB DUMMY A"],
		["lab_dummy_b", "LAB DUMMY B"],
		["001_naruto", "NARUTO UZUMAKI"],
		["002_sasuke", "SASUKE UCHIHA"],
		["003_sakura", "SAKURA HARUNO"],
	]
	for pair in lab_entries:
		var key: String = str(pair[0])
		var label: String = str(pair[1])
		lab_row.add_child(UIKit.tiny_button("%s [%s]" % [label, Loc.t("common.temporary")],
			func() -> void: _choose(_lab_entry(key, label)), 240))

	_count_label = UIKit.label("", 0.8, UIKit.MUTED)
	column.add_child(_count_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var content := UIKit.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_empty_label = UIKit.label("", 0.9, UIKit.MUTED)
	content.add_child(_empty_label)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_grid)

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	footer.add_child(UIKit.tiny_button("◀", _prev_page, 80))
	footer.add_child(UIKit.tiny_button("▶", _next_page, 80))
	_page_label = UIKit.label("", 0.85, UIKit.MUTED)
	footer.add_child(_page_label)
	footer.add_child(UIKit.expander())
	footer.add_child(UIKit.label(Loc.t("chars.capacity", [str(Consts.MAX_CHARACTERS)]), 0.75, UIKit.MUTED))
	footer.add_child(UIKit.button(Loc.t("common.back"), _go_back, 220))


func _filter_option(title: String, values: PackedStringArray, callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.add_item("%s: %s" % [title, Loc.t("common.all")], 0)
	for index in range(values.size()):
		option.add_item(str(values[index]), index + 1)
	option.item_selected.connect(callback)
	return option


func _on_search_changed(text: String) -> void:
	_search = text
	_page = 0
	refresh()


func _on_element_changed(index: int) -> void:
	_element = "" if index == 0 else str(_element_values[index - 1])
	_page = 0
	refresh()


func _on_role_changed(index: int) -> void:
	_role = "" if index == 0 else str(GameData.role_list[index - 1])
	_page = 0
	refresh()


func _on_rarity_changed(index: int) -> void:
	_rarity = "" if index == 0 else str(GameData.rarity_list[index - 1])
	_page = 0
	refresh()


func _on_playable_toggled(value: bool) -> void:
	_only_playable = value
	_page = 0
	refresh()


func refresh() -> void:
	_results = GameData.query(_search, _element, _role, _rarity, _only_playable)
	var pages: int = maxi(1, int(ceil(float(_results.size()) / float(PAGE_SIZE))))
	_page = clampi(_page, 0, pages - 1)

	for child in _grid.get_children():
		child.queue_free()

	if _results.is_empty():
		_grid.visible = false
		_empty_label.visible = true
		if GameData.characters.is_empty():
			_empty_label.text = "%s\n\n%s" % [Loc.t("chars.empty_title"), Loc.t("chars.empty_body")]
		else:
			_empty_label.text = Loc.t("chars.empty_filter")
	else:
		_grid.visible = true
		_empty_label.visible = false
		var start: int = _page * PAGE_SIZE
		var end: int = mini(start + PAGE_SIZE, _results.size())
		for index in range(start, end):
			_grid.add_child(_card(_results[index]))

	_count_label.text = Loc.t("chars.results", [str(_results.size())])
	_page_label.text = Loc.t("common.page", [str(_page + 1), str(pages)])
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _card(record: Dictionary) -> PanelContainer:
	var selectable: bool = GameData.is_selectable(record)
	var panel := UIKit.panel(UIKit.PANEL_ALT if selectable else Color("12161f"),
		UIKit.status_color(int(record.get("status", 0))))
	panel.custom_minimum_size = Vector2(420, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIKit.vbox(4)
	panel.add_child(column)

	# Placeholder portrait block. Real portraits are loaded lazily per page once
	# approved art exists; nothing is generated or faked here.
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(0, 56)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = UIKit.status_color(int(record.get("status", 0))).darkened(0.65)
	portrait_style.set_corner_radius_all(8)
	portrait.add_theme_stylebox_override("panel", portrait_style)
	portrait.add_child(UIKit.label("PORTRAIT PENDING", 0.7, UIKit.MUTED))
	column.add_child(portrait)

	var name_label := UIKit.label(str(record.get("name", "?")), 1.05, UIKit.TEXT)
	column.add_child(name_label)
	column.add_child(UIKit.label(str(record.get("series", "")), 0.78, UIKit.MUTED))

	var tags := UIKit.hbox(6)
	column.add_child(tags)
	tags.add_child(UIKit.tag(str(record.get("element", Consts.UNKNOWN_LABEL)), UIKit.INFO))
	tags.add_child(UIKit.tag(str(record.get("role", Consts.UNKNOWN_LABEL)), UIKit.MUTED))
	tags.add_child(UIKit.tag(str(record.get("rarity", Consts.UNKNOWN_LABEL)), UIKit.ACCENT))

	var status_row := UIKit.hbox(8)
	column.add_child(status_row)
	status_row.add_child(UIKit.tag(str(record.get("status_name", "DATA_ONLY")),
		UIKit.status_color(int(record.get("status", 0)))))
	if not selectable:
		status_row.add_child(UIKit.label(Loc.t("common.locked"), 0.72, UIKit.DANGER))

	column.add_child(UIKit.expander())
	var actions := UIKit.hbox(8)
	column.add_child(actions)
	actions.add_child(UIKit.tiny_button(Loc.t("chars.open_detail"),
		func() -> void: _open_detail(int(record.get("id", -1))), 160))
	var select_button := UIKit.tiny_button(Loc.t("chars.select"),
		func() -> void: _choose(Session.character_entry(record)), 160)
	select_button.disabled = not selectable
	if not selectable:
		select_button.tooltip_text = Loc.t("chars.locked_hint")
	actions.add_child(select_button)
	return panel


func _lab_entry(key: String, label: String) -> Dictionary:
	var entry: Dictionary = Session.lab_entry(key, label)
	return entry


func _choose(entry: Dictionary) -> void:
	if _purpose == "slot":
		Session.set_slot(_slot, entry)
		SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")
		return
	Session.p1 = entry
	if Session.p2.is_empty():
		Session.p2 = Session.lab_entry("lab_dummy_b", "LAB DUMMY B")
	Session.stage_id = "lab_arena" if Session.stage_id.is_empty() else Session.stage_id
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")


func _open_detail(character_id: int) -> void:
	if character_id < 0:
		return
	SceneRouter.change_scene("res://scenes/menus/character_detail.tscn", {"id": character_id})


func _prev_page() -> void:
	_page = maxi(0, _page - 1)
	refresh()


func _next_page() -> void:
	_page += 1
	refresh()


func _go_back() -> void:
	if _purpose == "slot":
		SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")
	else:
		SceneRouter.change_scene(SceneRouter.MAIN_MENU)
