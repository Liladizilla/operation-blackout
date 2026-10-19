# OPERATION BLACKOUT: FIRST LIGHT

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone, and collision-aware Q/E shoulder leaning
- Aim-down-sights field-of-view change, breathing/strafe sway, recoil, and brief muzzle illumination; low-cost first-person forearms and gloves follow weapon handling, with a visible magazine removal/reinsertion animation during reloads
- Assault rifle firing, raycast hit detection, ammunition and animated reloads, capped brass casing ejection, fading bullet impact marks and positional impact sounds from both friendly and hostile rounds striking solid surfaces; nearby guards can investigate impact locations, and hostile gunfire can alert nearby squad members, while near-miss rounds suppress exposed guards and trigger a brief reposition, plus lightweight procedural positional gunshot and grenade-blast audio without external asset downloads
- Hostile AI: line-of-sight detection, district patrols, pursuit, timed cover-aware flank runs, last-known-position investigation, cover-aware repositioning, grenade evasion, obstacle steering, coordinated alerts, visible shot tracers, and hitscan return fire; procedural arms and legs animate with movement, and lethal hits trigger a short collision-safe collapse
- Health and directional damage feedback, brief respawn protection, headshot-aware hit confirmation, a pulsing intel beacon with a vertical light beam, and a hold-to-recover objective gated behind enemy clearance, a marked extraction zone with a pulsing beacon, smoke plume, safety bollards, and a second hold interaction, deployment briefing screen, pause menu with adjustable mouse sensitivity and a control reference, and mission-complete debrief with mission time, hostile count, shot accuracy, grenade use, resupply use, and replay screen
- Combat HUD feedback with low-ammo warning colors, stamina percentage, a live intel distance/bearing indicator, and viewport-anchored layout; weapon view shifts into a tighter aim-down-sights position
- Three interactable ammo caches let players resupply reserve ammunition, with one-time pickup behaviour and a hard reserve cap
- Limited frag grenades can be thrown with G; the timed blast applies distance-falloff damage, reduced through solid cover, physical knockback, and a short explosion flash
- Layered window bays, facade trim, side-wall details, service doors, battered street lamps, road gutters, damaged asphalt patches, scattered debris, and lightweight battlefield smoke
- Expanded outer district with eight additional ruined perimeter buildings, a secondary service lane, utility crates, drainage details, and distributed rubble clusters; repeated materials are shared to keep the scene lightweight
- Mission briefing includes Recruit, Standard, and Veteran threat profiles that tune hostile awareness, firing cadence, and incoming damage
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
- **Q / E**: lean left / right when the side is clear
- **Space**: jump
- **R**: reload
- **F**: interact / recover intel
- **Esc**: pause / release mouse
- **Mission briefing**: choose Recruit, Standard, or Veteran before deployment

## Current limits

This is a foundation, not the finished game. Combatants use procedural meshes and inexpensive logic. The vertical slice still needs authored high-detail environment/character assets, proper skeletal animations, spatial weapon/ambience audio, robust navigation and cover tactics, destructible environments, vehicles, additional missions, co-op, and multiplayer. Current geometry and enemy logic remain lightweight while the gameplay loop is being verified.

## Performance

The project uses the Compatibility renderer, shared repeated materials, modest geometry, reduced CPU smoke counts, no imported textures, and no real-time global illumination. Automated scene-budget checks guard against runaway node and mesh growth. Interactive FPS and GPU load still need to be measured on target hardware.

## Verification

- **Automated gameplay checks:** test firing/hitscan damage, player damage and respawn, reload ammunition transfer, enemy damage/death, suppression response, enemy-count updates, the intel gate, mission-complete HUD state, the separate intel-to-exfil mission flow, respawn-protection checks, ammo-cache pickup/cap/HUD updates, grenade inventory/throw/damage-falloff/knockback checks, stamina and ammunition HUD updates, intel rangefinder presence, hostile obstacle steering and cover-goal checks, deployment-briefing pause/resume checks, mission-debrief/stat tracking and Escape-guard checks, pause-menu sensitivity checks, procedural audio stream and weapon-audio wiring checks, intel interaction-area/beacon initialization checks, extraction beacon smoke/bollard checks, facade rubble distribution, enemy muzzle-flash/hit-reaction feedback, viewport-anchored HUD layout, outer-district environment props, and difficulty-profile selection/balance, first-person arm/hand view-model wiring, hostile limb geometry and gait animation, and timed enemy death-collapse cleanup, bounded spent-casing ejection, and collisionless bullet-impact mark placement/lifetime caps, and collision-aware Q/E lean limits and recentering.
- **Headless smoke test:** GitHub Actions imports the project and runs the main scene for 300 frames on Godot 4.7.2 before executing gameplay regressions.
- **Still requires local verification:** visual quality, enemy behaviour in a live fight, mouse capture, pause-menu interaction, actual FPS, and GPU load.
- GitHub Actions runs the headless scene test and gameplay regression suite on pushes and pull requests.

Tactical HUD: nearby hostile shots trigger a brief directional `HOSTILE FIRE` cue before damage lands; confirmed incoming damage replaces it with the stronger hit-direction warning. Enemy cover selection also penalizes immediately reusing the previous position to encourage movement between engagements.
