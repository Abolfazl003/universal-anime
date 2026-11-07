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
CELL_W=420
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
  # nothing inside the character is touched), then the frame is trimmed, scaled
  # to the shared height and placed on the shared ground line.
  convert "$1" -alpha set -fuzz 12% -fill none -draw 'matte 0,0 floodfill' \
    -trim +repage -resize "x${FRAME_H}" \
    -background "$BG" -gravity South -extent "${CELL_W}x${CELL_H}" -flatten "$2"
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
  # -label must sit directly in front of the image it belongs to, otherwise
  # montage applies the last label to every cell.
  labeled=()
  i=0
  for f in "${clean[@]}"; do
    i=$((i + 1))
    labeled+=(-label "$(printf 'FRAME %02d' "$i")" "$f")
  done
  montage "${labeled[@]}" -tile "${#clean[@]}x1" \
    -geometry "${CELL_W}x${CELL_H}+12+18" -background "$BG" \
    -fill '#f3ece2' -font DejaVu-Sans-Bold -pointsize 26 \
    "$TMP/sheet_body.png"
  convert -size "$(identify -format '%w' "$TMP/sheet_body.png")"x64 xc:'#1d1a17' \
    -gravity West -fill '#ffb347' -font DejaVu-Sans-Bold -pointsize 30 \
    -annotate +20+0 "TEMP / NOT APPROVED - $(echo "$state" | tr '[:lower:]' '[:upper:]') FRAMES (PROPOSAL v1)" \
    "$TMP/sheet_header.png"
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
