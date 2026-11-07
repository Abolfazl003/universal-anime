# Phase 1 + Phase 2 — build report

Scope executed: **Phase 0 (audit)**, **Phase 1 (executable base)**, **Phase 2
(mechanics lab)**, plus the infrastructure for Phase 3 (reference gate).
Naruto's animation and moveset are **not** produced — by rule they are blocked
until an approved reference exists.

## What was built

### Executable base (Phase 1)
* `project.godot` — Godot 4.4, 2D only, `gl_compatibility`, 1920×1080 canvas with
  `canvas_items` stretch, 60 Hz physics, autoloads for services.
* Boot screen reporting the real data state (source file, record count, validator
  output, moveset/stage counts, save status, engine version).
* Main menu → Mode select → Character select → Character detail → Versus setup →
  Stage select → Versus → Results → Rematch, plus Settings, Controls, Reference
  gallery, Animation review. Pause overlay and restart from every gameplay screen.
* Full UI vocabulary in `data/localization/en.json` + `fa.json` (226 keys each),
  with a test that fails if code uses a key a locale does not define.

### Mechanics lab (Phase 2)
* Two temporary dummies (`lab_dummy_a`, `lab_dummy_b`) with **different** frame
  data, proving the engine is data-driven rather than hard-coded.
* Moves: light, heavy (explicit 2-phase multi-hit), special (projectile), ultimate
  (meter-gated projectile + invulnerable frames).
* Systems: HP, special energy, ultimate meter, combo counter, hitstun, blockstun,
  knockback, knockdown, get-up with invulnerability, recovery, input buffer,
  cancel windows, body collision, round timer, rounds-to-win, K.O./time-up.
* AI opponent with delayed perception (sees the world `reaction_ticks` in the
  past), quantised decisions, block/anti-air/spacing/meter behaviour.
* One seeded dungeon run: generated rooms, corridor-free grid layout, doors that
  lock during fights, a telegraphed trap, loot cache, rest pad and a boss with
  three patterns (radial burst, charge, ring) — all temporary shapes labelled
  `TEMP` on screen.

## Architecture (why adding a character is data-only)

```
Battle data (JSON)  →  Fighter controller  →  CombatManager  →  HUD
        ↑                     ↑                    ↑
  movesets/frame data   state table         hit resolution
```

* `scripts/characters/fighter.gd` contains **no** character names and no
  per-character branching; identity comes from the moveset dictionary.
* `scripts/combat/fighter_states.gd` is the single state table; every transition is
  checked against it and illegal transitions are refused with a warning.
* Combat resolution is deterministic AABB math on data rectangles
  (`scripts/combat/combat_manager.gd`), so headless tests exercise the real code.
* Timing is in 60 Hz ticks everywhere (`resources/animations/*.json`,
  `data/movesets/*.json`); animation playback is delta-based, so it does not
  depend on the display refresh rate.
* Menus are built from one `UIKit` so text scaling, focus rings and contrast stay
  consistent; no colour-only information.

## Verification performed

| Check | Result |
|---|---|
| Static analysis (`gdlint`, gdtoolkit 4.5.0) | clean, 0 problems |
| Headless engine run of the whole test suite | **314 / 314 checks pass**, process exit code 0 — full transcript in `docs/03_TEST_REPORT.md` |
| Both scenes started directly (F6 style) | all 16 scenes start with 0 `SCRIPT ERROR` after the fixes recorded in `docs/03_TEST_REPORT.md` |
| Visual check of the running game | **not possible** — the sandbox has no display/GPU, the engine was built headless. Gameplay logic is proven; the *look* is not. |
| Screenshots / video | none produced |

## What is temporary and must not be presented as final

* All fighter visuals: procedural rig drawn in code, tagged `TEMP` in-game.
* Lab arena geometry: ruler-marked training ground, `TEMPORARY`.
* Dungeon enemies/boss: abstract shapes with `TEMP` labels, data flagged
  `temporary: true`.
* Placeholder portraits in Character Select: text block "PORTRAIT PENDING".
* Audio: silent buses, no music or SFX shipped.

## Known limitations (honest list)

1. No character data and no approved art → nothing from any anime is playable.
2. Versus has no air attacks (`air_ok` exists in data as `false` for every lab
   move), no throws, no blocking in the air.
3. Crouch and stand blocking share one block animation; low/high attacks are not
   differentiated yet.
4. The AI does not use frame traps or whiff punishes; it is a readable lab
   opponent, not a tournament opponent.
5. Dungeon enemies use clamped movement inside convex rooms instead of full
   navigation; there is no pathfinding because rooms have no obstacles yet.
6. Dungeon difficulty curve is a first pass: room count is fixed at 7 with a
   single boss.
7. Two-player local versus needs two gamepads or shared keyboard; there is no
   keyboard-split rebinding UI shortcut (rebinding is per action in Controls).
8. `fa` UI strings exist but the built-in font does not cover Arabic script, so
   Persian labels render as boxes until a suitable TTF is bundled.
9. Nine-Patch/scale UI at 4K is untested without a display.
10. Combos are counted per attacker/defender pair only; no juggle limits.

## Next phase (blocked on you)

Phase 3 — Naruto reference: needs reference images or links (front / side / back /
three-quarter + dungeon views) plus answers to the open questions in
`docs/02_REFERENCE_NARUTO.md`. Then the design proposal is shown to you, revised,
approved, locked, and only then animation begins.
