# FPS Combat Slice (simple animated FPS NPC template)

This Summer Engine template is a compact first-person combat slice you can use as a starting point for a 3D shooter, enemy encounter prototype, or weapon handling experiment. It includes a playable arena, first-person movement, a rifle and pistol loadout, animated weapon viewmodels, ranged NPC enemies, hit feedback, muzzle effects, audio, and a simple HUD.

The project is intended as a base to build on. Keep the pieces you need, replace the blockout arena or assets, and extend the scripts into your own combat loop.

## What Is Included

- First-person player controller with mouse look, jump, sprint, crouch, stamina, and camera FOV feedback.
- Weapon system with hitscan shooting, ammo, reloads, recoil/camera shake hooks, bullet tracers, muzzle flash, and weapon switching.
- Rifle and pistol profiles in `res://weapons/` that can be copied or tuned for new weapons.
- Animated first-person rifle and pistol viewmodels.
- Ranged soldier NPCs with idle, movement, shooting, hit reaction, and death animations.
- Prototype arena scene in `res://main.tscn` with cover, lighting, HUD, and enemy placements.
- Asset manifest at `res://asset_manifest/fps_combat_assets.md` with source and license notes.
- Smoke test at `res://tests/input_reader_smoke_test.gd`.

## Controls

| Action | Keyboard and Mouse |
|---|---|
| Move | W, A, S, D |
| Look | Mouse |
| Jump | Space |
| Sprint | Shift |
| Crouch | C |
| Shoot | Left mouse button |
| Reload | R |
| Equip weapon 1 | 1 |
| Equip weapon 2 | 2 |
| Release mouse pointer | Esc |
| Recapture mouse pointer | Left mouse button |

Gamepad input mappings are also included for movement, look, jump, crouch, shoot, reload, and weapon slots. You can adjust all mappings in `project.godot` under the `[input]` section or through the Summer/Godot input map UI.

## Building On It

- Edit `res://main.tscn` to reshape the arena, move enemies, or replace the blockout layout with your own level.
- Tune player movement in `res://scripts/player_controller.gd`.
- Add or modify weapons by creating more `FPSWeaponProfile` resources like `res://weapons/rifle_01_profile.tres` and wiring them into the player's `WeaponLoadout`.
- Extend enemy behavior in `res://scripts/enemy_npc.gd` and enemy firing behavior in `res://scripts/enemy_ranged_weapon.gd`.
- Replace visual or audio assets under `res://assets/fps_combat/`, keeping license requirements in mind.
- Use `res://scripts/fps_input_reader.gd` as the central place for remappable player input.

## Running

Open the project folder in Summer Engine and run `res://main.tscn`. The first click captures the mouse pointer; press Esc to release it.
