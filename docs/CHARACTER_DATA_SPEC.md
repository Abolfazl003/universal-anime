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

### Field aliases (for the dataset that was actually supplied)

The supplied file does not use the names this project picked. It is **never
edited**: the loader resolves the synonyms below and copies the values verbatim.

| Supplied field | Read as | Handling |
|---|---|---|
| `anime` | `series` | search + filters + "distinct series" count |
| `signature.name` / `signature.description` | `powers[0]` | the whole string is kept as-is, including `"Rasengan / Kurama Chakra Mode"` |
| `signature.ultimate` | `ultimate` | exposed separately, never merged into the power name |
| `stats{hp,atk,def,spd,tech,build,power_level}` | `stats` | kept as a dictionary; gameplay will read it once movesets exist |
| `world`, `architecture`, `element_family`, `brick_cost`, `city_pieces`, `unlock_level` | same names | preserved and shown; `brick_cost` / `city_pieces` are unused by this game and are not evidence of any building-block mode |

`status` is absent in the supplied file, so **every record normalises to
`DATA_ONLY`**. That is the pipeline's entry state, not invented character data.

Unknown fields are preserved untouched in `record.raw`, so nothing from the
source is lost.

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

Measured on the supplied dataset on 2026-11-07 (headless, real engine):

| Metric | Value |
|---|---|
| Source file | `data/characters.local.json` (git-ignored, byte-identical to the upload, md5 `d0ece50b707dbd982984293a8f1017eb`) |
| Records | **500** |
| Valid / complete | **500** |
| Duplicate ids | **0** |
| Duplicate names | **0** |
| Distinct series | **90** |
| Distinct elements / roles | 130 / 16 |
| Rarity split | Legendary 195 · Epic 146 · Mythic 133 · Rare 26 |
| Status | `DATA_ONLY` × 500 |
| Playable | **0** |
| UI capacity | 600+ (paged at 48 cards/page) |
| Target | 600 — **100 short; nothing will be invented to close the gap** |

## Adding a character without touching the combat engine

1. Add the record (or wait for the source file).
2. Create `data/movesets/<id>_<name>.json` with `characterId` = the record id.
3. Add `resources/animations/<id>_<name>.json` with clip fps/frames once art exists.
4. Bind a stage in `data/stages/` when the environment is approved.

No file under `scripts/combat/` or `scripts/characters/` needs to change — those
files contain no character names.
