extends Resource
class_name FPSWeaponProfile

@export var weapon_name: String = "Pistol"
@export var damage: float = 25.0
@export var fire_rate: float = 0.15
@export var reload_time: float = 1.5
@export var magazine_size: int = 12
@export var max_ammo: int = 120
@export var is_automatic: bool = false
@export var spread_degrees: float = 1.0
@export var shot_range: float = 100.0

# Model paths for first-person weapon assets
@export var weapon_model_path: String = ""
@export var arms_model_path: String = ""

# Animation names from imported FBX animation resources
@export var base_pose_anim: String = "BasePose"
@export var fire_anim: String = "Fire"
@export var reload_anim: String = "Reload"
@export var draw_anim: String = "Draw"

# Animation FBX paths (loaded and extracted at runtime)
@export var arms_anim_base_pose_fbx: String = ""
@export var arms_anim_fire_fbx: String = ""
@export var arms_anim_reload_fbx: String = ""
@export var arms_anim_draw_fbx: String = ""
@export var weapon_anim_base_pose_fbx: String = ""
@export var weapon_anim_fire_fbx: String = ""
@export var weapon_anim_reload_fbx: String = ""

# Audio
@export var fire_sound: AudioStream = null
@export var fire_sound_segments: Array[Vector2] = []
@export var randomize_fire_sound_segments: bool = true
@export var reload_sound: AudioStream = null
@export var dry_fire_sound: AudioStream = null

# Camera feedback
@export var fire_camera_trauma: float = 0.3
@export var hit_camera_trauma: float = 0.5
