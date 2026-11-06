# ANIME SAGA

Strictly 2D anime fighting game in **Godot 4.4 / GDScript** with two modes:

* **VERSUS** — 1v1 side-view fighting (player vs AI, or local 2 players)
* **DUNGEON** — top-down action run (rooms, locked doors, traps, loot, boss)

> **Honest status: pre-alpha, Phase 2 (mechanics lab) — now running on a real engine.**
> What is playable now is the *engine*: two temporary `TEMP` dummies fighting in
> a temporary arena, and one seeded dungeon run with temporary shapes.
> **No anime character is implemented, approved or playable yet**, because the
> repository contains no `characters.json` and no reference image could be
> retrieved to design one. See `docs/00_PHASE0_AUDIT.md`.
>
> Verified on 2026-11-07 with a locally compiled Godot 4.4.1: the headless suite
> reports `PASSED: 252 FAILED: 0`, exit code `0` (`docs/03_TEST_REPORT.md`).
> The first run also exposed five real defects — dead state transitions, an
> unregistered combat manager, unavailable data on direct scene starts, a
> validator miscount, and two bad test assertions — all fixed and listed there.
> **Still unseen:** anything visual. The sandbox has no display, so no frame of
> this game has ever been rendered by anyone.

## Run it

Requires **Godot 4.4.x** (project was validated with 4.4.1-stable, GDScript,
`gl_compatibility` renderer).

```bash
# editor
godot --path .

# run directly
godot --path . res://scenes/boot/boot.tscn

# headless test suite (returns 0 when all checks pass)
godot --headless --path . res://tests/test_runner.tscn
```

The project opens and runs without any imported binary assets: all placeholder
art is drawn in code, so a fresh checkout needs no import step.

`tools/run_tests.sh`, `tools/run_game.sh` and `tools/lint.sh` wrap the three
commands above; each accepts an engine path as its first argument or via
`GODOT_BIN`. `tools/run_tests.sh` prints the suite result and exits non-zero on
any failed check.

## What actually works

| Feature | State |
|---|---|
| Boot screen with a real data report (source file, records, playable, validator output, save status) | working |
| Main menu → mode select → character select → versus setup → stage select → match → results → rematch | working |
| Character select with search, element/role/rarity filters, status badges, lock gating, 600+ paging | working (empty roster until data exists) |
| Versus fight: move, run, jump, crouch, block, light/heavy/special/ultimate, hitstun, blockstun, knockback, knockdown, get-up, combo counter, cancel windows, input buffer, body collision | working (lab dummies) |
| Rounds, rounds-to-win, optional timer, K.O./time-up, winner, rematch, return to menu | working |
| AI opponent (approach, spacing, attack, block, meter usage) with delayed perception | working |
| Dungeon: seeded layout, connectivity validation, rooms, doors that lock during fights, trap with telegraph, loot, rest pad, boss with 3 readable patterns, win/lose/restart | working (temporary shapes) |
| Pause menu (resume / restart / controls / character select / main menu) | working |
| Settings: separate master/music/SFX, window mode, resolution, text scale, screen shake, flash intensity, reduced motion, language (en/fa) | working |
| Controls screen with rebinding, persisted per profile | working |
| Save in `user://` with schema version, atomic write, corruption recovery, reset | working |
| Debug overlay (F3), hitbox view (F4), slow motion (F6), animation review tool (pause / slow / frame-step) | working |
| Naruto reference approval gallery | working as a **blocked** gate (no images available) |
| Naruto design, animation, moveset, Konoha stage | **not started / blocked** |

## Controls

See `docs/CONTROLS.md`. Defaults: P1 `WASD` + `J K L U I`, P2 arrows + numpad,
`Esc` pause, `F3` debug, `F4` hitboxes, `F6` slow motion. All rebindable.

## The two blockers (read this before expecting Naruto)

1. **`data/characters.json` is not in the repository.** Nothing was invented to
   fill it: no ids, no names, no powers, no fake roster. `data/characters.json`
   is an explicit empty container; the loaders, filters, paging and locks are all
   implemented and proven with an in-memory 650-record fixture in the tests.
   Drop the real file (or the git-ignored `data/characters.local.json`) and the
   roster appears with no code changes.
2. **No reference image could be retrieved or viewed** in the build environment
   (image search returned nothing, image hosts unreachable). Per the
   reference-first rules, no design proposal, no reference sheet and **no
   animation frames** were produced for Naruto. Text sources were read and are
   logged with URLs in `data/references.json` and
   `docs/02_REFERENCE_NARUTO.md`.

## Repository layout

```
project.godot                Godot 4.4 project (input actions are runtime-registered)
scenes/                      boot, menus, versus, dungeon, ui
scripts/
  core/                      services: data, settings, localization, router, session
  data/                      character validator, moveset loader, animation DB, stage loader
  input/                     InputMapService (tick-accurate), input buffer, human intent
  combat/                    state table, combat manager, projectiles
  characters/                fighter controller + procedural placeholder rig
  ai/                        versus AI
  dungeon/                   seeded generator, run controller, avatar, enemies, traps
  ui/                        every screen, built with a shared UIKit
  save/                      SaveService (atomic, versioned, corruption-tolerant)
  debug/                     F3 overlay, animation review tool
data/                        characters.json, movesets, stages, localization, dungeon data, references
resources/animations/        animation timing metadata (no image frames yet)
assets/characters/001_naruto/ reference / approved / sprites / effects / metadata folders
tests/                       headless test suite + runner scene
docs/                        audits, specs, reference gate, test report
```

## Design rules the code follows

* Characters are **data**; the combat engine contains no character names.
* Frame data lives in JSON (ticks at 60 Hz), never in scenes, and playback is
  delta-based so it is independent of display refresh rate.
* Hitboxes/hurtboxes are data rectangles, never the sprite.
* One attack phase can damage a target only once; multi-hit moves declare phases.
* All state changes go through one state table (allowed exits are enforced).
* Temporary things are labelled `TEMP` on screen; nothing temporary is presented
  as final art.
* Canonical names (characters, series, powers) are never translated by the game.

## Assets and rights

Personal, non-commercial fan project. Nothing in this repository ships licensed
anime art, music, voices or logos: every visual is procedural placeholder
geometry and every audio bus is silent. Reference URLs are recorded for research;
**viewing a reference is not a license to publish it**. Redrawing a character
does not remove its rights either.

## Next steps

1. You provide `characters.json` + reference images for Naruto (front, side,
   back, three-quarter, dungeon views).
2. I show the reference package and a design proposal for explicit approval.
3. After approval: design lock → animation → moveset → both cameras → QA →
   `PLAYABLE`.
4. Then the Konoha stage, then the next characters in small batches.
