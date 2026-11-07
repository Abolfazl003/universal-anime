#!/usr/bin/env bash
# Build normalised frame sheets and looping previews for the state reference art.
#
# The source frames are single generated images; this script is what turns them
# into something that can be read frame by frame:
#   * every frame is trimmed to the character and re-placed on a common canvas
#     with one shared ground line and one shared height, otherwise a flipbook
#     "jitters" even when the drawings are fine;
#   * <state>_frames.png is the ordered contact sheet with frame numbers;
#   * <state>_preview.gif is a ping-pong loop with morph in-betweens, which is a
#     PREVIEW of the motion only - it is not animation data and never ships.
#
# Usage:
#   tools/build_state_previews.sh assets/characters/states/001_naruto [state ...]
#   (no state names = every sub-directory that contains frame_*.png)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "usage: $0 <character-state-dir> [state ...]" >&2
  exit 2
fi
shift || true
if [[ ! -d "$ROOT/$TARGET" && ! -d "$TARGET" ]]; then
  echo "error: no such directory: $TARGET" >&2
  exit 2
fi
DIR="$TARGET"
[[ -d "$DIR" ]] || DIR="$ROOT/$TARGET"

BG="#a7998d"          # the shared studio background of every state frame
FRAME_H=660           # every character is normalised to this height in pixels
CELL_W=900            # wide enough that attack effects are not cut off
CELL_H=700
FPS_DELAY=6           # hundredths of a second per frame in the preview
MORPH=2               # in-between frames generated between two key frames

command -v convert >/dev/null || { echo "error: ImageMagick 'convert' missing" >&2; exit 2; }
command -v montage >/dev/null || { echo "error: ImageMagick 'montage' missing" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

normalise() { # normalise <in> <out>
  # The generated frames have a faint gradient in the studio background, which
  # leaves a visible rectangle when a frame is pasted onto a flat canvas. Flood
  # fill from the corner makes it transparent (only the connected region, so
  # nothing inside the character is touched).
  # Four corner fills, not one: when an attack effect loops around the body it
  # touches the border and cuts the background into regions that a single corner
  # fill never reaches (that is what left visible rectangles in the first pass).
  # Some generations draw a thin "floor" line at the very bottom edge. It is not
  # part of the character, it lands at a different height in every frame, and it
  # shows up as a stray horizontal rule in the cell - so shave the outer pixels
  # before anything else.
  local sw_raw sh_raw draw
  convert "$1" -shave 2x4 "$TMP/shaved.png"
  set -- "$TMP/shaved.png" "$2"
  sw_raw=$(identify -format "%w" "$1")
  sh_raw=$(identify -format "%h" "$1")
  draw="matte 0,0 floodfill matte $((sw_raw - 1)),0 floodfill"
  draw+=" matte 0,$((sh_raw - 1)) floodfill matte $((sw_raw - 1)),$((sh_raw - 1)) floodfill"
  convert "$1" -alpha set -fuzz 20% -fill none -draw "$draw" \
    -fuzz 8% -fill "$BG" -opaque 'srgb(167,153,141)' \
    -trim +repage "$TMP/t.png"
  # NB: `read < <(...)` returns non-zero at EOF (identify prints no newline) and
  # would kill the script under `set -e`, so sizes are read with command
  # substitution instead.
  local w h
  w=$(identify -format "%w" "$TMP/t.png")
  h=$(identify -format "%h" "$TMP/t.png")

  # Anchor on the FEET, not on the bounding box: attack frames carry a wide
  # effect on one side, so box-centring would slide the body sideways between
  # frames and the flipbook would jitter. The bottom eighth of the drawing is
  # the feet; its centre is the anchor that keeps the character planted.
  local strip_h=$(( h / 8 ))
  (( strip_h < 6 )) && strip_h=6
  convert "$TMP/t.png" -gravity South -crop "${w}x${strip_h}+0+0" +repage "$TMP/feet.png"
  local feet_geom feet_w feet_x
  feet_geom=$(convert "$TMP/feet.png" -fuzz 12% -trim -format "%wx%h%O" info:)
  feet_w=${feet_geom%%x*}
  feet_x=$(echo "$feet_geom" | sed -E 's/^[0-9]+x[0-9]+\+([0-9]+)\+.*/\1/')
  local feet_centre=$(( feet_x + feet_w / 2 ))

  convert "$TMP/t.png" -resize "x${FRAME_H}" "$TMP/scaled.png"
  local sh ox oy
  sh=$(identify -format "%h" "$TMP/scaled.png")
  ox=$(( CELL_W / 2 - feet_centre * sh / h ))
  oy=$(( CELL_H - sh ))
  convert -size "${CELL_W}x${CELL_H}" xc:"$BG" "$TMP/scaled.png" \
    -geometry "+${ox}+${oy}" -composite "$2"
}

header_for() { # header_for <state> -> banner text from index.json (TEMP unless approved)
  local index
  index="$(dirname "$DIR")/index.json"
  if [[ -f "$index" ]]; then
    python3 - "$index" "$DIR" "$1" <<'PY2' 2>/dev/null || true
import json, os, sys
index, char_dir, state = sys.argv[1], os.path.normpath(sys.argv[2]), sys.argv[3]
data = json.load(open(index, encoding="utf-8"))
for character in data.get("characters", []):
    for key, entry in character.get("states", {}).items():
        if key == state and entry.get("header"):
            print(entry["header"])
            raise SystemExit
print(f"TEMP / NOT APPROVED - {state.upper()} FRAMES (PROPOSAL v1)")
PY2
  else
    echo "TEMP / NOT APPROVED - $(echo "$1" | tr '[:lower:]' '[:upper:]') FRAMES (PROPOSAL v1)"
  fi
}

states=("$@")
if [[ ${#states[@]} -eq 0 ]]; then
  while IFS= read -r d; do states+=("$(basename "$d")"); done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

for state in "${states[@]}"; do
  # Raw generated frames live in <character>/_source/<state>/ and are git-ignored
  # (a single raw frame is ~1 MB). The normalised frames that this script writes
  # to <character>/<state>/frame_NN.png are the ones that ship in the repo.
  SRCDIR="$DIR/_source/$state"
  [[ -d "$SRCDIR" ]] || SRCDIR="$DIR/$state"
  mapfile -t frames < <(find "$SRCDIR" -maxdepth 1 -name 'frame_*.png' | sort)
  if [[ ${#frames[@]} -eq 0 ]]; then
    echo "skip $state (no frame_*.png)"
    continue
  fi

  # 1. normalise
  clean=()
  i=0
  for f in "${frames[@]}"; do
    i=$((i + 1))
    out="$TMP/$(printf '%02d.png' "$i")"
    normalise "$f" "$out"
    clean+=("$out")
  done
  mkdir -p "$DIR/$state"
  i=0
  for f in "${clean[@]}"; do
    i=$((i + 1))
    cp "$f" "$DIR/$state/$(printf 'frame_%02d.png' "$i")"
  done

  # 2. ordered contact sheet with frame numbers and an explicit TEMP banner
  # The normalised frames share one wide 900 px cell so attack effects are never
  # cut off and the ground line is identical. For the sheet that leaves a lot of
  # dead space, so each cell is cropped horizontally to its content (full height
  # kept, so the ground line stays put) before being laid out.
  tight=()
  for f in "${clean[@]}"; do
    trim_geom=$(convert "$f" -fuzz 12% -trim -format "%wx%h%O" info:)
    trim_w=${trim_geom%%x*}
    trim_x=$(echo "$trim_geom" | sed -E 's/^[0-9]+x[0-9]+\+([0-9]+)\+.*/\1/')
    pad=30
    crop_w=$(( trim_w + pad * 2 ))
    crop_x=$(( trim_x - pad ))
    (( crop_x < 0 )) && crop_x=0
    (( crop_x + crop_w > CELL_W )) && crop_w=$(( CELL_W - crop_x ))
    convert "$f" -crop "${crop_w}x${CELL_H}+${crop_x}+0" +repage "$TMP/tight_$(basename "$f")"
    tight+=("$TMP/tight_$(basename "$f")")
  done

  # -label must sit directly in front of the image it belongs to, otherwise
  # montage applies the last label to every cell.
  labeled=()
  i=0
  for f in "${tight[@]}"; do
    i=$((i + 1))
    labeled+=(-label "$(printf 'FRAME %02d' "$i")" "$f")
  done
  montage "${labeled[@]}" -tile "${#clean[@]}x1" \
    -geometry "+12+18" -background "$BG" \
    -fill '#f3ece2' -font DejaVu-Sans-Bold -pointsize 26 \
    "$TMP/sheet_body.png"
  banner=$(header_for "$state")
  accent=
  if [[ "$banner" == APPROVED* ]]; then accent='#7fd6a0'; else accent='#ffb347'; fi
  convert -size "$(identify -format '%w' "$TMP/sheet_body.png")"x64 xc:'#1d1a17' \
    -gravity West -fill "$accent" -font DejaVu-Sans-Bold -pointsize 30 \
    -annotate +20+0 "$banner" "$TMP/sheet_header.png"
  # 8-bit palette keeps the sheets readable and a quarter of the size; line art
  # with flat fills does not need 16-bit truecolour.
  convert "$TMP/sheet_header.png" "$TMP/sheet_body.png" -append -depth 8 -colors 192 \
    "PNG8:$DIR/${state}/${state}_frames.png"

  # 3. ping-pong preview with morph in-betweens (preview only, not data).
  # A single frame has nothing to loop, so the GIF is skipped instead of
  # producing a frozen still that pretends to be motion.
  if [[ ${#clean[@]} -lt 2 ]]; then
    echo "  (single frame: contact sheet only, no preview)"
    continue
  fi
  seq=("${clean[@]}")
  for ((j = ${#clean[@]} - 2; j >= 0; j--)); do seq+=("${clean[j]}"); done
  convert -delay "$FPS_DELAY" -loop 0 "${seq[@]}" -morph "$MORPH" \
    -resize 70% -colors 96 -dither None -layers Optimize "$DIR/${state}/${state}_preview.gif"

  echo "built ${state}: ${#clean[@]} frames -> ${state}_frames.png, ${state}_preview.gif"
done

# ---------------------------------------------------------------------------
# One overview per character: every state sheet stacked, so the whole state set
# can be judged in one look. Only built when at least two state sheets exist.
# ---------------------------------------------------------------------------
# Order matters: the overview reads in game order, not alphabetically.
sheets=()
for state in walk run light heavy special form ultimate; do
  [[ -f "$DIR/$state/${state}_frames.png" ]] && sheets+=("$DIR/$state/${state}_frames.png")
done
if [[ ${#sheets[@]} -ge 2 ]]; then
  parts=()
  for sheet in "${sheets[@]}"; do
    convert "$sheet" -resize 1600x -bordercolor '#1d1a17' -border 0x6 "$TMP/ov_$(basename "$sheet")"
    parts+=("$TMP/ov_$(basename "$sheet")")
  done
  convert "${parts[@]}" -append -depth 8 -colors 192 "PNG8:$DIR/state_overview.png"
  echo "overview: $DIR/state_overview.png (${#sheets[@]} state sheets)"
fi
