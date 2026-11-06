# Character 001 — Naruto Uzumaki (reference gate)

**Status: `REFERENCE_PENDING` — step 1 (reference review) is now done with real
images; step 2 (design proposal) is being shown to you; step 5 (approval) has
NOT happened, so nothing is locked and no animation exists.**

## Pipeline position

| Step | State |
|---|---|
| 1. Review valid references | **DONE** — six images pulled, two judged usable and viewed in full (see below) |
| 2. Produce a design proposal | **shown for review** (not final, not locked) |
| 3. Show the image to the user | yes — the proposal is displayed, not just linked |
| 4. Revision | waiting on your corrections |
| 5. Explicit user approval | **not given** |
| 6. Design lock | **not locked** (`designLocked: false`) |
| 7. Animation production | **not started** (forbidden before step 5) |

The in-game fighter art is still a **procedural placeholder** labelled `TEMP` on
screen. The proposal image is a concept for discussion; it is not a sprite sheet,
not a rig, and not an approved design.

## Sources actually opened in this session

| Source | URL | What was used | Image viewed |
|---|---|---|---|
| Narutopedia (Fandom) | https://naruto.fandom.com/wiki/Naruto_Uzumaki | page text (Appearance / Abilities sections, contents) | **no** |
| Heroes Wiki (Fandom) | https://hero.fandom.com/wiki/Naruto_Uzumaki | text excerpt cross-checking the Part II outfit | **no** |
| Character profile (Fandom) | https://saint-knights.fandom.com/wiki/Naruto_Uzumaki | text confirming Part I vs Part II differences | **no** |

Earlier in the session `imageSearch` returned nothing and image hosts were
unreachable. **That is no longer true**: image search worked on 2026-11-07 and the
two references below were downloaded and opened, at full size, in this session.

## Images actually viewed (2026-11-07)

| # | Source | URL | What it is | Verdict |
|---|---|---|---|---|
| A | Pinterest board "Naruto design sheets" (production model sheet, Japanese) | https://pinterest.com/ivyrose00/naruto-design-sheets | Official-style **character setting sheet**: front / three-quarter / side / back turnaround, hands, sandal and bag detail, height marker, annotations. Long coat, forehead protector, arm pouch. | **usable for proportions, silhouette, face, hand and foot construction** — but it is the **blank-period / *The Last*** outfit, not the Shippuden tracksuit |
| B | best-wallpaper.net, *Naruto Shippuden* HD | https://ja.best-wallpaper.net/naruto-shippuden-hd_wallpapers.html | Coloured Shippuden-era render, strong foreshortened pose, official-looking shading | **usable for the Shippuden palette and costume read** (orange jacket with black shoulders/zip, black headband cloth, orange trousers, grey knee holster); **not** usable for proportions — the perspective distorts everything |

Rejected on sight:

* `naruto-uzumaki-shippuden-full-body-chara-3.jpg` — fan re-imagining with goggles,
  blue/orange varsity jacket and branded sneakers. Not the canon design.
* two further search hits that were a Reddit sketch and a figure listing, neither
  of which is a usable turnaround.

**Known gap:** I have still **not** seen a *Shippuden-specific* official
turnaround (front/side/back at neutral). Reference A gives me the construction,
reference B gives me the costume colours, and the two together are not the same
document. If you have the 疾風伝 設定画 for Naruto, that would close the gap
properly; otherwise the proposal extrapolates between them and I will say exactly
where it does.

**No reference image is redistributed in this repository.** The downloaded files
live outside the project (`/home/user/reference-material/`) and are git-ignored,
per the rule that no copyrighted art is packaged with the game.

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

1. **Approval or corrections on the shown proposal** (step 4/5). If you have a
   Shippuden setting sheet, adding it would remove the extrapolation described
   above; the dungeon top-down views (idle + walk, 4 directions) still need to be
   designed either way.
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
