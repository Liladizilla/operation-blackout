# OPERATION BLACKOUT: FIRST LIGHT

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone
- Aim-down-sights field-of-view change, breathing/strafe sway, recoil, and brief muzzle illumination
- Assault rifle firing, raycast hit detection, ammunition and reloads
- Basic hostile AI: line-of-sight detection, pursuit/strafe, last-known-position investigation, cover repositioning, and hitscan return fire
- Health and directional damage feedback, headshot-aware hit confirmation, hold-to-recover intel objective gated behind enemy clearance, pause menu, and mission-complete/replay screen
- Layered window bays, facade trim, side-wall details, service doors, and lightweight drifting battlefield smoke
- Godot Compatibility renderer for integrated graphics

## Requirements

- Godot 4.x stable
- Linux or Windows
- No external asset downloads required for this prototype

## Run

1. Download or clone this repository.
2. Open `project.godot` in Godot 4.x.
3. Press **F6** to run the main scene or **F5** to run the project.
4. Click the game window to capture the mouse.

## Controls

- **WASD**: move
- **Mouse**: look
- **Left mouse**: fire
- **Right mouse**: aim down sights
- **Shift**: sprint
- **Ctrl**: crouch toggle
- **Z**: prone toggle
- **Space**: jump
- **R**: reload
- **F**: interact / recover intel
- **Esc**: pause / release mouse

## Current limits

This is a foundation, not the finished game. Combatants use procedural meshes and inexpensive logic. The vertical slice still needs authored high-detail assets, proper skeletal animations, spatial weapon/ambience audio, robust navigation and cover tactics, destructible environments, vehicles, additional missions, co-op, and multiplayer. Current geometry and enemy logic are intentionally lightweight placeholders for gameplay iteration.

## Performance

The project uses the Compatibility renderer, modest geometry, no imported textures, and no real-time global illumination. It is intended to be approachable on older integrated GPUs while the core gameplay loop is being proven.

## Verification

- **Headless smoke test:** passed in Godot 4.7.2, including project import and a 300-frame scene run with no script/parse errors.
- **Not yet visually verified:** rendered appearance, mouse capture, pause-menu interaction, and gameplay feel still need an interactive run.
- GitHub Actions repeats the headless smoke test on pushes and pull requests.