# OPERATION BLACKOUT: FIRST LIGHT

Suppression now preserves a valid cover commitment across repeated near misses and tracks the actual incoming-fire source when choosing evasive cover. Enemies also finish their short defensive hold after the suppression window expires, then return to visible-target combat once that commitment runs out.

Tactical AI scores cover using actual world-geometry line of sight, discourages reusing the same cover, separates squadmates' cover and flank goals, biases flankers toward the less occupied side of the player's position, and penalizes near-identical flank routes to reduce movement oscillation. Wounded hostiles weight distance from incoming fire more heavily when selecting a defensive position.

A lightweight Godot 4 first-person tactical shooter vertical-slice prototype. This is an original project inspired by the pacing and tactical feel of classic shooters, not their protected characters, story, or assets.

## Current milestone

- Procedurally assembled 3D ruined-town arena and cover
- First-person mouse look, WASD movement, sprint, jump, crouch, prone, and collision-aware Q/E shoulder leaning
- Aim-down-sights field-of-view change, breathing/strafe sway, recoil, and brief muzzle illumination; low-cost first-person forearms and gloves follow weapon handling, with a visible magazine removal/reinsertion animation during reloads
- Assault rifle firing, raycast hit detection, ammunition and animated reloads, capped brass casing ejection, fading bullet impact marks and positional impact sounds from both friendly and hostile rounds striking solid surfaces; nearby guards can investigate impact locations, and hostile gunfire can alert nearby squad members, while near-miss rounds suppress exposed guards and trigger a brief reposition, plus lightweight procedural positional gunshot and grenade-blast audio without external asset downloads
- Hostile AI: line-of-sight detection, district patrols, role-based assault/support/flanker/rifleman behavior with distinct movement spacing, role-specific firing envelopes, movement- and distance-based shot spread, role-specific controlled bursts and short reacquisition pauses after losing sight, support-led sustained suppression that creates short movement windows for flankers, designated flanker maneuvering with riflemen inheriting flank duty only when no living flanker remains, assault pressure advances, pursuit, timed cover-aware flank runs, ally-spacing penalties for cover and flank selection, separation steering that prevents squadmates from crowding each other, last-known-position investigation, cover-aware repositioning with role- and health-dependent defensive holds, grenade evasion, obstacle steering, coordinated alerts, visible shot tracers, and hitscan return fire; nonlethal hits trigger directional upper-body flinches, with stronger headshot reactions, while layered helmet, goggles, backpack, squad radio with raised antenna, sidearm holster, belt, individually modeled magazine pouches, shoulder pads, knee pads, boot caps, and separate rifle optic/barrel components build out the hostile silhouette; procedural arms and legs animate with movement and lethal hits trigger a short collision-safe collapse
- Health and directional damage feedback, brief respawn protection, headshot-aware hit confirmation, a pulsing intel beacon with a vertical light beam, and a hold-to-recover objective gated behind enemy clearance, a marked extraction zone with a pulsing beacon, smoke plume, safety bollards, and a second hold interaction, deployment briefing screen, pause menu with adjustable mouse sensitivity and a control reference, and mission-complete debrief with mission time, hostile count, shot accuracy, grenade use, resupply use, and replay screen
- Combat HUD feedback with low-ammo warning colors, stamina percentage, a live intel distance/bearing indicator, and viewport-anchored layout; weapon view shifts into a tighter aim-down-sights position
- Three interactable ammo caches let players resupply reserve ammunition, with one-time pickup behaviour and a hard reserve cap
- Limited frag grenades can be thrown with G; the timed blast applies distance-falloff damage, reduced through solid cover, physical knockback, and a short explosion flash
- Layered window bays with rain-streak weathering, facade trim, surface-mounted electrical junctions and conduit runs, rooftop water tanks, side-wall details, damaged balcony rails, exposed rebar, cracked facades, battered air-conditioning units, wrecked vehicles with separate hood/trunk panels, tinted glazing, mirrors, grille bars, emissive headlamps, bumpers and four collidable detailed wheels, service doors, street lamps, road gutters, detailed manhole covers and storm-drain grates, tire skid scarring, damaged asphalt patches, scattered debris, and lightweight battlefield smoke, a layered distant city skyline, animated broken-cloud sky shader, sun scatter, fog-softened horizon, warm directional sunlight, collidable street lamps, and sagging overhead utility cables
- Shared procedural spatial shader for terrain, asphalt, concrete facades, and rubble, adding world-space noise, aggregate grain, pores, weathering, and surface-specific roughness without external texture downloads; collision bodies remain independent of the rendered surface material
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

This is a foundation, not the finished game. The procedural surface shader adds material variation, but it is not a substitute for authored PBR texture sets, detailed modular building meshes, believable soldier models, rigged animations, or scanned environmental assets. Combatants still use procedural meshes and inexpensive logic. The vertical slice still needs high-detail environment/character assets, proper skeletal animations, spatial weapon/ambience audio, robust navigation and cover tactics, destructible environments, vehicles, additional missions, co-op, and multiplayer.

## Performance

The project uses the Compatibility renderer, shared repeated materials, modest geometry, reduced CPU smoke counts, no imported textures, and no real-time global illumination. Automated scene-budget checks guard against runaway node and mesh growth. Interactive FPS and GPU load still need to be measured on target hardware.

## Verification

- **Automated gameplay checks:** test firing/hitscan damage, player damage and respawn, reload ammunition transfer, enemy damage/death, suppression response, enemy-count updates, the intel gate, mission-complete HUD state, the separate intel-to-exfil mission flow, respawn-protection checks, ammo-cache pickup/cap/HUD updates, grenade inventory/throw/damage-falloff/knockback checks, stamina and ammunition HUD updates, intel rangefinder presence, hostile obstacle steering, cover-goal checks, role- and health-dependent cover commitment checks, coordinated flank spacing, immediate obstacle-clearance scoring for flank routes, and ally-separation steering, deployment-briefing pause/resume checks, mission-debrief/stat tracking and Escape-guard checks, pause-menu sensitivity checks, procedural audio stream and weapon-audio wiring checks, intel interaction-area/beacon initialization checks, extraction beacon smoke/bollard checks, facade rubble distribution, enemy muzzle-flash/hit-reaction feedback, viewport-anchored HUD layout, outer-district environment props, and difficulty-profile selection/balance, distinct hostile squad-role assignment and engagement-spacing checks, supporting-fire detection and flanker acceleration checks, first-person arm/hand view-model wiring, hostile limb geometry and gait animation, and timed enemy death-collapse cleanup, bounded spent-casing ejection, and collisionless bullet-impact mark placement/lifetime caps, collision-aware Q/E lean limits and recentering, and regression checks for layered hostile equipment (including radio/antenna, sidearm holster, and combat-ready rifle posture with a shorter combat stride, forward torso lean, and smoothly settling lateral movement lean, with controlled deceleration and defensive holds at selected cover, with line-of-sight scoring that distinguishes world geometry from squadmates) and procedural surface materials.
- **Headless smoke test:** GitHub Actions imports the project and runs the main scene for 300 frames on Godot 4.7.2 before executing gameplay regressions.
- **Still requires local verification:** visual quality, enemy behaviour in a live fight, mouse capture, pause-menu interaction, actual FPS, and GPU load.
- GitHub Actions runs the headless scene test and gameplay regression suite on pushes and pull requests.

Tactical HUD: nearby hostile shots trigger a brief directional `HOSTILE FIRE` cue before damage lands; confirmed incoming damage replaces it with the stronger hit-direction warning. Enemy cover selection also penalizes immediately reusing the previous position to encourage movement between engagements.
