extends Node

# Collision layer constants for the FPS combat slice.
# Player bodies: layer 1 (Godot default)
# Environment: layer 2 (walls, floors, cover)
# Interactable: layer 3 (doors, pickups)
# Enemy bodies: layer 4

const LAYER_ENVIRONMENT: int = 2
const LAYER_INTERACTABLE: int = 3
const LAYER_ENEMY: int = 4

# Player shoot ray hits environment + enemy
const PLAYER_SHOOT_MASK: int = (1 << (LAYER_ENVIRONMENT - 1)) | (1 << (LAYER_ENEMY - 1))

# Enemy shoot ray hits environment + player
const ENEMY_SHOOT_MASK: int = (1 << (LAYER_ENVIRONMENT - 1)) | (1 << 0)
