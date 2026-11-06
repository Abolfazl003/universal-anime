# Character extensions

Supplemental information that is **not** in `characters.json` lives here, one
file per character, always with provenance. Nothing in this folder is allowed to
contradict the source file: if a value disagrees, the source file wins and the
conflict is reported.

Required fields: `characterId`, `source`, `retrieved`, `data`.
Files starting with `_` are examples and are ignored by the loader.
