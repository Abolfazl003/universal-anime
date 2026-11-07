# Approval log

Approvals are a human act and they are recorded **here, in the repository**,
never in the player save. The machine-readable form is
`assets/characters/approvals.json`; this page is the readable log.

Rule that does not change: an approval covers **the look of an artifact**. It
does not mean the engine already draws it. Anything still drawn by the procedural
rig keeps its on-screen `TEMP` tag until the approved art is rebuilt into sprites
and those sprites are approved too.

## 001 — Naruto Uzumaki, state frames v1 — APPROVED

| Field | Value |
|---|---|
| Approval id | `001_naruto_state_frames_v1` |
| Date | 2026-11-08 |
| Given by | user |
| User's words | «تصاویر تایید شدن» |
| Character | id 1, Naruto Uzumaki |
| What was shown | the five state frame sets — walk (4 frames), run (4 frames), special/Rasengan (4), form/Kurama Chakra Mode (3), ultimate/Rasenshuriken (4) — each as a numbered contact sheet plus a looping preview |
| Covered artifacts | `assets/characters/states/001_naruto/{walk,run,special,form,ultimate}/` and `assets/characters/concepts/001_naruto_v2.png` |
| Locked | yes (`designLocked: true` for all five state sets and the concept) |
| Animation | unblocked (`animationBlocked: false`) — more frames may now be produced |

**Not covered by this approval:**

* the in-game art — the engine still draws the procedural rig, so the `TEMP` tag
  in a match is unchanged and correct;
* sprite sheets, pixel-perfect frames, hit-frame data, effects timing;
* characters 002–020, which remain `CONCEPT_ONLY` and unapproved;
* anything not listed under "Covered artifacts" above.

Where the approval shows up:

| Place | Change |
|---|---|
| `assets/characters/approvals.json` | new record `001_naruto_state_frames_v1` |
| `assets/characters/states/index.json` | every state of character 1 becomes `APPROVED_V1`, `designLocked: true`, `animationBlocked: false`, with `approvedOn`, `approvedBy`, `approvalId`, and an `APPROVED v1` sheet header |
| `assets/characters/001_naruto/metadata/status.json` | `STATE_FRAMES_APPROVED`, `designLocked: true`, `designApprovedBy/On` filled, `animationBlocked: false` |
| `assets/characters/concepts/index.json` | character 1 concept is `APPROVED_V1` (it is the design every approved frame shares) |
| every `<state>_frames.png` | banner switches from `TEMP / NOT APPROVED` to green `APPROVED v1 - 2026-11-08` |

The pipeline enforces this rather than trusting memory: `tools/build_state_index.py`
derives lock state **only** from `approvals.json`, and its `--check` mode fails if
a state is locked without an approval record, or unblocked without one.
