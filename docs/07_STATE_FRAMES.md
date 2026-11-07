# State frames — frame-by-frame proposals (NOT approved)

Started 2026-11-07. These are the "what does he look like while walking / running
/ casting" sheets: ordered frames per state, one shared camera, one shared ground
line, plus a looping preview so the motion can actually be read.

**Nothing is approved.** On 2026-11-08 the user first said the images were
approved and then corrected it — «تصویرای انیمیشن تایید نشد», the animation images
were *not* approved. The approval record was therefore revoked the same day (it
stays in `assets/characters/approvals.json` as an audit trail, marked `REVOKED`,
and grants nothing; see `docs/08_APPROVALS.md`).

Every state set is **proposal art** again: `status: PROPOSAL_V1`,
`designLocked: false`, `animationBlocked: true`, `TEMP / NOT APPROVED` banner on
every sheet. Lock state is derived from `approvals.json` only, never hand-typed,
and only `GRANTED` records count.

The in-game rig stays procedural regardless: an approval would cover the look of
the frames, not the engine. The `TEMP` tag in a match stays until these frames are
rebuilt into sprites and those sprites are approved.

## Where things live

```
assets/characters/states/
  001_naruto/
    walk/     frame_01..08.png  walk_frames.png      walk_preview.gif   (8, closed cycle)
    run/      frame_01..05.png  run_frames.png       run_preview.gif    (5 of 8)
    special/  frame_01..04.png  special_frames.png   special_preview.gif
    form/     frame_01..03.png  form_frames.png      form_preview.gif
    ultimate/ frame_01..04.png  ultimate_frames.png  ultimate_preview.gif
    state_overview.png          (all state sheets stacked, in game order)
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
   * flood-fill the studio background to transparency from **all four corners**
     (one corner is not enough: an attack effect that loops around the body cuts
     the background into regions the fill never reaches, which left visible
     rectangles in the first pass), then repaint the last background leftovers to
     the shared flat tone;
   * trim to the drawing, scale it to a constant 660 px height, and anchor it
     horizontally on **the centre of the feet**, not on the bounding box —
     otherwise a frame with a big effect on one side slides the body sideways and
     the flipbook jitters;
   * place it on a 900×700 cell (wide enough that effects are not cut off) with a
     shared ground line at the bottom;
   * for the contact sheet only, crop each cell back to its content so the strip
     is not three-quarters empty — the ground line and the character scale are
     untouched, only dead margin is removed;
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
| walk | **8 (loop)** | `walk_speed` 285 px/s, ground locomotion |
| run | **5 of 8** | `run_speed` 455 px/s |
| special (Rasengan) | 4 | 16 startup / 6 active / 20 recovery |
| form (Kurama Chakra Mode) | 3 | 26 cast frames, 600-tick duration |
| ultimate (Rasenshuriken) | 4 | 24 startup / 3 active / 32 recovery |

### In-betweens: what changed after the rejection

The first version had four *key* poses per cycle and nothing between them, and the
user rejected exactly that: «تصویرای انیمیشن تایید نشد» — it does not read as
motion. The fix is not "generate more images" but **how** the middle frames are
drawn:

* A fresh drawing from the concept always came back as a neutral standing pose,
  because the model had no idea where in the cycle it was. Asking for a subtle
  in-between from a text description does not work.
* An in-between is therefore generated as an **edit of the keyframe it follows**:
  the keyframe is the image input, and the prompt lists three numeric deltas
  ("lower the hips by 4% of body height", "peel the back heel off the floor",
  "arms hang slightly lower"). The model then keeps the character, costume,
  framing and line work and only shifts the pose, which is what an in-between is.

The walk cycle is now the standard 8-frame pattern and closes properly:
contact R → down → passing (L knee up) → up (reaching) → contact L → down →
passing (R knee up) → up (reaching) → loop.

Chronology matters and is not the order the images happen to be generated in.
Both ability sets were **reordered** after a first pass: the "sphere already
formed in the hand" frame was drawn first and had to become frame 2, after the
"small sphere gathering at the hip" frame. Sequence: gather → charge → release →
recover.

Once a state has enough frames, the mapping goes into `index.json`
(`movesetTiming`) automatically.

## What is good, what is not

Verified by eye this turn:

* **Walk cycle works.** Four frames that actually alternate: contact (right leg
  forward) → passing (left knee lifted, only the right foot down) → contact
  (opposite arm swing) → passing (right knee lifted, only the left foot down).
  The sheet and loop are in `walk/`.
* **Run cycle is half-way to eight.** It has 5 frames (contact R → compression R
  → push-off R → flight → contact L); the mirrored compression, push-off and
  flight for the left side were not generated because the 10-image turn limit ran
  out. Next batch finishes it.
* **All three ability states are animated now**: Rasengan 4 frames, Kurama
  Chakra Mode 3 frames, Rasenshuriken 4 frames, each with a contact sheet and a
  looping preview.
* **Two layout defects fixed in the assembler**, both found by looking at the
  sheets: single-corner flood fill left rectangular background patches, and
  box-centring made the body jump sideways between frames with wide effects.

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
4. **The test suite still cannot run.** The sandbox reset removed the local
   Godot binary and it is not downloadable from the allowed hosts; `gdlint`
   (parse check, reinstalled this session) is green, and no GDScript has changed
   since the last verified **429/429 at commit `f163966`**. The state-frame index
   is verified instead by `tools/build_state_index.py --check`, which fails on a
   missing frame, sheet or preview, a frame-count mismatch, or any approval
   claim that is not backed by `approvals.json`.
5. **Turn budget.** Ten generated images per turn is the hard ceiling, which is
   why an 8-frame cycle costs most of a turn and why the run cycle is 5 of 8.
6. **Approval ≠ engine.** No strips are approved. Even when one is, turning it
   into sprites (fixed pixel grid, per-frame hold times from the moveset numbers,
   hit-frame alignment) is a separate stage, and that is what would finally let
   the in-game `TEMP` tag come off.

## Next

1. Finish the run cycle to 8 frames, then bring `special`, `form` and `ultimate`
   up to 6–8 frames each so the ability states read as motion too.
2. Repeat the state frame pipeline for characters 002–005 (each has a concept to
   draw against), one character at a time, and get each approved the same way.
3. Build the engine-side gallery so these sheets can be reviewed inside the game
   instead of from the repository.
4. Add the state-frame checks to the GDScript suite (`data / state frame
   sequences`) as soon as the engine can run again, so `index.json` is covered by
   CI and not only by the Python `--check`.
