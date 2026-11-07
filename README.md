# ANIME SAGA

Strictly 2D anime fighting game in **Godot 4.4 / GDScript** with two modes:

* **VERSUS** — 1v1 side-view fighting (player vs AI, or local 2 players)
* **DUNGEON** — top-down action run (rooms, locked doors, traps, loot, boss)

> **Honest status: pre-alpha, Phase 2 (mechanics lab) — now running on a real engine,
> and the real roster is loaded.**
> What is playable now is the *engine*: two temporary `TEMP` dummies fighting in
> a temporary arena, and one seeded dungeon run with temporary shapes.
> The character file you supplied is live in the boot report and the roster:
> **500 records, 90 series, 500 complete, 0 duplicate ids** — and **0 playable**,
> because every record is still `DATA_ONLY`. Nothing from any anime is
> implemented, approved or playable; the reference gate for Naruto is open (one
> proposal shown, unapproved). Five characters (ids 1–5) now have their
> abilities implemented as data with placeholder visuals. See `docs/00_PHASE0_AUDIT.md`.
>
> Verified on 2026-11-07 with a locally compiled Godot 4.4.1: the headless suite
> reports `PASSED: 429 FAILED: 0`, exit code `0` (`docs/03_TEST_REPORT.md`).
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
| Character select with search, element/role/rarity filters, status badges, lock gating, 600+ paging | working — **500 real records / 90 series loaded**, all locked as `DATA_ONLY`, searchable and filterable |
| Versus fight: move, run, jump, crouch, block, light/heavy/special/ultimate, hitstun, blockstun, knockback, knockdown, get-up, combo counter, cancel windows, input buffer, body collision | working (lab dummies) |
| Character 001 abilities: Rasengan dash, Kurama Chakra Mode timed form, Tailed Beast Rasenshuriken ultimate, plus a smooth pose-blended rig | **mechanics + placeholder visuals** — playable from the LAB row as `NARUTO UZUMAKI [TEMP]`; design still unapproved (`docs/04_NARUTO_ABILITIES.md`) |
| Character 002 abilities: Amaterasu stationary flame, Sharingan timed form, Indra's Arrow: Perfect Susanoo ultimate | **mechanics + placeholder visuals** — LAB row `SASUKE UCHIHA [TEMP]` (`docs/05_SASUKE_AND_SAKURA_ABILITIES.md`) |
| Character 003 abilities: Byakugo Super Strength punch, Byakugo healing form, Strength of a Hundred: Cherry Blossom Impact rush ultimate | **mechanics + placeholder visuals** — LAB row `SAKURA HARUNO [TEMP]` (`docs/05_SASUKE_AND_SAKURA_ABILITIES.md`) |
| Character 004 abilities: Sharingan / Kamui warp dash, Sharingan form, Kamui: Wrinkle-Dimension Slash ultimate | **mechanics + placeholder visuals** — LAB row `KAKASHI HATAKE [TEMP]` (`docs/06_KAKASHI_AND_ITACHI_ABILITIES.md`) |
| Character 005 abilities: Amaterasu flame, Tsukuyomi form, Susanoo: Totsuka Blade Seal ultimate | **mechanics + placeholder visuals** — LAB row `ITACHI UCHIHA [TEMP]` (`docs/06_KAKASHI_AND_ITACHI_ABILITIES.md`) |
| Stat-driven damage, support (heal) moves, timed projectiles | working — dataset `atk` scales damage, forms add a multiplier, `heal` cannot overheal |
| State frame proposals (walk / run / special / form / ultimate) with normalised frame sheets and looping previews | **proposal art, unapproved** — `assets/characters/states/`, walk + run cycles for character 001 (`docs/07_STATE_FRAMES.md`) |
| Rounds, rounds-to-win, optional timer, K.O./time-up, winner, rematch, return to menu | working |
| AI opponent (approach, spacing, attack, block, meter usage) with delayed perception | working |
| Dungeon: seeded layout, connectivity validation, rooms, doors that lock during fights, trap with telegraph, loot, rest pad, boss with 3 readable patterns, win/lose/restart | working (temporary shapes) |
| Dungeon environments: 8 authored room themes, chosen deterministically from the run seed, hinted by the selected character's world | working (palettes and accents, no room art yet) |
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

1. **Dataset is loaded but nothing is playable.** Your file lives at
   `data/characters.local.json` (git-ignored, source byte-identical, md5
   `d0ece50b…`), and it uses `anime` + a nested `signature` object instead of this
   project's `series`/`powers` names. The loader maps those fields **without
   editing your file**: 500 records, 90 series, 500 complete, 0 duplicates, 0
   validator errors. Every record is `DATA_ONLY`, so the entire roster is locked
   by design until characters are approved and animated. The capacity target is
   600 and the dataset holds 500 — **100 short, and they will not be invented.**
2. **Art is still gated.** Two external references were viewed on 2026-11-07 and
   a design proposal has been shown, but nothing is approved and **no animation
   frame exists**. `designLocked` is `false`, `animationBlocked` is `true`
   (`docs/02_REFERENCE_NARUTO.md`, `assets/characters/001_naruto/`).

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
data/                        characters.json (empty container) + characters.local.json (your 500), movesets, stages, localization, dungeon data, references
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

1. You approve the Naruto proposal (or send corrections + a Shippuden setting
   sheet, and the dungeon-camera views).
2. I revise the proposal and show it again for explicit approval; nothing is
   locked or animated before that.
3. After approval: design lock → animation → moveset → both cameras → QA →
   `PLAYABLE`.
4. Then the Konoha stage, then the next characters in small batches.
