# Tests

Headless test suite. It drives the real fighters, the real combat manager, the
real save manager and instantiates the real scenes — nothing is mocked except
input, which is provided by a scripted intent source.

```bash
godot --headless --path . res://tests/test_runner.tscn
echo $?   # 0 = all checks passed
```

Coverage:

| Suite | What it proves |
|---|---|
| `test_data.gd` | validator (duplicate ids, missing fields), character store honesty, 650-record query/paging capacity, moveset frame data, animation fps metadata, stage approval status, every UI localization key exists, every scene resource loads |
| `test_combat.gd` | state table consistency, tick input buffer expiry, startup/active windows, one-hit-per-attack rule, explicit multi-hit phases, block chip/blockstun, projectile damage-once, energy and meter costs, ground anchor |
| `test_dungeon.gd` | seeded determinism, connectivity to the boss, room types, data-driven enemies/loot, dungeon scene instantiation with doors and player |
| `test_ui_save.gd` | save round-trip, corrupt-save recovery, safe defaults, input map + rebinding, character-select paging with a 650-record fixture, versus scene round flow |

What the tests **cannot** prove: face/hair/costume fidelity or anatomy quality.
Those require human review of approved art — as stated in the design rules.
