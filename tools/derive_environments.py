#!/usr/bin/env python3
"""Derive an environment index from the character dataset.

The dataset describes a city, a world and an architecture string for every
character, but contains no artwork and no stage definitions. This tool turns
those descriptive fields into a stable, regenerable index that the game can use
for stage selection, palette theming and future art briefs.

It never invents a city, a world or an architecture line: every string in the
output is copied from the source record. Palettes are deterministic
derivations of the world name, marked as such, and are not art.

Usage:
    python3 tools/derive_environments.py [source.json] [output.json]
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data" / "characters.local.json"
OUTPUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "data" / "environments" / "derived.json"


def palette_for(name: str) -> dict:
    digest = hashlib.sha256(name.encode("utf-8")).digest()
    hue = digest[0] / 255.0
    return {
        "hue": round(hue, 3),
        "sky": _hsl_hex(hue, 0.35, 0.22),
        "mid": _hsl_hex((hue + 0.04) % 1.0, 0.30, 0.42),
        "accent": _hsl_hex((hue + 0.5) % 1.0, 0.55, 0.62),
        "ground": _hsl_hex((hue + 0.02) % 1.0, 0.25, 0.16),
        "derived": True,
    }


def _hsl_hex(h: float, s: float, l: float) -> str:
    def f(n: float) -> float:
        k = (n + h * 12) % 12
        a = s * min(l, 1 - l)
        return l - a * max(-1, min(k - 3, min(9 - k, 1)))

    r, g, b = (int(round(f(n) * 255)) for n in (0, 8, 4))
    return "#%02x%02x%02x" % (r, g, b)


def main() -> int:
    records = json.loads(SOURCE.read_text(encoding="utf-8"))
    worlds: dict = {}
    for record in records:
        world = str(record.get("world", "")).strip()
        city = str(record.get("city", "")).strip()
        series = str(record.get("anime", record.get("series", ""))).strip()
        if not world or not city:
            continue
        entry = worlds.setdefault(world, {"world": world, "series": [], "cities": [], "characters": 0})
        if series and series not in entry["series"]:
            entry["series"].append(series)
        entry["characters"] += 1
        entry["cities"].append(
            {
                "city": city,
                "architecture": str(record.get("architecture", "")).strip(),
                "characterId": int(record.get("id", -1)),
                "characterName": str(record.get("name", "")).strip(),
            }
        )

    ordered = sorted(worlds.values(), key=lambda w: (-w["characters"], w["world"]))
    for index, entry in enumerate(ordered, start=1):
        entry["id"] = "world_%03d" % index
        entry["series"].sort()
        entry["cities"].sort(key=lambda c: c["city"])
        entry["palette"] = palette_for(entry["world"])
        entry["stageStatus"] = "ENVIRONMENT_DATA_ONLY"

    payload = {
        "schemaVersion": 1,
        "kind": "derived_environment_index",
        "generatedFrom": {
            "path": str(SOURCE.relative_to(ROOT)) if SOURCE.is_relative_to(ROOT) else str(SOURCE),
            "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        },
        "note": (
            "Derived, not authored. Every city, world and architecture string is copied from the "
            "character dataset; palettes are deterministic hashes of the world name. This is not art "
            "and not an approved stage set: stageStatus stays ENVIRONMENT_DATA_ONLY until a stage is "
            "designed, shown and approved."
        ),
        "totals": {
            "worlds": len(ordered),
            "cities": sum(len(w["cities"]) for w in ordered),
            "series": len({s for w in ordered for s in w["series"]}),
        },
        "worlds": ordered,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("wrote %s: %d worlds, %d cities" % (OUTPUT.relative_to(ROOT), payload["totals"]["worlds"], payload["totals"]["cities"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
