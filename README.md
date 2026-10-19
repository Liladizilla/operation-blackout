# OPERATION BLACKOUT: FIRST LIGHT

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone
- Aim-down-sights field-of-view change, breathing/strafe sway, recoil, and brief muzzle illumination
- Assault rifle firing, raycast hit detection, ammunition and reloads
- Hostile AI: line-of-sight detection, pursuit/strafe, last-known-position investigation, cover-aware repositioning to clear positions beside barriers and service-alley crates, short-range obstacle steering around concrete barriers, visible muzzle flashes during return fire, and hitscan return fire; taking damage triggers a brief hit reaction and suppression/reposition response
- Health and directional damage feedback, brief respawn protection, headshot-aware hit confirmation, hold-to-recover intel objective gated behind enemy clearance, a marked extraction zone that requires a second hold interaction, pause menu, and mission-complete/replay screen
- Combat HUD feedback with low-ammo warning colors, stamina percentage and faster recovery while stationary, a live intel distance/bearing indicator, and wrapped viewport-aware text; weapon view shifts into a tighter aim-down-sights position
- Expanded hostile cover choices across the outer district to reduce repeated movement toward the same central cover positions
- Weapon stability responds to movement and stance: sprinting widens spread, while crouching and going prone improve shot control; incoming fire keeps enemies suppressed long enough to seek cover
- Intel recovery reports when the interaction is interrupted by leaving the objective zone
- Layered window bays, facade trim, side-wall details, service doors, battered street lamps, road gutters, damaged asphalt patches, scattered debris, and lightweight battlefield smoke
- Expanded outer district with eight additional ruined perimeter buildings, a secondary service lane, utility crates, drainage details, and distributed rubble clusters; repeated materials are shared to keep the scene lightweight
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

- **Automated gameplay checks:** test firing/hitscan damage, player damage and respawn, reload ammunition transfer, enemy damage/death, suppression response, enemy-count updates, the intel gate, mission-complete HUD state, the separate intel-to-exfil mission flow, respawn-protection checks, stamina and ammunition HUD updates, movement/stance weapon spread, intel rangefinder presence, hostile obstacle steering and cover-goal checks, facade rubble distribution, enemy muzzle-flash/hit-reaction feedback, viewport-anchored HUD layout, and expected outer-district environment props.
- **Headless smoke test:** GitHub Actions imports the project and runs the main scene for 300 frames on Godot 4.7.2 before executing gameplay regressions.
- **Still requires local verification:** visual quality, enemy behaviour in a live fight, mouse capture, pause-menu interaction, actual FPS, and GPU load.
- GitHub Actions runs the headless scene test and gameplay regression suite on pushes and pull requests.