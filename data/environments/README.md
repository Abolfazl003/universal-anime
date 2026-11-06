# Environments (derived index)

`derived.json` is **generated, not authored**. It exists because the character
dataset already describes a place for every one of its 500 records — a `world`, a
`city` and an `architecture` line — and none of it is usable by the engine while
it sits inside character records.

Regenerate with:

```bash
python3 tools/derive_environments.py
```

## What it contains

* 180 worlds, 500 cities, 90 series (measured, not estimated).
* Every world entry: id, world name, the series that use it, its cities with the
  source architecture line, the character id/name that owns each city, a
  deterministic palette, and `stageStatus`.
* Totals block, plus a `generatedFrom` block with the source path and its sha256,
  so the index can be proven to match the dataset it came from.

## What it is not

* **Not art.** No stage has been designed, drawn or approved. Every entry is
  `ENVIRONMENT_DATA_ONLY`.
* **Not invented.** City, world and architecture strings are copied verbatim.
  Palettes are a hash of the world name, flagged `"derived": true`; they are a
  theming hint, not a colour script.
* **Not a stage set.** `data/stages/*.json` remains the only thing the stage
  loader reads. This index feeds stage *selection* and art briefs once a stage is
  approved.

## The rule for turning one of these into a real stage

1. Pick a world or city from this index.
2. Write a stage brief (camera framing, floor line, parallax layers, palette).
3. Show the proposal to the user; revise.
4. Only after explicit approval: build the stage, bind it in `data/stages/`, QA.
5. Stage status goes `ENVIRONMENT_DATA_ONLY → ENVIRONMENT_PROPOSED →
   ENVIRONMENT_APPROVED → ENVIRONMENT_IMPLEMENTED`.
