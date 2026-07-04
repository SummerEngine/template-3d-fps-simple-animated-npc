---
name: fps-combat-slice-animations
overview: >-
  Wire weapon animations (fire, reload, base pose) from Kuptchi FBX clips, wire
  enemy Mixamo animations, and verify the full combat loop.
createdAt: '2026-07-02T12:10:37.425Z'
todos:
  - id: weapon-animations
    content: >-
      Load Kuptchi animation FBX clips and wire fire/reload/base-pose animations
      to WeaponSystem
    status: completed
  - id: enemy-skeleton-anim
    content: >-
      Wire Mixamo enemy animation clips to SoldierEnemy AnimationPlayer via the
      Ch35 skeleton
    status: completed
  - id: enemy-combat-wiring
    content: >-
      Wire enemy ranged weapon shooting, hit reactions, and death with
      animations
    status: completed
  - id: combat-verify
    content: >-
      Run and verify: player can shoot, enemy takes damage, reacts, dies, and
      HUD updates
    status: completed
---
## Weapon Animations
- Arms animation FBX: load each FP_Arms_Rifle_01_*.fbx, extract animation from its AnimationPlayer, add to arms root AnimationPlayer
- Rifle weapon FBX: load Rifle_01_*.fbx same way
- Wire WeaponSystem._fire() to play "Fire" animation, _start_reload() to play "Reload", equip() to play "BasePose"

## Enemy Animations
- Mixamo clips at res://assets/fps_combat/enemy/mixamo_shooter_animations/
- Load each FBX, extract animation, add to enemy's AnimationPlayer
- Wire enemy_npc to play: "rifle aiming idle" on ready, "firing rifle" on attack, "hit reaction" on damaged, "Dying" on death
- Wire enemy_ranged_weapon to trigger muzzle flash + positional audio on fire

## Verification
- runAndVerify after each step
- Confirm weapons render, animations play, enemy reacts to damage
