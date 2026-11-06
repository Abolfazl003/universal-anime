# Phase 0 — Repository and environment audit

Executed on 2026-11-06 against branch `arena/c66d4db8-universal-anime`
(base commit `719bc6f`, "Initial commit").

## What the repository actually contained

| Item | Reality |
|---|---|
| Files in the repository | 1 (`README.md`, 18 bytes) |
| Previous Godot skeleton | **None.** No `project.godot`, no scenes, no scripts, no data. |
| `data/characters.json` | **Does not exist.** |
| Character records | **0 available in the repository.** The brief's "500 records / 90 series" could not be verified because the file is not here. |
| Godot version pinned by the repo | None. Chosen: **Godot 4.4.1** (GDScript, `gl_compatibility` renderer, 2D only). |

Because there was no skeleton, "review and fix the existing skeleton" reduced to
"there is nothing to fix"; the project was created from scratch. Nothing was
deleted, renamed or overwritten.

## Honest reporting of the two blockers

### Blocker 1 — character database missing
No record, id or power name was invented to fill the gap. `data/characters.json`
now exists as an explicit empty container whose `meta.status` states
`SOURCE_FILE_NOT_PRESENT_IN_REPOSITORY`. Meaning:

* the game reports **0 records / 0 playable** everywhere,
* Character Select renders an explicit "no data" state instead of fake heroes,
* capacity (600+) is implemented and proven with an in-memory test fixture,
* dropping the real file at `data/characters.json` (or the git-ignored
  `data/characters.local.json`) makes the roster appear without code changes.

### Blocker 2 — no reference image could be retrieved or viewed
The build environment could reach text pages (Narutopedia was opened and read)
but **image search returned no results** and binary downloads from image hosts
were not reachable. Consequence, stated plainly:

* **no reference image was visually inspected**,
* therefore **no design proposal, no reference sheet and no animation frame was
  produced** for Naruto,
* the Naruto design is **not approved and not locked**, and the animation
  pipeline is **blocked at step 1** until the user supplies reference images.

Text sources that were actually opened are listed with URLs in
`data/references.json` and in `docs/02_REFERENCE_NARUTO.md`.

## Engine / tooling facts

| Item | Value |
|---|---|
| Engine used for validation | Godot 4.4.1-stable, headless build (`template_debug`, x11/wayland disabled) compiled in the sandbox from the 4.4.1 source tag |
| Validation mode | `godot --headless …` (no GPU/display available in the sandbox) |
| Visual capture | **Not possible** — headless only. No screenshot of the running game exists. |
| Static check | `gdtoolkit` 4.5.0 `gdlint` (clean) |

The engine build result and the test-run transcript are recorded in
`docs/03_TEST_REPORT.md`.
