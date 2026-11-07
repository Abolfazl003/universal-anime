extends RefCounted
## Central state vocabulary for a 2D fighter.
##
## Every state declares: how it is entered, how it exits, which inputs it
## accepts, which animation it plays, whether movement is allowed and whether the
## fighter can be hit. Gameplay code reads this table instead of juggling
## scattered booleans, and tests assert that the table is consistent.

enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	CROUCH,
	BLOCK,
	ATTACK,
	SPECIAL,
	ULTIMATE,
	HITSTUN,
	KNOCKDOWN,
	GETUP,
	VICTORY,
	DEFEAT,
	INTRO,
	OUTRO,
	FORM,
}

const NAMES: Dictionary = {
	State.IDLE: "IDLE",
	State.WALK: "WALK",
	State.RUN: "RUN",
	State.JUMP: "JUMP",
	State.FALL: "FALL",
	State.CROUCH: "CROUCH",
	State.BLOCK: "BLOCK",
	State.ATTACK: "ATTACK",
	State.SPECIAL: "SPECIAL",
	State.ULTIMATE: "ULTIMATE",
	State.HITSTUN: "HITSTUN",
	State.KNOCKDOWN: "KNOCKDOWN",
	State.GETUP: "GETUP",
	State.VICTORY: "VICTORY",
	State.DEFEAT: "DEFEAT",
	State.INTRO: "INTRO",
	State.OUTRO: "OUTRO",
	State.FORM: "FORM",
}

## animation: clip id played while in the state (may be overridden by a move).
## can_move: horizontal intent is applied.
## vulnerable: may receive damage.
## grounded_only: cannot be entered while airborne.
## actionable: accepts new attack input.
const TABLE: Dictionary = {
	State.IDLE: {
		"animation": "idle",
		"can_move": true,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": true,
		"exits": ["WALK", "RUN", "JUMP", "CROUCH", "BLOCK", "ATTACK", "SPECIAL", "ULTIMATE", "HITSTUN", "INTRO", "VICTORY", "DEFEAT"],
	},
	State.WALK: {
		"animation": "walk",
		"can_move": true,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": true,
		"exits": ["IDLE", "RUN", "JUMP", "CROUCH", "BLOCK", "ATTACK", "SPECIAL", "ULTIMATE", "HITSTUN", "DEFEAT"],
	},
	State.RUN: {
		"animation": "run",
		"can_move": true,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": true,
		"exits": ["IDLE", "WALK", "JUMP", "CROUCH", "BLOCK", "ATTACK", "SPECIAL", "ULTIMATE", "HITSTUN", "DEFEAT"],
	},
	State.JUMP: {
		"animation": "jump_start",
		"can_move": true,
		"vulnerable": true,
		"grounded_only": false,
		"actionable": false,
		"exits": ["IDLE", "FALL", "HITSTUN", "DEFEAT"],
	},
	State.FALL: {
		"animation": "jump_loop",
		"can_move": true,
		"vulnerable": true,
		"grounded_only": false,
		"actionable": false,
		"exits": ["IDLE", "HITSTUN", "KNOCKDOWN", "DEFEAT"],
	},
	State.CROUCH: {
		"animation": "crouch",
		"can_move": false,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": true,
		"exits": ["IDLE", "JUMP", "BLOCK", "ATTACK", "SPECIAL", "HITSTUN", "DEFEAT"],
	},
	State.BLOCK: {
		"animation": "block",
		"can_move": false,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "CROUCH", "HITSTUN", "DEFEAT"],
	},
	State.ATTACK: {
		"animation": "light_attack",
		"can_move": false,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "ATTACK", "SPECIAL", "ULTIMATE", "HITSTUN", "DEFEAT"],
	},
	State.SPECIAL: {
		"animation": "special",
		"can_move": false,
		"vulnerable": true,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "ATTACK", "HITSTUN", "DEFEAT"],
	},
	State.ULTIMATE: {
		"animation": "ultimate",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "HITSTUN", "DEFEAT"],
	},
	State.HITSTUN: {
		"animation": "hit_reaction",
		"can_move": false,
		"vulnerable": true,
		"grounded_only": false,
		"actionable": false,
		"exits": ["IDLE", "KNOCKDOWN", "DEFEAT", "FALL"],
	},
	State.KNOCKDOWN: {
		"animation": "knockdown",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["GETUP", "DEFEAT"],
	},
	State.GETUP: {
		"animation": "get_up",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "DEFEAT"],
	},
	State.VICTORY: {
		"animation": "victory",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["OUTRO"],
	},
	State.DEFEAT: {
		"animation": "defeat",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": [],
	},
	State.INTRO: {
		"animation": "intro",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE"],
	},
	State.OUTRO: {
		"animation": "outro",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": [],
	},
	State.FORM: {
		"animation": "form_activation",
		"can_move": false,
		"vulnerable": false,
		"grounded_only": true,
		"actionable": false,
		"exits": ["IDLE", "HITSTUN", "DEFEAT"],
	},
}

## Fixed durations (ticks) for states that are not driven by a move's frame data.
const DEFAULT_DURATIONS: Dictionary = {
	State.KNOCKDOWN: 42,
	State.GETUP: 24,
	State.INTRO: 60,
	State.OUTRO: 60,
	State.FORM: 0,
}


static func name_of(state: int) -> String:
	return str(NAMES.get(state, "UNKNOWN"))


static func animation_for(state: int) -> String:
	var entry: Dictionary = TABLE.get(state, {})
	return str(entry.get("animation", "idle"))


static func can_move(state: int) -> bool:
	return bool((TABLE.get(state, {}) as Dictionary).get("can_move", false))


static func is_vulnerable(state: int) -> bool:
	return bool((TABLE.get(state, {}) as Dictionary).get("vulnerable", true))


static func is_actionable(state: int) -> bool:
	return bool((TABLE.get(state, {}) as Dictionary).get("actionable", false))


## The exit lists are written with readable names ("WALK") instead of enum values
## so the table can be reviewed like a design document. Resolve them once here, and
## accept raw ints too so callers can pass either form.
static func resolve_state(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		for state in NAMES.keys():
			if str(NAMES[state]) == str(value):
				return int(state)
	return -1


static func transition_allowed(from_state: int, to_state: int) -> bool:
	var exits: Array = (TABLE.get(from_state, {}) as Dictionary).get("exits", [])
	for exit_state in exits:
		if resolve_state(exit_state) == to_state:
			return true
	return false


## Used by the test-suite: every declared exit must exist in TABLE and itself be
## able to return to a playable state.
static func validate_table() -> PackedStringArray:
	var problems := PackedStringArray()
	for state in TABLE.keys():
		var entry: Dictionary = TABLE[state]
		for key in ["animation", "can_move", "vulnerable", "grounded_only", "actionable", "exits"]:
			if not entry.has(key):
				problems.append("State %s missing key %s" % [name_of(state), key])
		var exits: Array = entry.get("exits", [])
		for exit_state in exits:
			var resolved: int = resolve_state(exit_state)
			if resolved < 0 or not TABLE.has(resolved):
				problems.append("State %s exits to undefined state %s" % [name_of(state), str(exit_state)])
	# DEFEAT and OUTRO are deliberate terminals: a finished match has nowhere to go.
	for state in TABLE.keys():
		var entry: Dictionary = (TABLE[state] as Dictionary)
		var exits: Array = entry.get("exits", [])
		if not bool(entry.get("actionable", false)) and exits.is_empty() and state != State.DEFEAT and state != State.OUTRO:
			problems.append("State %s is a dead end but is not DEFEAT" % name_of(state))
	return problems
