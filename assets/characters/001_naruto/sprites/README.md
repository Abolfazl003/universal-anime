# 001 / sprite frames

One folder per animation clip (`idle/`, `walk/`, ...) with a fixed canvas and a
shared foot-contact pivot. Empty: no frame may be produced before design lock.

Rules once populated: constant canvas size, constant foot contact, no extra
limbs, no proportion drift between frames, fps recorded in
`resources/animations/001_naruto.json` (never in the scene).
