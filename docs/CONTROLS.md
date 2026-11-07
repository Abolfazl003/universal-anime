# Controls

Every action is registered at runtime by `InputService` and can be rebound in
**Main menu → Controls** (saved to your profile). Gamepad bindings are kept when
a keyboard binding is changed.

## Versus / mechanics lab

| Action | Player 1 | Player 2 | Gamepad 1 | Gamepad 2 |
|---|---|---|---|---|
| Move | `A` / `D` | `←` / `→` | left stick | left stick |
| Jump | `W` | `↑` | A | A |
| Crouch | `S` | `↓` | B | B |
| Light attack | `J` | `Numpad 1` | X | X |
| Heavy attack | `K` | `Numpad 2` | Y | Y |
| Block | `L` (hold) | `Numpad 3` (hold) | LB | LB |
| Special | `U` | `Numpad 4` | RB | RB |
| Ultimate | `I` | `Numpad 5` | R3 | R3 |
| Transform (form) | `O` | `Numpad 6` | L3 | L3 |
| Pause | `Esc` | `Esc` | Start | Start |

`Transform` only does something on a character whose moveset declares a `forms`
block (currently character 001, Kurama Chakra Mode). It is refused while a form is
already active or when the energy cost cannot be paid.

## Dungeon

| Action | Binding |
|---|---|
| Move (8 directions) | `WASD` / arrows (player 1 bindings) |
| Attack | `J` (light) or `K` (heavy) |
| Special shot | `U` (costs 25 energy) |
| Block | `L` (hold — reduces damage to 30%) |
| Pause | `Esc` |

## Menus

Standard Godot UI actions: arrows / D-pad / left stick to move focus, `Enter` or
`Space` or gamepad **A** to confirm, `Esc` / gamepad **B** to go back.

## Debug

| Key | Effect |
|---|---|
| `F3` | Debug overlay: FPS, physics rate, scene, mode, fighter states, hitbox count, object/node counts, memory, save status, roster counts |
| `F4` | Draw hitboxes (red) and hurtboxes (green) on every fighter |
| `F6` | Toggle 0.25× slow motion (useful with the animation review tool) |
