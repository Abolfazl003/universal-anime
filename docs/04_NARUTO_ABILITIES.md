# Character 001 — abilities (mechanics implemented, art NOT approved)

Implemented on 2026-11-07 for character id 1 (`Naruto Uzumaki`) from the dataset's
signature field. The power names are used verbatim; nothing was renamed.

**Status: mechanics + placeholder visuals only.** The design is still unapproved,
so `temporary: true` stays in the moveset, the fighter keeps its on-screen `TEMP`
tag, and no final animation frame exists. Kurama Chakra Mode additionally carries
`requires_separate_reference_approval: true`.

## The three abilities, one by one

| Ability | Kind | Data | Behaviour |
|---|---|---|---|
| **Rasengan** | `special`, type `rush` | 30 energy, 16 startup / 6 active / 20 recovery, `move_speed` 640, 22 damage, 26 hitstun | A committed forward dash with the sphere in the front hand. The dash lasts the whole move and stops dead the moment it connects. Refused with less than 30 energy. |
| **Kurama Chakra Mode** | `forms.kurama_chakra_mode` | 60 energy, 26 cast frames, 600-tick duration (10 s), speed ×1.25, damage ×1.3, 12 invulnerable frames | Enters the new `FORM` state, plays the activation clip, then stays active as a timed buff. Multipliers apply to movement, to melee hitbox damage and to projectile damage. Cannot stack; expires on its own, and is cleared on respawn. |
| **Tailed Beast Rasenshuriken** | `ultimate`, type `projectile` | 100 meter, 24 startup, radius 52, 560 speed, 1100 range, 38 damage, 12 invulnerable frames | A large thrown disc with its own spinning visual. Meter is consumed on start; refused below 100. |

Basic attacks are also data: `light_attack` (4/3/8, 5 damage, cancels into heavy)
and `heavy_attack` (10/4/16, two 7-damage phases, cancels into Rasengan).

## Input

| Action | P1 | P2 | Gamepad |
|---|---|---|---|
| Transform | `O` | `KP 6` | left stick click |
| Special (Rasengan) | `U` | `KP 4` | right shoulder |
| Ultimate (Rasenshuriken) | `I` | `KP 5` | right stick click |

Rebindable in Controls. `input.form` is localized in both `en` and `fa`.

## "The animation must be smooth" — what was actually done

The rig is procedural (placeholder), so smoothness is a property of the code:

1. **Pose blending.** Every numeric pose value is blended toward the new clip's
   target with a frame-rate-independent exponential (`1 - exp(-dt / 0.07)`), so a
   clip change is a 70 ms transition instead of a teleport. This is the single
   biggest reason the placeholder rig no longer snaps.
2. **Eased attack curves.** The arm swings on `light_attack`, `heavy_attack`,
   `special` and `ultimate` used linear clamps; they now use a smoothstep
   (`x²(3−2x)`), which removes the robotic start/stop at the ends of a swing.
3. **Time-based, not frame-based.** Animation progress, the Rasengan spin, the
   aura pulse and the Rasenshuriken blade rotation all read wall-clock/simulation
   time, so they look identical at 60, 144 or 240 fps.
4. **Data-driven motion.** Rush speed, startup, active and recovery come from the
   moveset; the body never moves on a hard-coded timer.
5. **Committed dash with a clean stop.** The rush travels through the whole move
   and zeroes its velocity on contact, so the attacker does not slide through the
   opponent.

What is **not** done: no sprite frames, no skeletal animation, no motion blur, no
hit-stop changes, and the visual result has **never been seen** — the sandbox
build has no renderer. "Smooth" is verified by construction and by the tests, not
by eye.

## Tests

`tests/test_combat.gd` → `combat / character 001 abilities` (12 checks): moveset
loads, Rasengan is the special at 30 energy, ultimate is the Rasenshuriken at a
full meter, the form exists and is flagged for separate approval, Rasengan is
refused without energy and spends it when used, the dash moves the fighter,
damage lands, the dash stops on contact, the form consumes 60, enters `FORM`,
grants both multipliers, refuses to stack, expires, restores normal multipliers,
leaves the fighter actionable, and the ultimate consumes the meter and spawns
exactly one projectile with the `rasenshuriken` visual and a large radius.

Later batches made his dataset stats part of the moveset, so his attack value now
scales his damage the same way it does for every other character. Re-verified with
characters 002 and 003; the checks below are unchanged.

Full suite: **377 checks, 0 failures, exit 0** (`docs/03_TEST_REPORT.md`).

## Still required before this can be called finished

1. Explicit approval of the character design (proposal v1 is still unapproved).
2. A reference sheet for **Kurama Chakra Mode** before any final art of the form.
3. Real animation frames replacing the procedural rig, per clip, at the recorded
   per-clip FPS.
4. A human look at the result on a machine with a GPU.
