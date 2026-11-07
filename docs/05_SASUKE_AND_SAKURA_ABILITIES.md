# Characters 002 and 003 — abilities (mechanics implemented, art NOT approved)

Implemented on 2026-11-07 for dataset ids 2 (`Sasuke Uchiha`) and 3 (`Sakura Haruno`).
Every power name is copied verbatim from `data/characters.local.json`; nothing was
renamed or invented. Both movesets carry `temporary: true`, so both fighters show
the on-screen `TEMP` tag in a real match.

Files: `data/movesets/002_sasuke.json`, `data/movesets/003_sakura.json`.
Playable from the LAB row of character select as `SASUKE UCHIHA [TEMP]` and
`SAKURA HARUNO [TEMP]` (either one as P1 or P2).

## Character 002 — Sasuke Uchiha

Stats from the dataset (hp 64 / atk 89 / def 50 / spd 95 / tech 64 / build 57) are
now part of the moveset, so his stats actually change how he fights.

| Ability | Kind | Data | Behaviour |
|---|---|---|---|
| **Amaterasu** | `special`, type `projectile` | 35 energy, 18 startup / 2 active / 22 recovery, speed 0, `lifetime_ticks` 180 (3 s), radius 46, 16 damage, 22 hitstun | Spawns a **stationary** black flame ahead of him. It does not travel; it burns in place for three seconds and disappears on its own timer. Refused below 35 energy. |
| **Sharingan** | `forms.sharingan` | 40 energy, 18 cast frames, 480-tick duration (8 s), speed ×1.15, damage ×1.2, 8 invulnerable frames | Timed buff in the `FORM` state. The "reads the opponent" idea is modelled as a short invulnerability window plus a speed and damage bump — mechanics only. Cannot stack; expires by itself. |
| **Indra's Arrow: Perfect Susanoo** | `ultimate`, type `projectile` | 100 meter, 26 startup, radius 40, 900 speed, 1400 range, 44 damage + 7 chip, 16 invulnerable frames | Fires a large violet arrow on a straight line with its own visual (`susanoo_arrow`). Meter is consumed on start. |

Basics: `light_attack` (3/2/7, 5 damage, cancels into heavy) and `heavy_attack`
(9/4/14, 12 damage, cancels into Amaterasu).

## Character 003 — Sakura Haruno

Dataset stats: hp 87 / atk 80 / def 77 / spd 49 / tech 49 / build 62. Slow, tanky,
hard-hitting — that is the whole design brief for her numbers.

| Ability | Kind | Data | Behaviour |
|---|---|---|---|
| **Byakugo Super Strength** | `special`, type `melee` | 25 energy, 15 startup / 4 active / 24 recovery, 26 damage, 28 hitstun, knockback 420/-200 | A single committed punch with a charging-fist effect (`effect.kind = "impact"`) that tightens during startup and snaps on the active frames. The biggest knockback of the three characters. |
| **Byakugo** | `forms.byakugo` | 45 energy, 22 cast frames, 600-tick duration (10 s), `heal_per_second` 6, damage ×1.15, 10 invulnerable frames | A healing form: while it is active she regenerates 6 HP per second (accumulated as whole HP, never above max), with a small damage bump. The forehead seal and chakra markings need their own approved reference. |
| **Strength of a Hundred: Cherry Blossom Impact** | `ultimate`, type `rush` | 100 meter, 22 startup / 6 active / 30 recovery, `move_speed` 560, 40 damage + 8 chip, 34 hitstun, knockback 520/-220, 14 invulnerable frames | A charged forward rush into an impact. Travels the whole move, stops dead on contact, plays the impact effect. |

Basics: `light_attack` (5/3/9, 6 damage) and `heavy_attack` (13/5/18, 17 damage,
cancels into the punch). Her slower startup is deliberate: 49 speed, 49 technique.

## Engine work this required (all data-driven, no per-character code)

| Change | File | Why |
|---|---|---|
| `stats` block carried by movesets, `damage_scale = clamp(0.8 + atk/250, 0.8, 1.4)` | `moveset_loader.gd`, `fighter.gd` | Dataset attack values now matter. Dummies without stats stay at 1.0, so existing tuning is untouched. |
| `damage_multiplier()` = stats × form, used by melee, multi-hit **and** projectiles | `fighter.gd` | One damage path instead of three; a form now also boosts a thrown Amaterasu. |
| `type: "support"` moves (no hitbox, no damage, no hitstun required) + `heal`, `energy_gain_on_cast` | `moveset_loader.gd`, `fighter.gd` | Needed for heal/buff moves. Fires once per cast, at the `startup` frame. |
| `heal(amount)` → returns HP actually restored, never exceeds max, refuses a downed fighter | `fighter.gd` | So regeneration and support moves cannot overheal or revive. |
| `forms.*.heal_per_second` | `fighter.gd` | Byakugo. Accumulated per tick, applied as whole HP. |
| `projectile.lifetime_ticks` (0 = old range-only behaviour) | `projectile.gd` | Amaterasu has no travel, so range cannot end it. |
| `amaterasu` and `susanoo_arrow` placeholder visuals | `projectile.gd` | Time-based flicker and a shaped arrow; no animation frames. |
| `effect.kind = "impact"` charged-fist visual | `fighter_visual.gd` | Strength moves read differently from the Rasengan sphere. |
| Form aura takes `aura_color` from the form data | `fighter_visual.gd` | Sharingan red, Byakugo teal, Kurama gold — same rig. |

## Smoothness — what is actually there

The same three properties the first character got, applied to the new moves:

1. **70 ms pose blend.** Every new clip (Amaterasu cast, Sharingan activation,
   punch, rush, impact) goes through the same frame-rate-independent exponential
   blend, so no pose snaps.
2. **Time-based effects.** The Amaterasu flicker, the aura pulse and the arrow
   glow read wall-clock time; the impact ring is driven by the move's own
   `startup` value, eased with smoothstep, so it tightens instead of jumping.
3. **Data-driven timing.** Startup, active, recovery, rush speed and flame
   lifetime all come from the moveset JSON.

Not done: still no sprite or skeletal frames, no hit-stop, no trails, and **nobody
has seen any of it** — the sandbox has no renderer. Smoothness here is verified by
construction and by the tests, not by eye.

## Tests

* `tests/test_combat.gd` → `combat / character 002 abilities` (28 checks): moveset
  loads with stats, Amaterasu/Sharingan/Indra's Arrow names, form flagged for
  separate approval, stat scaling > 1.0, energy cost 35, exactly one projectile
  with the `amaterasu` visual, speed 0, does not move, still burning after 30
  ticks, Sharingan spends 40 and grants both multipliers, expires back to base,
  ultimate refused without meter then consumes it, spawns one `susanoo_arrow`
  that travels forward.
* `tests/test_combat.gd` → `combat / character 003 abilities` (21 checks): names,
  Byakugo form with `heal_per_second` 6, heal caps at max, heal refuses a downed
  fighter, punch spends 25 and lands damage with knockback, Byakugo regenerates
  HP over time in combat, form still boosts damage, ultimate consumes the meter,
  rushes forward and deals ≥30.
* `tests/test_data.gd` → 4 checks: support moves load without hitbox/damage/hitstun
  and keep `heal`; `projectile.lifetime_ticks` survives the loader.
* `tests/test_ui_save.gd` → `ui / characters 002 and 003 in a live match` (10
  checks): both bind in a real VERSUS scene, both keep the `TEMP` tag, both use
  their dataset stats, Sharingan and Byakugo both usable in a live match, and
  Byakugo actually heals during a match.

Full suite after this batch: **377 checks, 0 failures, exit 0**.

## Still required before these can be called finished

1. Approved reference sheets for both characters (concepts are unapproved).
2. Separate references for **Sharingan** and **Byakugo** before any final form art.
3. Real animation frames per clip.
4. A human look on a machine with a GPU.

Characters are being built one at a time, in dataset order: 001 done, 002 and 003
done to this same standard, next is id 4.
