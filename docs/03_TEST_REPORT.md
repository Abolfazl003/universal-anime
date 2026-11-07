# 03 — Test report (first real engine run)

This is the first document in the project backed by an actual Godot process
instead of static reading. Everything below was executed in the sandbox on
2026-11-07 (UTC) and the transcripts are reproduced verbatim.

## Engine

| Item | Value |
|---|---|
| Binary | `/home/user/tools/godot` (copy of the build output, kept outside the repo) |
| Version string | `4.4.1.stable.custom_build` |
| Build | locally compiled from the official 4.4.1 source, `target=template_debug`, `-j2` |
| Modules | 3D, X11, Wayland, Vulkan, GLES3 and audio backends **disabled** |
| Consequence | the engine prints `ERROR: No renderers available.` on every start |

That renderer error is a property of *my* stripped build, not of the project:
with neither Vulkan nor GLES3 compiled in, the engine has no renderer to
register. Headless logic execution is unaffected, and the full suite runs. What
this build **cannot** do is draw a frame — so no screenshot, no visual check, and
no claim about how anything looks.

## Command and result

```console
$ cd /home/user/universal-anime
$ /home/user/tools/godot --headless --path . res://tests/test_runner.tscn
...
---------------------------------------------
PASSED: 252   FAILED: 0   TOTAL: 252
---------------------------------------------
RESULT: PASSED
$ echo $?
0
```

That was the state on the first clean run (252 checks). Eight alias checks were
added afterwards when the real dataset arrived, so the current suite is **260
checks**, still at 0 failures — see "Second run" below.

The runner itself prints `RESULT: PASSED`, and the process exit code is `0`
(the runner calls `quit(1)` on any failure, so a shell/CI gate can rely on it).

Also verified:

```console
$ /home/user/tools/godot --headless --path . --quit
$ echo $?
0
```

`--quit` with the boot scene: no script errors, only the two engine-build
messages described above (`No renderers available`, and `Could not load global
script cache`, which is expected for a template build with no editor import
cache — the project uses `preload()` paths everywhere, so nothing depends on it).

Warning count in the passing run: **0** `WARNING`, **0** `SCRIPT ERROR`.

## What the 260 checks cover

| Suite | Coverage |
|---|---|
| `data / validator` | duplicate ids, incomplete records, power-name preservation, status normalisation, "absent optional fields are not invented", **and the `anime`/`signature` aliases of the supplied dataset** |
| `data / character store` | 600 capacity target, honest empty dataset (no fabricated records), extension loading, references index |
| `data / capacity + filtering` | synthetic 650-record fixture (never written to disk): search by name/series, element/rarity filters, pagination math, lock rules |
| `data / movesets`, `animations`, `stages` | every JSON file parses, frame data is internally consistent, per-animation FPS recorded |
| `combat / state table` | every state declares an animation, transitions are legal, terminals are explicit |
| `combat / timing` | no hitbox before `startup`, active window length matches data ±1 tick, move returns to neutral |
| `combat / damage` | one damage instance per active phase, multi-hit phases each land once, chip damage on block, blockstun, combo counter, energy gain |
| `combat / projectile` | special spawns a projectile exactly once and it damages once |
| `combat / ultimate` | gated by a full meter, consumes it |
| `combat / grounding` | respawn puts feet on the floor, jump leaves the ground, landing restores grounding |
| `dungeon` | room graph, door locking rules, floor progression, enemy contact damage |
| `ui / capacity and match flow` | 650-character select renders one page of cards, versus stage spawns both fighters, INTRO → FIGHT, round ends on KO, round point awarded |
| `input / save` | rebinding label + persistence + reset, corrupt save → CORRUPT with preserved copy, backup-only → PARTIAL, no save → NEW, settings defaults (shake/flash off, reduced motion on) |

## Bugs the real run exposed (all fixed in this branch)

None of these were visible to `gdlint`; every one of them was a live defect that
made the game wrong.

1. **Every state transition was refused.** `fighter_states.gd` stored exit
   states as readable names (`"WALK"`) but `transition_allowed()` compared them
   to integer enum values, so the comparison was always false and `_enter()`
   returned early. The fighter stayed in IDLE forever (546 `Illegal fighter
   transition` warnings in the first run). Fixed with `resolve_state()` and a
   name-resolution pass in `validate_table()`; `DEFEAT`/`OUTRO` are now the
   explicit terminals.
2. **Combat resolution was dead code.** `CombatManager` only ever resolved hits
   for fighters in its `fighters` array, but nothing called `add_fighter()` —
   not the versus match, not the tests. Damage, blockstun, combo counting,
   projectiles and energy gain were all silently inert. Fixed: the manager now
   auto-registers any child that implements `active_hit()` (and unregisters on
   exit), so adding the node is enough.
3. **Data was unavailable on direct scene starts.** `GameData` loads on a
   deferred `_ready()`, so F6-style single-scene runs hit `null` loaders
   (`Nonexistent function 'get_moveset' in base 'Nil'`, then `list_stages` and
   `get_stage`). Fixed with `ensure_loaded()` plus `stage()`, `all_stages()`,
   `stage_count()`, `moveset_count()` accessors; the four call sites in
   `boot_screen.gd`, `versus_setup.gd`, `stage_select.gd` and `versus_match.gd`
   now use them.
4. **Validator counted unimportable records as valid.** A structurally complete
   record with a duplicate id was counted in `valid_records` even though it can
   never be imported. Fixed: duplicates are excluded from the valid count.
5. **Two test defects** (test-side, listed for honesty rather than as gameplay
   bugs): the "no hitbox during startup" assertion was inverted, and the
   grounding test jumped straight after `respawn()`, which deliberately starts
   in INTRO. The block test also read `blockstun_ticks` after it had expired and
   inherited a GETUP state from the previous test; it now resets the dummy and
   samples the stun every tick. The save test expected `NEW` while a `.backup`
   file still existed — backup-only is correctly reported as `PARTIAL`, so the
   test now asserts both cases.

## Scene sweep

Each scene was started headless for 6 s (`timeout`), capturing only
`SCRIPT ERROR` / `WARNING` / `Nonexistent` lines. Before fixes 3, `stage_select`
and `versus_setup` failed; now all 16 scenes are clean. `dungeon_run`,
`anim_review` and the menus simply keep running until the timeout kills them,
which is the expected behaviour for a non-quitting scene.

## Second run — with the real dataset loaded

After `data/characters.local.json` (500 records) was supplied, the same suite and a
data probe were re-run on the same engine:

```console
$ godot --headless --path . res://tests/test_runner.tscn
PASSED: 260   FAILED: 0   TOTAL: 260        # exit 0, real dataset loaded
$ godot --headless --path . --script /tmp/probe4.gd
existing=500 prepared=500 playable=0 series=90 statuses={ "DATA_ONLY": 500 }
validator: ok=true errors=0 warnings=0 incomplete=0
```

Search and filter probes against the live dataset: `"naruto"` → 38 matches,
series `Bleach` → 25, element `Fire` → 29, `only_playable` → 0, unfiltered → 500.
`character_select`, `character_detail` and `boot` scenes start with no script
errors while holding the real roster.

### Two more defects the real data exposed (fixed)

6. **The boot screen's validator line was hard-wired to "clean".**
   `GameData.reload_all()` overwrote `validation_report` with its own merged
   summary, which has no `errors`/`warnings` keys, so the screen always printed
   "no duplicate ids, no missing required fields" regardless of the file. The
   validator report and the merged data report are now separate
   (`validation_report` vs `data_report`).
7. **"Complete records" counted 0 for every real record.** The boot stat tested
   raw field names, so a file using `anime`/`signature` looked 100% incomplete.
   Completeness now goes through the same alias resolution as the validator
   (`CharacterValidator.is_complete`), and reports 500/500.

## Third run — after character 001's abilities

Rasengan, Kurama Chakra Mode and the Tailed Beast Rasenshuriken added 12 combat
checks plus 5 end-to-end scene checks (`docs/04_NARUTO_ABILITIES.md`).

```console
$ godot --headless --path . res://tests/test_runner.tscn
PASSED: 314   FAILED: 0   TOTAL: 314      exit 0
```

Three defects found while wiring the abilities, all fixed:

8. **The loader silently dropped `forms` and move `name`/`effect`.** The engine
   looked correct but every transformation was unreachable and abilities had no
   names, because `MovesetLoader._register` never copied the new keys.
9. **The rush could not reach.** A dash that only moves during active frames
   travelled ~96 px, so a Rasengan thrown from 300 px away could never connect.
   The rush now commits to the whole move and stops only on contact.
10. **The form cast outlives the buff by design** — the test assumed the fighter
    became actionable the instant the buff expired, which is wrong; the cast
    animation still has to finish.

## Fourth run — 2026-11-07 (characters 002 and 003)

Sasuke and Sakura moved from "record in the dataset" to "playable abilities", and
the engine gained the pieces their moves need: dataset `atk` scaling damage,
support (heal) moves, healing forms, and projectiles that expire on a timer
instead of on range.

```console
$ godot --headless --path . res://tests/test_runner.tscn
PASSED: 377   FAILED: 0   TOTAL: 377      exit 0
```

63 new checks: 28 for Sasuke, 21 for Sakura, 10 for the duo in a live VERSUS
scene, and 4 in the data layer for support moves and timed projectiles
(`docs/05_SASUKE_AND_SAKURA_ABILITIES.md`). Four defects were found on the way,
all fixed:

11. **Support moves were impossible to author.** The loader demanded `hitbox`,
    `damage`, `hitstun` and `blockstun` from every move, so a pure heal could
    never validate. Those four fields are now optional when `type` is `"support"`.
12. **`heal()` could over-report.** It now returns the HP actually restored, caps
    at `max_hp`, and refuses a fighter already at 0 HP — otherwise a healing form
    would have kept a corpse alive.
13. **`start_form()` requires solid ground.** A live-match test failed because the
    AI had jumped on that exact tick; the fighter correctly refused. The test now
    settles the fighter first — the behaviour is intended, the test was wrong.
14. **A fixture leaked into a shared directory.** Adding a second moveset fixture
    to `user://moveset_fixture` made the older "deliberately broken" fixture fail
    the new load. New fixtures get their own directory now.

## What is still unverified

* **Anything visual.** No renderer, no window, no screenshot. Layout, palette,
  frame-perfect animation timing and the 600-card scroll performance have never
  been seen by a human or by me.
* **Real input devices.** Tests drive fighters through `ScriptedIntent`; the
  keyboard/gamepad paths (`InputService`) are exercised only for binding
  label/persistence, never by actual key events.
* **Physical feel.** Hitstop, screen shake (default off), knockback tuning and
  the AI's difficulty are numbers in data, not experiences.
* **Balance.** Damage scaling from stats is new. Sasuke (atk 89) and Sakura
  (atk 80) hit harder than the stat-less dummies by design, but no human has
  played a round to say whether that feels right.
* **Persian rendering.** `fa.json` has full key parity, but the bundled font has
  no Arabic-script coverage, so those labels would render as boxes.

## Next

Abilities for ids 1–3 are done to the same standard; the next batch is id 4 and
onward, one character at a time. The art gate is unchanged and still blocked on
you: `characters.json` is still absent, no design is approved, and no final
animation frame exists for any character.
