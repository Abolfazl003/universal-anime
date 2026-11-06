extends Control
## Results screen for both modes. Data comes from the payload written by the
## match / dungeon controller and was already persisted by SaveManager.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var _payload: Dictionary = {}


func _ready() -> void:
	theme = UIKit.theme()
	_payload = SceneRouter.payload()
	_build()
	UIKit.focus_first(self)


func _build() -> void:
	var column := UIKit.screen_root(self)
	var mode: String = str(_payload.get("mode", "versus"))
	var is_dungeon: bool = mode == "dungeon"
	UIKit.header(column, Loc.t("results.title"),
		Loc.t("results.dungeon_win") if is_dungeon else _versus_subtitle())

	var panel := UIKit.panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var body := UIKit.vbox(10)
	panel.add_child(body)

	if is_dungeon:
		var won: bool = bool(_payload.get("won", false))
		body.add_child(UIKit.label(Loc.t("results.dungeon_win") if won else Loc.t("results.dungeon_lose"),
			2.0, UIKit.OK if won else UIKit.DANGER))
		body.add_child(UIKit.key_value_row(Loc.t("results.floor"), str(_payload.get("floor", 0))))
		body.add_child(UIKit.key_value_row(Loc.t("results.seed"), str(_payload.get("seed", 0))))
		body.add_child(UIKit.key_value_row("Loot", str(_payload.get("loot", 0))))
	else:
		var winner: int = int(_payload.get("winner", -1))
		var winner_name: String = Loc.t("match.draw")
		if winner == 0:
			winner_name = str(_payload.get("p1", "P1"))
		elif winner == 1:
			winner_name = str(_payload.get("p2", "P2"))
		body.add_child(UIKit.label(Loc.t("results.winner"), 0.95, UIKit.MUTED))
		body.add_child(UIKit.label(winner_name, 2.0, UIKit.ACCENT))
		var wins: Array = _payload.get("wins", [0, 0])
		body.add_child(UIKit.key_value_row(Loc.t("results.rounds"), "%s — %s" % [
			str(wins[0] if wins.size() > 0 else 0), str(wins[1] if wins.size() > 1 else 0)
		]))
		body.add_child(UIKit.key_value_row("P1", str(_payload.get("p1", ""))))
		body.add_child(UIKit.key_value_row("P2", str(_payload.get("p2", ""))))
		if bool(_payload.get("temporary", false)):
			body.add_child(UIKit.tag(Loc.t("results.temporary_note"), UIKit.WARN))
	body.add_child(UIKit.expander())
	body.add_child(UIKit.label(str(SaveManager.last_load_status), 0.7, UIKit.MUTED))

	var footer := UIKit.hbox(12)
	column.add_child(footer)
	if is_dungeon:
		footer.add_child(UIKit.button(Loc.t("dungeon.restart"), _restart_dungeon, 300, true))
	else:
		footer.add_child(UIKit.button(Loc.t("results.rematch"), _rematch, 300, true))
		footer.add_child(UIKit.button(Loc.t("results.change"), _change_fighters, 300))
	footer.add_child(UIKit.expander())
	footer.add_child(UIKit.button(Loc.t("results.menu"), func() -> void: SceneRouter.change_scene(SceneRouter.MAIN_MENU), 260))


func _versus_subtitle() -> String:
	var wins: Array = _payload.get("wins", [0, 0])
	return "%s — %s" % [str(_payload.get("p1", "")), str(_payload.get("p2", ""))] if wins.is_empty() else \
		"%s vs %s · %s—%s" % [str(_payload.get("p1", "")), str(_payload.get("p2", "")),
			str(wins[0] if wins.size() > 0 else 0), str(wins[1] if wins.size() > 1 else 0)]


func _rematch() -> void:
	SceneRouter.change_scene("res://scenes/versus/versus_stage.tscn")


func _change_fighters() -> void:
	SceneRouter.change_scene("res://scenes/menus/versus_setup.tscn")


func _restart_dungeon() -> void:
	Session.dungeon_seed = int(Time.get_unix_time_from_system()) % 100000
	SceneRouter.change_scene("res://scenes/dungeon/dungeon_run.tscn", {"seed": Session.dungeon_seed})
