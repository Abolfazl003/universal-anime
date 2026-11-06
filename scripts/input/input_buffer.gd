extends RefCounted
## Per-fighter input buffer.
##
## Ticks are simulation ticks (1/60 s), never rendered frames, so buffering
## behaves identically at 30, 60 or 144 Hz. Buffered inputs expire after
## `window_ticks`; useful for buffering an attack pressed slightly before a
## recovery ends.

const DEFAULT_WINDOW_TICKS: int = 8

var window_ticks: int = DEFAULT_WINDOW_TICKS
var _entries: Array[Dictionary] = []
var _tick: int = 0


func advance() -> void:
	_tick += 1
	var alive: Array[Dictionary] = []
	for entry in _entries:
		if _tick - int(entry["tick"]) <= window_ticks:
			alive.append(entry)
	_entries = alive


func push(action: String) -> void:
	# Collapse duplicates so holding a key cannot spam the buffer.
	if not _entries.is_empty() and _entries[-1]["action"] == action:
		return
	_entries.append({"action": action, "tick": _tick})


func has(action: String) -> bool:
	for entry in _entries:
		if entry["action"] == action and _tick - int(entry["tick"]) <= window_ticks:
			return true
	return false


func consume(action: String) -> bool:
	if not has(action):
		return false
	var remaining: Array[Dictionary] = []
	for entry in _entries:
		if entry["action"] == action:
			continue
		remaining.append(entry)
	_entries = remaining
	return true


## Returns the most recently buffered action, or "" when the buffer is empty.
func latest() -> String:
	if _entries.is_empty():
		return ""
	return str(_entries[-1]["action"])


func clear() -> void:
	_entries.clear()


func size() -> int:
	return _entries.size()


func tick() -> int:
	return _tick
