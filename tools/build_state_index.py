#!/usr/bin/env python3
"""Rebuild assets/characters/states/index.json from the files on disk.

The state frame art is reference material, never game data: this index only
records what exists, how many frames each sequence has, whether it loops, and -
for ability states - which part of the moveset timing each sequence is meant to
cover. Every entry stays unapproved by construction; approval is a human act and
is recorded separately (see docs/07_STATE_FRAMES.md).

Usage: python3 tools/build_state_index.py [--check]
    --check  exit 1 if the file on disk is out of date (used by the test suite)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATES_DIR = ROOT / "assets" / "characters" / "states"
INDEX = STATES_DIR / "index.json"
MOVESETS = ROOT / "data" / "movesets"
APPROVALS = ROOT / "assets" / "characters" / "approvals.json"

# state folder -> moveset move/for it describes, or None for locomotion
STATE_MOVES = {
    "walk": None,
    "run": None,
    "light": "light_attack",
    "heavy": "heavy_attack",
    "special": "special",
    "ultimate": "ultimate",
    "form": "form",
}
LOOPING = {"walk", "run"}
STATE_LABELS = {
    "walk": "walk cycle",
    "run": "run cycle",
    "light": "light attack",
    "heavy": "heavy attack",
    "special": "special",
    "ultimate": "ultimate",
    "form": "transformation",
}


def load_approvals() -> dict[int, list[dict]]:
    """Character id -> list of approval records (empty when nothing is approved)."""
    if not APPROVALS.exists():
        return {}
    data = json.loads(APPROVALS.read_text(encoding="utf-8"))
    by_character: dict[int, list[dict]] = {}
    for entry in data.get("approvals", []):
        # Only a GRANTED record unlocks anything. A revoked (or status-less)
        # record is kept for the audit trail but grants nothing.
        if str(entry.get("status", "")).upper() != "GRANTED":
            continue
        by_character.setdefault(int(entry.get("characterId", 0)), []).append(entry)
    return by_character


def approval_for(records: list[dict], state: str) -> dict | None:
    for record in records:
        if state in record.get("states", []):
            return record
    return None


def character_name(character_dir: str) -> str:
    parts = character_dir.split("_", 1)
    return parts[1].replace("_", " ").title() if len(parts) > 1 else character_dir


def moveset_for(character_dir: str) -> dict:
    path = MOVESETS / f"{character_dir}.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def build() -> dict:
    approvals = load_approvals()
    characters = []
    for character_dir in sorted(p for p in STATES_DIR.iterdir() if p.is_dir()):
        states = {}
        moveset = moveset_for(character_dir.name)
        moves = moveset.get("moves", {})
        forms = moveset.get("forms", {})
        for state_dir in sorted(p for p in character_dir.iterdir() if p.is_dir()):
            frames = sorted(state_dir.glob("frame_*.png"))
            if not frames:
                continue
            state = state_dir.name
            timing = None
            move_key = STATE_MOVES.get(state, "special")
            if state == "form" and forms:
                form = next(iter(forms.values()))
                timing = {"kind": "form", "cast_frames": form.get("cast_frames"),
                          "duration_frames": form.get("duration_frames")}
            elif move_key and move_key in moves:
                move = moves[move_key]
                timing = {"kind": "move", "move": move_key,
                          "startup": move.get("startup"), "active": move.get("active"),
                          "recovery": move.get("recovery")}
            granted = approval_for(approvals.get(int(character_dir.name.split("_", 1)[0]), []), state)
            states[state] = {
                "label": STATE_LABELS.get(state, state),
                "frames": [str(f.relative_to(ROOT)) for f in frames],
                "frameCount": len(frames),
                "loop": state in LOOPING,
                "sheet": f"{state_dir.relative_to(ROOT)}/{state}_frames.png",
                "preview": (f"{state_dir.relative_to(ROOT)}/{state}_preview.gif"
                            if len(frames) > 1 else None),
                "movesetTiming": timing,
                "status": "APPROVED_V1" if granted else "PROPOSAL_V1",
                "designLocked": bool(granted),
                "animationBlocked": not bool(granted),
                "approvedOn": granted.get("approvedOn") if granted else None,
                "approvedBy": granted.get("approvedBy") if granted else None,
                "approvalId": granted.get("id") if granted else None,
                "header": (
                    f"APPROVED v1 - {granted.get('approvedOn')} - {state.upper()} FRAMES "
                    f"(user approval: {granted.get('id')})"
                    if granted
                    else f"TEMP / NOT APPROVED - {state.upper()} FRAMES (PROPOSAL v1)"
                ),
            }
        if states:
            overview = character_dir / "state_overview.png"
            characters.append({
                "characterId": int(character_dir.name.split("_", 1)[0]),
                "overview": str(overview.relative_to(ROOT)) if overview.exists() else None,
                "characterName": character_name(character_dir.name),
                "moveset": f"data/movesets/{character_dir.name}.json",
                "states": states,
            })
    return {
        "schemaVersion": 1,
        "kind": "state_frame_sequences",
        "note": ("Frame-by-frame state proposals. Generated art, not approved, not locked, "
                 "not game data. The <state>_preview.gif files are motion PREVIEWS built with "
                 "morph in-betweens and never ship in the game. The in-game rig is still "
                 "procedural until a sequence is approved."),
        "frameNormalisation": {"heightPx": 660, "cellWidth": 420, "cellHeight": 700,
                               "background": "#a7998d",
                               "groundLine": "shared across every frame of a character"},
        "characters": characters,
    }


def validate(data: dict) -> list[str]:
    """Every file the index promises has to exist, and nothing may claim approval."""
    problems: list[str] = []
    for character in data["characters"]:
        if character.get("overview") and not (ROOT / character["overview"]).exists():
            problems.append(f"missing overview: {character['overview']}")
        for state, entry in character["states"].items():
            for frame in entry["frames"]:
                if not (ROOT / frame).exists():
                    problems.append(f"missing frame: {frame}")
            if entry["frameCount"] != len(entry["frames"]):
                problems.append(f"{character['characterId']}/{state}: frameCount mismatch")
            if not (ROOT / entry["sheet"]).exists():
                problems.append(f"missing contact sheet: {entry['sheet']}")
            if entry["preview"] and not (ROOT / entry["preview"]).exists():
                problems.append(f"missing preview: {entry['preview']}")
            if entry["frameCount"] > 1 and not entry["preview"]:
                problems.append(f"{character['characterId']}/{state}: animation has no preview")
            if entry["designLocked"] and not entry.get("approvalId"):
                problems.append(f"{character['characterId']}/{state}: locked without an approval record")
            if not entry["designLocked"] and not entry["animationBlocked"]:
                problems.append(f"{character['characterId']}/{state}: animation unblocked without approval")
    return problems


def main() -> int:
    data = build()
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    problems = validate(data)
    if "--check" in sys.argv:
        current = INDEX.read_text(encoding="utf-8") if INDEX.exists() else ""
        if current != text:
            problems.append("state index is out of date; run tools/build_state_index.py")
        if problems:
            for problem in problems:
                print(problem)
            return 1
        print("state index is up to date and consistent")
        return 0
    for problem in problems:
        print(f"warning: {problem}")
    INDEX.write_text(text, encoding="utf-8")
    total = sum(len(c["states"]) for c in data["characters"])
    print(f"wrote {INDEX.relative_to(ROOT)}: {len(data['characters'])} characters, {total} states")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
