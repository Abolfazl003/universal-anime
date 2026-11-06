extends Node
## Global, immutable constants and enums for the whole game.
## Keep this file free of logic: it is the single vocabulary shared by
## data loaders, combat, UI and tests.

## Development status of a character. Only PLAYABLE may enter final matches.
## Declared in progression order (see docs/CHARACTER_DATA_SPEC.md).
enum Status {
	DATA_ONLY = 0,
	REFERENCE_PENDING = 1,
	REFERENCE_APPROVED = 2,
	ANIMATION_IN_PROGRESS = 3,
	IMPLEMENTED = 4,
	QA_PASSED = 5,
	PLAYABLE = 6,
}

const STATUS_NAMES: Dictionary = {
	Status.DATA_ONLY: "DATA_ONLY",
	Status.REFERENCE_PENDING: "REFERENCE_PENDING",
	Status.REFERENCE_APPROVED: "REFERENCE_APPROVED",
	Status.ANIMATION_IN_PROGRESS: "ANIMATION_IN_PROGRESS",
	Status.IMPLEMENTED: "IMPLEMENTED",
	Status.QA_PASSED: "QA_PASSED",
	Status.PLAYABLE: "PLAYABLE",
}

## Statuses that are allowed to be shown as selectable in the final roster.
const STATUS_SELECTABLE: int = Status.PLAYABLE

## Design target for roster capacity (UI must scale beyond this as well).
const MAX_CHARACTERS: int = 600

## Simulation rate. All frame data in data/*.json is expressed in these ticks,
## never in screen frames, so gameplay is independent of display refresh rate.
const TICK_RATE: int = 60

const SAVE_SCHEMA_VERSION: int = 3

enum Mode {
	NONE = 0,
	VERSUS = 1,
	DUNGEON = 2,
	LAB = 3,
}

enum PlayerControl {
	HUMAN = 0,
	AI = 1,
	DISABLED = 2,
}

## Facing direction as +1 / -1 for use in hitbox math.
const FACING_RIGHT: int = 1
const FACING_LEFT: int = -1

## Legal "elements" are read from data; these are fallbacks only for filters
## when a record does not declare an element.
const UNKNOWN_LABEL: String = "UNKNOWN"

const DATA_FILES: Dictionary = {
	"characters": "res://data/characters.json",
	"characters_local_override": "res://data/characters.local.json",
	"extensions_dir": "res://data/character_extensions",
	"movesets_dir": "res://data/movesets",
	"stages_dir": "res://data/stages",
	"localization_dir": "res://data/localization",
	"references": "res://data/references.json",
	"animations_dir": "res://resources/animations",
}

## Required top-level fields for every character record.
const CHARACTER_REQUIRED_FIELDS: PackedStringArray = [
	"id",
	"name",
	"series",
	"city",
	"element",
	"role",
	"rarity",
	"powers",
]

## Fields that may legitimately be absent in the source data. We never invent
## them: missing values stay null/empty and are reported by the validator.
const CHARACTER_OPTIONAL_FIELDS: PackedStringArray = [
	"world",
	"architecture",
	"description",
	"status",
	"form",
	"portrait",
	"tags",
]

const DEFAULT_HP: int = 100
const DEFAULT_SPECIAL_MAX: float = 100.0
const DEFAULT_ULTIMATE_MAX: float = 100.0
const ROUND_TIME_DEFAULT: float = 99.0
