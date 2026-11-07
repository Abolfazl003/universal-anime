# State frames — frame-by-frame proposals (NOT approved)

Started 2026-11-07. These are the "what does he look like while walking / running
/ casting" sheets: ordered frames per state, one shared camera, one shared ground
line, plus a looping preview so the motion can actually be read.

Everything here is **proposal art**. Every entry in
`assets/characters/states/index.json` is `status: PROPOSAL_V1`,
`designLocked: false`, `animationBlocked: true`, and every sheet carries a
`TEMP / NOT APPROVED` banner. The in-game rig stays procedural until a sequence
is approved by you.

## Where things live

```
assets/characters/states/
  001_naruto/
    walk/  frame_01..04.png  walk_frames.png  walk_preview.gif
    run/   frame_01..04.png  run_frames.png   run_preview.gif
    special/ form/ ultimate/   (frame_01 only so far)
  index.json          <- generated manifest, see tools/build_state_index.py
```

Naming rule: `frame_NN.png` in reading order, zero-padded, one folder per state.
State folder names match the moveset: `walk`, `run`, `light`, `heavy`, `special`,
`ultimate`, `form`.

The committed `frame_NN.png` files are the **normalised** frames (420x700, shared
ground line). The raw generations are kept in `<character>/_source/<state>/` and
are **git-ignored**: one raw frame is ~1 MB, and the repo does not need the extra
resolution for reference art. Per character the committed state art is roughly
4 MB (9 normalised frames, 5 sheets, 2 looping previews), which is the budget we
are holding to.

## The pipeline (two scripts, both re-runnable)

1. **Frames are drawn one state at a time**, each frame generated against the
   character's approved-style *concept* (`assets/characters/concepts/`), never
   against the previous frame — chaining frames makes the model copy the previous
   pose and the cycle stops moving. This was the first real lesson: frame 2 of the
   walk came back identical to frame 1 when it was drawn from frame 1.
2. **`tools/build_state_previews.sh <character-dir> [state…]`** normalises and
   assembles:
   * flood-fill the studio background to transparency from the corner (the
     generated frames have a faint gradient, which otherwise shows as a visible
     rectangle when pasted onto a shared canvas);
   * trim to the character, scale every frame to the same 660 px height, place it
     on a 420×700 cell with a shared ground line at the bottom;
   * `<state>_frames.png` — ordered contact sheet, labelled `FRAME 01…NN`, with
     the `TEMP / NOT APPROVED` header;
   * `<state>_preview.gif` — ping-pong loop with 2 morph in-betweens per pair,
     6/100 s per frame, only built when a state has 2+ frames.
3. **`tools/build_state_index.py [--check]`** regenerates `index.json` from disk
   and verifies it: every listed frame, sheet and preview exists, `frameCount`
   matches, every animation has a preview, and no entry claims an approval it
   does not have. `--check` exits non-zero when anything drifts.

## Timing, tied to the real moveset numbers

The sheets are art, but their *intent* is the timing already in
`data/movesets/001_naruto.json`, so the frames line up with what the engine does:

| State | Frames now | Engine timing it must cover |
|---|---|---|
| walk | 4 (loop) | `walk_speed` 285 px/s, ground locomotion |
| run | 4 (loop) | `run_speed` 455 px/s |
| special (Rasengan) | 1 | 16 startup / 6 active / 20 recovery |
| form (Kurama Chakra Mode) | 1 | 26 cast frames, 600-tick duration |
| ultimate (Rasenshuriken) | 1 | 24 startup / 3 active / 32 recovery |

Once a state has enough frames, the mapping goes into `index.json`
(`movesetTiming`) automatically.

## What is good, what is not

Verified by eye this turn:

* **Walk cycle works.** Four frames that actually alternate: contact (right leg
  forward) → passing (left knee lifted, only the right foot down) → contact
  (opposite arm swing) → passing (right knee lifted, only the left foot down).
  The sheet and loop are in `walk/`.
* **Run cycle is half-baked.** Frame 01 (push-off) and frame 03 (flight) read
  well, but frames 02 and 04 came back nearly identical to the flight poses
  instead of the planted-foot contact poses the prompts asked for, so the loop
  reads more like a hover than a sprint. **This is an open defect**, not a
  design decision; it gets another pass next batch.
* **The ability states have a single frame each** so far (the pose itself is
  good: hand thrusting the Rasengan, the Kurama aura, the raised Rasenshuriken).
  They are not animation yet and no GIF is generated for them, by design.

## Honest limits

1. **Text-to-image does not give frame-accurate sequences.** It re-draws the
   character each time: costume details drift (a red crest appeared on the
   jacket twice and was prompt-suppressed), proportions move a few percent
   between frames, and precise sub-poses ("left thigh horizontal, knee at 90°")
   are only sometimes obeyed. Strong, *large* pose changes are followed; subtle
   ones are flattened.
2. **The GIF is a preview, not animation data.** It interpolates with morphs. It
   shows whether the *silhouettes* flow; it is not something the game plays, and
   it is never imported into the project.
3. **Nothing here is in the game.** The engine still draws the procedural rig.
   Real skeletons/sprites are the next stage and they need an approved design
   first.
4. **The test suite was not run this turn.** The sandbox was reset between
   turns, which removed the local Godot binary (it is not downloadable from the
   allowed hosts) and the git index. No GDScript was changed in this turn — only
   assets, docs and two new tools — so the suite still stands at the last
   verified run, **429/429 at commit `f163966`**. `gdlint` (script parse check)
   is green. This is a verification gap to close the moment the engine binary is
   back.

## Next

1. Re-draw `run/frame_02` and `run/frame_04` as real planted-foot contacts, and
   add the missing passing frame so the cycle closes properly.
2. Fill the ability states: `special` (gather → thrust → impact → recover),
   `form` (activation → aura → sustained), `ultimate` (gather → overhead →
   throw → follow-through).
3. Then repeat for characters 002–005 (each has a concept to draw against) and
   keep going down the roster.
4. Add the state-frame checks to the GDScript suite (`data / state frame
   sequences`) as soon as the engine can run again, so `index.json` is covered by
   CI and not only by the Python `--check`.
