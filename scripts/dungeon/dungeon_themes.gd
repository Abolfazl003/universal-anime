extends RefCounted
## Dungeon theme table.
##
## A run picks one theme from its seed, so the same seed always looks the same and
## a run is reproducible end to end (layout, enemies, palette). When a character is
## already selected, its world is used as a hint so a Sand Village run feels sandy.
##
## This is art direction for rooms, not character art: no reference approval is
## involved and nothing here is copyrighted material.

const PATH: String = "res://data/dungeon/themes.json"
const FALLBACK_ID: String = "stone_halls"
const REQUIRED_PALETTE_KEYS: PackedStringArray = ["wall", "floor", "accent", "hazard"]

static var _cache: Array = []


static func load_themes() -> Array:
	if not _cache.is_empty():
		return _cache
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("DungeonThemes: cannot open %s" % PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DungeonThemes: %s is not an object." % PATH)
		return []
	var themes: Variant = (parsed as Dictionary).get("themes", [])
	if typeof(themes) != TYPE_ARRAY:
		return []
	var out: Array = []
	for entry in (themes as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("id", "")).is_empty():
			continue
		out.append(entry)
	_cache = out
	return _cache


static func get_theme(theme_id: String) -> Dictionary:
	for theme in load_themes():
		if str((theme as Dictionary).get("id", "")) == theme_id:
			return theme
	return {}


static func fallback() -> Dictionary:
	var theme: Dictionary = get_theme(FALLBACK_ID)
	if theme.is_empty() and not load_themes().is_empty():
		return load_themes()[0]
	return theme


## Deterministic: same seed, same theme, on every platform.
static func pick(seed_value: int, world_hint: String = "") -> Dictionary:
	var themes: Array = load_themes()
	if themes.is_empty():
		return {}
	var hinted: Dictionary = _match_world(themes, world_hint)
	if not hinted.is_empty():
		return hinted
	var index: int = absi((seed_value * 2654435761) % themes.size())
	return themes[index]


static func _match_world(themes: Array, world_hint: String) -> Dictionary:
	var haystack: String = world_hint.strip_edges().to_lower()
	if haystack.is_empty():
		return {}
	for theme in themes:
		for keyword in ((theme as Dictionary).get("keywords", []) as Array):
			if haystack.contains(str(keyword).to_lower()):
				return theme
	return {}


static func color_of(theme: Dictionary, key: String, default_hex: String) -> Color:
	var palette: Dictionary = theme.get("palette", {})
	return Color(str(palette.get(key, default_hex)))


static func is_valid(theme: Dictionary) -> bool:
	if str(theme.get("id", "")).is_empty():
		return false
	var palette: Dictionary = theme.get("palette", {})
	for key in REQUIRED_PALETTE_KEYS:
		if not palette.has(key):
			return false
	return true
