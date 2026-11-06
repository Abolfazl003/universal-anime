extends Node
## SessionState — the data carried between menus and a match.
## Menus write it, gameplay reads it. No scene reads globals directly.

const Consts = preload("res://scripts/core/constants.gd")

signal config_changed()

## Fighter slots. A slot is either a data-driven character (id + moveset) or a
## clearly-labelled temporary lab dummy used by the mechanics lab.
var p1: Dictionary = {}
var p2: Dictionary = {}
var mode: int = Consts.Mode.NONE
var stage_id: String = ""
var rounds_to_win: int = 2
var round_time: float = Consts.ROUND_TIME_DEFAULT
var timer_enabled: bool = true
var p1_control: int = Consts.PlayerControl.HUMAN
var p2_control: int = Consts.PlayerControl.AI
var ai_difficulty: int = 1
var dungeon_seed: int = 0
var dungeon_length: int = 4


func _ready() -> void:
	reset()


func reset() -> void:
	p1 = {}
	p2 = {}
	mode = Consts.Mode.NONE
	stage_id = ""
	rounds_to_win = 2
	round_time = Consts.ROUND_TIME_DEFAULT
	timer_enabled = true
	p1_control = Consts.PlayerControl.HUMAN
	p2_control = Consts.PlayerControl.AI
	ai_difficulty = 1
	dungeon_seed = 0
	dungeon_length = 4
	config_changed.emit()


func set_slot(slot: int, entry: Dictionary) -> void:
	if slot == 1:
		p1 = entry
	else:
		p2 = entry
	config_changed.emit()


func get_slot(slot: int) -> Dictionary:
	return p1 if slot == 1 else p2


## Convenience: build a lab dummy entry.
static func lab_entry(moveset_id: String, label: String) -> Dictionary:
	return {
		"kind": "lab",
		"id": 0,
		"name": label,
		"moveset": moveset_id,
		"temporary": true,
	}


static func character_entry(character: Dictionary) -> Dictionary:
	return {
		"kind": "character",
		"id": int(character.get("id", -1)),
		"name": str(character.get("name", "")),
		"moveset": "",
		"temporary": false,
	}


func describe_versus() -> String:
	var a: String = str(p1.get("name", "-"))
	var b: String = str(p2.get("name", "-"))
	return "%s vs %s" % [a, b]


func is_versus_ready() -> bool:
	return not p1.is_empty() and not p2.is_empty()
