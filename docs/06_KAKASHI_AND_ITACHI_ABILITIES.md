# Characters 004 and 005 — abilities (mechanics implemented, art NOT approved)

Implemented on 2026-11-07 for dataset ids 4 (`Kakashi Hatake`) and 5 (`Itachi Uchiha`).
Power names are copied verbatim from `data/characters.local.json`; nothing was
renamed. Both movesets carry `temporary: true` and both fighters show the `TEMP`
tag in a real match. Playable from the LAB row as `KAKASHI HATAKE [TEMP]` and
`ITACHI UCHIHA [TEMP]`.

## Character 004 — Kakashi Hatake

Dataset stats: hp 71 / atk 62 / def 53 / spd 73 / tech 93 / build 90 (power level 74).
He is the technician of the group: high tech and build, low raw attack, so his
damage scale is barely above baseline (1.048) while his moves give him reach,
mobility and invulnerability windows.

| Ability | Kind | Data | Behaviour |
|---|---|---|---|
| **Sharingan / Kamui** | `special`, type `rush` | 35 energy, 12 startup / 5 active / 20 recovery, `move_speed` 700, 18 damage, 24 hitstun, 12 invulnerable frames | A warp-dash: he covers ground fast for the whole move, is invulnerable through the entry frames, and stops dead on contact. |
| **Sharingan** | `forms.sharingan` | 30 energy, 16 cast frames, 420-tick duration (7 s), speed ×1.2, damage ×1.15, 6 invulnerable frames | Timed read/dodge window. Cheapest form of the five characters so far. |
| **Kamui: Wrinkle-Dimension Slash** | `ultimate`, type `projectile` | 100 meter, 24 startup, radius 56, 780 speed, 1200 range, 42 damage + 8 chip, 14 invulnerable frames | Throws a dimensional rift (`kamui_slash` visual: jagged violet polygon with a bright core) on a straight line. |

Basics: `light_attack` (4/2/8, 5 damage) and `heavy_attack` (10/4/15, 12 damage,
cancels into the warp).

## Character 005 — Itachi Uchiha

Dataset stats: hp 58 / atk 91 / def 62 / spd 94 / tech 63 / build 56 (power level 71).
Frail but the highest attack of the five — his damage scale is 1.164 with the
lowest HP pool in the lab (67).

| Ability | Kind | Data | Behaviour |
|---|---|---|---|
| **Amaterasu** | `special`, type `projectile` | 40 energy, 16 startup, speed 0, `lifetime_ticks` 210 (3.5 s), radius 52, 19 damage, 24 hitstun | A black flame that stays where it lands and burns longer than Sasuke's. Refused below 40 energy. |
| **Tsukuyomi** | `forms.tsukuyomi` | 45 energy, 20 cast frames, 360-tick duration (6 s), damage ×1.25, speed ×1.1, 20 invulnerable frames | The eye-contact window: the longest invulnerability in the game so far, paid for with the shortest duration. Mechanics only — no genjutsu scene. |
| **Susanoo: Totsuka Blade Seal** | `ultimate`, type `projectile` | 100 meter, 26 startup, radius 48, 620 speed, 1150 range, 46 damage + 9 chip, 18 invulnerable frames | Throws the sealing blade (`totsuka_blade` visual: long crimson-edged blade with a drifting sealing spiral). The slowest and hardest-hitting ultimate so far. |

Basics: `light_attack` (3/2/7, 5 damage) and `heavy_attack` (8/4/13, 13 damage,
cancels into Amaterasu).

## New visuals (both placeholders, time-based, no frames)

| Visual | File | Description |
|---|---|---|
| `kamui_slash` | `scripts/combat/projectile.gd` | Two counter-rotating jagged polygons (a dark rift inside a violet halo) plus a white core. Rotates on wall-clock time, so it spins identically at any frame rate. |
| `totsuka_blade` | `scripts/combat/projectile.gd` | A shaft with a gold core, a crimson guard and three sealing motes travelling along the blade on a phase offset. |

Both reuse the form aura colouring added for characters 002/003, so Sharingan is
red and Tsukuyomi violet without any per-character code.

## Tests

* `combat / character 004 abilities` (19 checks): moveset loads, verbatim names,
  Sharingan declared, damage scale below 1.1 (he is not a raw bruiser), warp
  spends 35, grants invulnerability ticks, covers >60 px, lands damage, Sharingan
  costs 30 and boosts speed and damage, ultimate refused without meter, spawns
  exactly one `kamui_slash` projectile of radius ≥50.
* `combat / character 005 abilities` (18 checks): verbatim names, Tsukuyomi
  declared, Amaterasu costs 40, spawns one stationary `amaterasu` flame that
  burns ≥200 ticks, Tsukuyomi costs 45 with a ≥20-frame invulnerable window and
  a ×1.25 damage multiplier, ultimate spends the meter, spawns one
  `totsuka_blade` and that blade travels forward.
* `ui / temporary lab roster` (15 checks): all seven lab entries (2 dummies + 5
  characters) resolve to a loadable moveset and all five characters stay flagged
  `TEMPORARY`; Kakashi's dataset `tech` value reaches the moveset.

Full suite after this batch: **429 checks, 0 failures, exit 0**.

## Honest notes

* The two failures hit while writing these tests were **test bugs**, not engine
  bugs: Kakashi's warp was tested from 340 px away, which is outside what a
  700 px/s dash can cover inside its own frame budget, and his ultimate was
  fired while the test dummy had already walked into the spawn point — the
  projectile spawned inside the opponent's hurtbox, hit instantly and despawned.
  Both were corrected by resetting spacing, and the behaviour (a projectile that
  spawns overlapping a target hits immediately) is intended.
* Nothing here has been seen. There is no renderer in the sandbox.
* Both forms still need their own approved references before final art.

## Next

Characters are built in dataset order: 001–005 are done to this standard. Id 6
(`Jiraiya`, `Sage Mode / Toad Summoning`, ultimate `Sage Art: Cho Odama Rasengan`)
is next.
