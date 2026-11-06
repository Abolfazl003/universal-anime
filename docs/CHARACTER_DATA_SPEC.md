# Character data specification

`data/characters.json` is the **source of truth**. The game never edits, renames
or completes it.

## Import

1. Put the authoritative file at `data/characters.json`.
   *Alternative:* `data/characters.local.json` (git-ignored) takes precedence, so
   a private dataset never has to be committed.
2. Either shape is accepted:

```json
[ { "id": 1, "name": "…" } ]
```
```json
{ "schemaVersion": 1, "characters": [ { "id": 1, "name": "…" } ] }
```

3. Reload the game. `Boot → Data report` shows the real numbers.

## Record fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | integer, unique. Duplicates are reported as errors. |
| `name` | yes | canonical, **never translated** by the game |
| `series` | yes | used by search + filters |
| `city` | yes | used by search |
| `element`, `role`, `rarity` | yes | filter values read from the data, nothing hard-coded |
| `powers` | yes | array of `{name, description}` (bare strings are also accepted; the game keeps the name and leaves the description empty) |
| `world`, `architecture`, `description`, `status`, `form`, `portrait`, `tags` | optional | absent fields stay empty; the UI prints "unknown" |

Missing fields are **reported**, never invented. If a record lacks a required
field it is counted as incomplete by the validator and stays unplayable.

## Status pipeline

```
DATA_ONLY → REFERENCE_PENDING → REFERENCE_APPROVED → ANIMATION_IN_PROGRESS
          → IMPLEMENTED → QA_PASSED → PLAYABLE
```

* Records without a `status` value are treated as `DATA_ONLY`.
* Only `PLAYABLE` records can be selected for a match (the button is disabled and
  a lock hint is shown otherwise).
* `PLAYABLE` additionally requires a bound moveset and all required animation
  clips with real frames — enforced by `AnimationDB.missing_animations()` and the
  QA gates in the test suite.

## Supplemental information

Anything the source file does not contain goes to `data/character_extensions/`
(one JSON file per character, with `source`, `retrieved`, `notes`), never back
into `characters.json`. See `data/character_extensions/_example.json`.

## Current verified counts

| Metric | Value |
|---|---|
| Records in repository | 0 (file missing — see `docs/00_PHASE0_AUDIT.md`) |
| Playable | 0 |
| UI capacity | 600+ (paged at 48 cards/page) |
| Target | 600, reachable only with valid remaining data |

## Adding a character without touching the combat engine

1. Add the record (or wait for the source file).
2. Create `data/movesets/<id>_<name>.json` with `characterId` = the record id.
3. Add `resources/animations/<id>_<name>.json` with clip fps/frames once art exists.
4. Bind a stage in `data/stages/` when the environment is approved.

No file under `scripts/combat/` or `scripts/characters/` needs to change — those
files contain no character names.
