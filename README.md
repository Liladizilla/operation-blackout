# OPERATION BLACKOUT: FIRST LIGHT

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone
- Aim-down-sights field-of-view change and weapon sway/recoil
- Assault rifle firing, raycast hit detection, ammunition and reloads
- Basic hostile AI: line-of-sight detection, pursuit/strafe, hitscan return fire
- Health feedback, HUD, objective interaction, pause menu
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

This is a foundation, not the finished game. Combatants use procedural meshes and inexpensive logic. Campaign missions, multiplayer, vehicles, advanced destruction, motion capture, console support, animation, audio, and cover-seeking AI are not implemented yet.

## Performance

The project uses the Compatibility renderer, modest geometry, no imported textures, and no real-time global illumination. It is intended to be approachable on older integrated GPUs while the core gameplay loop is being proven.

## Verification status

The project has not yet passed a Godot runtime test. Initial sandbox validation is the next milestone; passing static upload checks does not prove that the game launches or plays correctly.