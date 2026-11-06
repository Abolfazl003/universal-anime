# Character 001 — Naruto Uzumaki (reference gate)

**Status: `REFERENCE_PENDING` — blocked at step 1 of the pipeline.**

## Pipeline position

| Step | State |
|---|---|
| 1. Review valid references | **BLOCKED** — no image could be retrieved or displayed in this environment |
| 2. Produce a design proposal | not started (not allowed before step 1) |
| 3. Show the image to the user | nothing to show yet |
| 4. Revision | — |
| 5. Explicit user approval | — |
| 6. Design lock | **not locked** |
| 7. Animation production | **not started** (forbidden before step 5) |

No frame was generated. No image was inspected. The in-game fighter art is a
**procedural placeholder** that is labelled `TEMP` on screen; it is not a
Naruto design.

## Sources actually opened in this session

| Source | URL | What was used | Image viewed |
|---|---|---|---|
| Narutopedia (Fandom) | https://naruto.fandom.com/wiki/Naruto_Uzumaki | page text (Appearance / Abilities sections, contents) | **no** |
| Heroes Wiki (Fandom) | https://hero.fandom.com/wiki/Naruto_Uzumaki | text excerpt cross-checking the Part II outfit | **no** |
| Character profile (Fandom) | https://saint-knights.fandom.com/wiki/Naruto_Uzumaki | text confirming Part I vs Part II differences | **no** |

`imageSearch` was attempted and returned no images; binary downloads from image
hosts were unreachable. See `data/references.json` for the machine-readable list.

## Version decision (proposed, awaiting confirmation)

**Naruto Shippuden (Part II), default outfit**, before the Pain-arc coat.

Explicitly excluded from this design (must not be mixed in):

* Part I outfit (blue shoulder/waist panels, blue headband, goggles)
* Pain-arc short-sleeved red coat with flame hem and summoning scroll
* Nine-Tails / Kurama Chakra Mode and Six Paths Sage Mode (separate forms that
  need their own reference + approval)
* Blank period / The Last / Hokage-era outfits

## What the text sources say (to be confirmed against images)

* Orange, form-fitting tracksuit jacket; black colouring starts at the collar,
  covers shoulders and sleeves and runs down the front zip; also wraps the waist
  and half of the back.
* White circular design on the left shoulder (no tassel in Part II); red
  Uzumaki swirl on the back.
* Plain white T-shirt at the neckline; orange trousers with a shuriken holster on
  the right knee; black ankle-height shinobi sandals.
* Long black forehead-protector bandanna (metal plate worn at the front).
* Blond spiky hair, blue eyes, three whisker marks on each cheek, fair/tan skin.
* Part II proportions: ≈166 cm, lean build.

## Power names from the brief (kept verbatim)

`Rasengan` · `Kurama Chakra Mode` · `Tailed Beast Rasenshuriken`

The brief says these come from `characters.json`. That file is **not in the
repository**, so the game does not claim these are the record's exact strings.
Once the file is present the loader copies power names verbatim.

## What is needed from you to unblock

1. Reference images, placed in `assets/characters/001_naruto/references/`
   (or links that can be opened):
   * front, side, back, three-quarter
   * at least one full-body neutral pose
   * the dungeon-camera views (top-down idle + walk, 4 directions)
2. Answers to the open questions:
   * exact arc for the default version?
   * keep the Pain-arc coat out, or plan it as a separate costume?
   * which Rasengan variant should the special use?
   * should Kurama Chakra Mode be a transformation with its own animation set, or
     an Ultimate-only visual?
   * are minor non-canon liberties acceptable (fabric folds, exact hand shapes)?
3. After the proposal is shown: explicit approval, or a list of corrections.

Only then: design lock → reference sheet → animation → moveset → both cameras →
QA → `PLAYABLE`.
