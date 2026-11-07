# Approval log

Approvals are a human act and they are recorded **here, in the repository**,
never in the player save. The machine-readable form is
`assets/characters/approvals.json`; this page is the readable log.

Rule that does not change: an approval covers **the look of an artifact**. It
does not mean the engine already draws it. Anything still drawn by the procedural
rig keeps its on-screen `TEMP` tag until the approved art is rebuilt into sprites
and those sprites are approved too.

Rule learned the hard way: **only a `GRANTED` record unlocks anything.**
`REVOKED` records stay in the file as an audit trail, and the build tool ignores
them, so a correction can never be silently overridden by an old message.

## 001 — Naruto Uzumaki, state frames v1 — REVOKED (nothing is approved)

| Event | When | Statement |
|---|---|---|
| Granted | 2026-11-08 | «تصاویر تایید شدن» |
| Withdrawn | 2026-11-08 | «تصویرای انیمیشن تایید نشد» |

The user first said the images were approved, then corrected it: the **animation
images are not approved**. The repository follows the correction:

* `assets/characters/approvals.json` — record `001_naruto_state_frames_v1` is kept
  with `status: "REVOKED"`, `revokedOn`, `revokedBy`, and the verbatim revocation
  statement. It grants nothing.
* `assets/characters/states/index.json` — all five states back to
  `PROPOSAL_V1`, `designLocked: false`, `animationBlocked: true`, no
  `approvedOn`/`approvedBy`, and every sheet header back to
  `TEMP / NOT APPROVED`.
* `assets/characters/001_naruto/metadata/status.json` — `STATE_FRAMES_UNAPPROVED`,
  `designLocked: false`, `animationBlocked: true`, approval fields cleared.
* `assets/characters/concepts/index.json` — character 1 back to `CONCEPT_ONLY`
  (the concept was only ever approved as the shared design of the frames).
* `docs/07_STATE_FRAMES.md` — status section back to proposal.

Nothing else was deleted: the 19 frames, the five sheets, the five looping
previews and the overview are all still there, just labelled as proposals again.

## What the build tool enforces

`tools/build_state_index.py` derives lock state **only** from `approvals.json`
and only from `GRANTED` entries. `--check` fails when:

* a state is locked without a backing approval record,
* a state has animation unblocked without an approval,
* a listed frame, sheet, preview or overview is missing,
* `frameCount` does not match the frames on disk.

So the art cannot drift into "approved" by accident, and it cannot stay "approved"
after a correction like this one.
