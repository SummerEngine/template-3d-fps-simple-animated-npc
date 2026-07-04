---
name: fps-combat-slice
overview: >-
  Build a playable FPS combat slice with Kuptchi first-person weapons/arms,
  Kenney prototype textures, Mixamo shooter enemy with animations, VFX, and
  rifle audio.
createdAt: '2026-07-02T10:23:58.558Z'
todos:
  - id: input-maps
    content: >-
      Set up all FPS input actions (WASD, mouse, shoot, reload, weapon swap,
      etc.)
    status: completed
  - id: player-controller
    content: >-
      Write player_controller.gd with WASD movement, mouse look, jump, sprint,
      crouch
    status: completed
  - id: weapon-data
    content: >-
      Write fps_weapon_profile.gd (WeaponData resource) and fps_combat_layers.gd
      (collision constants)
    status: completed
  - id: weapon-system
    content: >-
      Write weapon_system.gd (fire/reload/ammo/hitscan) and weapon_loadout.gd
      (switching)
    status: completed
  - id: camera-shake-vfx
    content: >-
      Write camera_shake_3d.gd, hit_flash_3d.gd, one_shot_vfx_3d.gd,
      bullet_tracer_3d.gd
    status: completed
  - id: enemy-scripts
    content: >-
      Write enemy_npc.gd and enemy_ranged_weapon.gd with Mixamo animation
      integration
    status: completed
  - id: hud
    content: 'Write hud_controller.gd (crosshair, health, ammo, reload)'
    status: completed
  - id: main-scene
    content: >-
      Build main.tscn with full World hierarchy, Kenney textures, lighting,
      player, enemy, VFX, and HUD
    status: completed
  - id: verify
    content: runAndVerify to confirm the game compiles and runs
    status: completed
---
## Scene Hierarchy (from working-scene-recipe.md)

```
World (Node3D)
  Level (Node3D)
    Ground (StaticBody3D + BoxShape3D + MeshInstance3D with PlaneMesh)
    Walls (StaticBody3D boxes)
    Cover (StaticBody3D boxes)
  Player (CharacterBody3D)
    StandingShape (CapsuleShape3D radius=0.35 height=1.8)
    CrouchingShape (CapsuleShape3D radius=0.35 height=1.0 disabled)
    Head (Node3D at Y=1.5)
      Camera3D (FOV=70)
        WeaponHolder (Node3D offset: 0.2, -0.15, -0.4)
          FP_Arms+rifle via Kuptchi .fbx
        ShootRay (RayCast3D target=-100m mask=10)
      CameraShake
    CeilingCheck (RayCast3D up)
    WeaponSystem (Node)
    WeaponLoadout (Node)
  Enemies (Node3D)
    SoldierEnemy (CharacterBody3D)
      CollisionShape3D (Capsule)
      Model (Mixamo Ch35_nonPBR)
        Skeleton3D, AnimationPlayer
      EnemyWeapon (Node3D)
        Muzzle (Node3D)
        MuzzleFlash (Sprite3D)
      HitFlash (Node)
      HealthComponent
  Effects (Node3D)
  HUD (CanvasLayer)
```

## Collision Layers (fps_combat_layers.gd)
- Layer 2: Environment (walls, floor, cover)
- Layer 4: Enemy bodies
- Player shoot mask: 10 (env + enemy)
- Enemy shoot mask: 3 (env + player)

## Audio
- Rifle fire: res://assets/fps_combat/audio/238916__qubodup__rifle-shooting.wav
- 8 timestamp segments in weapon profile
- Enemy uses same but AudioStreamPlayer3D at -9dB with distance falloff

## Kenney Textures
- dark/ for arena floor/walls
- orange/ for cover objects
- red/ for hazard/death zone
