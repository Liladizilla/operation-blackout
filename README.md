# OPERATION BLACKOUT: FIRST LIGHT

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone
- Aim-down-sights field-of-view change, breathing/strafe sway, recoil, and brief muzzle illumination
- Assault rifle firing, raycast hit detection, ammunition and reloads
- Hostile AI: line-of-sight detection, pursuit/strafe, last-known-position investigation, cover-aware repositioning, and hitscan return fire; taking damage triggers a suppression/reposition response
- Health and directional damage feedback, headshot-aware hit confirmation, hold-to-recover intel objective gated behind enemy clearance, pause menu, and mission-complete/replay screen
- Layered window bays, facade trim, side-wall details, service doors, battered street lamps, road gutters, damaged asphalt patches, scattered debris, and lightweight battlefield smoke
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

This is a foundation, not the finished game. Combatants use procedural meshes and inexpensive logic. The vertical slice still needs authored high-detail environment/character assets, proper skeletal animations, spatial weapon/ambience audio, robust navigation and cover tactics, destructible environments, vehicles, additional missions, co-op, and multiplayer. Current geometry and enemy logic remain lightweight while the gameplay loop is being verified.

## Performance

The project uses the Compatibility renderer, shared repeated materials, modest geometry, reduced CPU smoke counts, no imported textures, and no real-time global illumination. The current Godot 4.4.1 headless scene profile reports **730 nodes and 338 mesh instances**; automated budget checks guard against runaway growth. Interactive FPS and GPU load still need to be measured on target hardware.

## Verification

- **Automated gameplay checks:** test firing/hitscan damage, player damage and respawn, reload ammunition transfer, enemy damage/death, suppression response, enemy-count updates, the intel gate, and mission-complete HUD state.
- **Headless smoke test:** passed in Godot 4.4.1 with a 300-frame main-scene run and no script/parse errors.
- **Still requires local verification:** visual quality, enemy behaviour in a live fight, mouse capture, pause-menu interaction, actual FPS, and GPU load.
- GitHub Actions runs the headless scene test and gameplay regression suite on pushes and pull requests.