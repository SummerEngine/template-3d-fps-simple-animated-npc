extends CharacterBody3D
class_name EnemyNPC

signal damaged()
signal died()

enum EnemyState {
	IDLE,
	CHASE,
	STRAFE_LEFT,
	STRAFE_RIGHT,
	BACKPEDAL,
	RETREAT_AWAY,
	ATTACK,
	RELOAD,
	HIT,
	DEAD,
}

enum FacingMode {
	FACE_PLAYER,
	FACE_MOVEMENT,
}

const ENEMY_ANIMATION_LIBRARY := "enemy_clips"
const ANIMATION_IMPORT_VERSION := 3
const DEFAULT_LINE_OF_SIGHT_MASK: int = 3
const ROOT_MOTION_TRACK_PATH := "Skeleton3D:mixamorig_Hips"

static var _animation_library_cache: Dictionary = {}

@export var walk_speed: float = 3.0
@export var run_speed: float = 3.8
@export var strafe_speed: float = 2.4
@export var backpedal_speed: float = 2.0
@export var sight_range: float = 18.0
@export_range(-1.0, 1.0, 0.01) var detection_front_dot_min: float = 0.0
@export var attack_range: float = 15.0
@export var hold_range: float = 9.0
@export var retreat_range: float = 4.0
@export var max_health: float = 80.0
@export var attack_cooldown: float = 1.1
@export var attack_windup: float = 0.35
@export var damage_per_shot: float = 8.0
@export var strafe_decision_interval: float = 1.4
@export var line_of_sight_mask: int = DEFAULT_LINE_OF_SIGHT_MASK
@export var line_of_sight_eye_height: float = 1.35
@export var line_of_sight_target_height: float = 1.0
@export var last_known_memory_time: float = 4.0
@export var last_known_arrival_distance: float = 1.1

@export var animation_player_path: NodePath
@export var ranged_weapon_path: NodePath = NodePath("EnemyWeapon")
@export var hit_flash_path: NodePath = NodePath("HitFlash")

@export_group("Animation Names")
@export var idle_combat_animation: String = "enemy_idle"
@export var aim_idle_animation: String = "enemy_idle"
@export var run_forward_animation: String = "enemy_move"
@export var walk_forward_animation: String = "enemy_move"
@export var walk_backward_animation: String = ""
@export var run_backward_animation: String = ""
@export var strafe_left_animation: String = ""
@export var strafe_right_animation: String = ""
@export var turn_left_animation: String = ""
@export var turn_right_animation: String = ""
@export var fire_single_animation: String = "enemy_attack"
@export var reload_animation: String = ""
@export var hit_front_animation: String = "enemy_hit"
@export var death_front_animation: String = "enemy_death"

@export_group("Animation Clip Sources")
@export_file("*.fbx") var idle_combat_fbx: String = "res://assets/fps_combat/enemy/ranged_soldier_animations/rifle aiming idle.fbx"
@export_file("*.fbx") var run_forward_fbx: String = "res://assets/fps_combat/enemy/ranged_soldier_animations/rifle run.fbx"
@export_file("*.fbx") var fire_single_fbx: String = "res://assets/fps_combat/enemy/ranged_soldier_animations/firing rifle.fbx"
@export_file("*.fbx") var hit_front_fbx: String = "res://assets/fps_combat/enemy/ranged_soldier_animations/hit reaction.fbx"
@export_file("*.fbx") var death_front_fbx: String = "res://assets/fps_combat/enemy/ranged_soldier_animations/Dying.fbx"
@export_file("*.fbx") var walk_backward_fbx: String = ""
@export_file("*.fbx") var run_backward_fbx: String = ""
@export_file("*.fbx") var strafe_left_fbx: String = ""
@export_file("*.fbx") var strafe_right_fbx: String = ""
@export_file("*.fbx") var reload_fbx: String = ""

@onready var animation_player: AnimationPlayer = _resolve_animation_player()
@onready var ranged_weapon: Node = get_node_or_null(ranged_weapon_path)
@onready var hit_flash: HitFlash3D = get_node_or_null(hit_flash_path) as HitFlash3D

var health: float
var player: PlayerController = null
var _has_detected_player: bool = false
var _has_line_of_sight_to_player: bool = false
var _has_last_known_player_position: bool = false
var _last_known_player_position: Vector3 = Vector3.ZERO
var _time_since_player_seen: float = 0.0
var _attack_timer: float = 0.0
var _state: EnemyState = EnemyState.IDLE
var _state_locked: bool = false
var _strafe_timer: float = 0.0
var _strafe_direction: int = 1


func _ready() -> void:
	health = max_health
	collision_layer = 1 << 3
	add_to_group("enemies")

	var model := get_node_or_null("SoldierModel") as Node3D
	if model:
		model.rotation_degrees.y = 180.0

	_import_enemy_animations()
	_play_animation(idle_combat_animation)
	_state = EnemyState.IDLE


func _resolve_animation_player() -> AnimationPlayer:
	var configured := get_node_or_null(animation_player_path) as AnimationPlayer
	if configured:
		return configured
	return get_node_or_null("SoldierModel/AnimationPlayer") as AnimationPlayer


func _import_enemy_animations() -> void:
	if not animation_player:
		push_warning("[EnemyNPC] No AnimationPlayer found. Enemy will move without skeletal animation.")
		return

	var clips := {
		idle_combat_animation: idle_combat_fbx,
		aim_idle_animation: idle_combat_fbx,
		run_forward_animation: run_forward_fbx,
		walk_forward_animation: run_forward_fbx,
		fire_single_animation: fire_single_fbx,
		hit_front_animation: hit_front_fbx,
		death_front_animation: death_front_fbx,
		walk_backward_animation: walk_backward_fbx,
		run_backward_animation: run_backward_fbx,
		strafe_left_animation: strafe_left_fbx,
		strafe_right_animation: strafe_right_fbx,
		reload_animation: reload_fbx,
	}

	var cache_key := _build_animation_cache_key(clips)
	var cached_lib := _animation_library_cache.get(cache_key) as AnimationLibrary
	var lib := cached_lib if cached_lib else AnimationLibrary.new()

	if not cached_lib:
		for target_name in clips:
			var fbx_path: String = clips[target_name]
			if target_name.is_empty() or fbx_path.is_empty():
				continue
			var anim := _extract_first_animation(fbx_path)
			if anim:
				if _should_loop_animation(target_name):
					anim.loop_mode = Animation.LOOP_LINEAR
				if _should_lock_animation_in_place(target_name):
					_strip_horizontal_root_motion(anim)
				lib.add_animation(target_name, anim)
			else:
				print("[EnemyNPC] FAILED to extract anim from %s" % fbx_path)
		if not lib.get_animation_list().is_empty():
			_animation_library_cache[cache_key] = lib
			print("[EnemyNPC] cached '%s' library with %d animations: %s" % [ENEMY_ANIMATION_LIBRARY, lib.get_animation_list().size(), lib.get_animation_list()])

	if lib.get_animation_list().is_empty():
		return

	if animation_player.has_animation_library(ENEMY_ANIMATION_LIBRARY):
		animation_player.remove_animation_library(ENEMY_ANIMATION_LIBRARY)
	animation_player.add_animation_library(ENEMY_ANIMATION_LIBRARY, lib)


func _build_animation_cache_key(clips: Dictionary) -> String:
	var keys := clips.keys()
	keys.sort()
	var parts: Array[String] = []
	parts.append("v%d" % ANIMATION_IMPORT_VERSION)
	for target_name in keys:
		var fbx_path: String = clips[target_name]
		if target_name.is_empty() or fbx_path.is_empty():
			continue
		parts.append("%s=%s" % [target_name, fbx_path])
	return "|".join(parts)


func _extract_first_animation(fbx_path: String) -> Animation:
	var scene := load(fbx_path) as PackedScene
	if not scene:
		print("[EnemyNPC] FAILED to load scene: %s" % fbx_path)
		return null
	var inst := scene.instantiate()
	var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not ap or ap.get_animation_list().is_empty():
		print("[EnemyNPC] No AnimationPlayer in %s" % fbx_path)
		inst.queue_free()
		return null
	var anim_name := ap.get_animation_list()[0]
	var anim := ap.get_animation(anim_name)
	var result := anim.duplicate() if anim else null
	ap.queue_free()
	inst.queue_free()
	return result


func _should_loop_animation(anim_name: String) -> bool:
	return (
		anim_name == idle_combat_animation
		or anim_name == aim_idle_animation
		or anim_name == run_forward_animation
		or anim_name == walk_forward_animation
		or anim_name == walk_backward_animation
		or anim_name == run_backward_animation
		or anim_name == strafe_left_animation
		or anim_name == strafe_right_animation
	)


func _should_lock_animation_in_place(anim_name: String) -> bool:
	return (
		anim_name == run_forward_animation
		or anim_name == walk_forward_animation
		or anim_name == walk_backward_animation
		or anim_name == run_backward_animation
		or anim_name == strafe_left_animation
		or anim_name == strafe_right_animation
	)


func _strip_horizontal_root_motion(anim: Animation) -> void:
	for track_index in range(anim.get_track_count()):
		if str(anim.track_get_path(track_index)) != ROOT_MOTION_TRACK_PATH:
			continue
		var key_count := anim.track_get_key_count(track_index)
		if key_count < 2:
			return
		var first_value = anim.track_get_key_value(track_index, 0)
		if not first_value is Vector3:
			return
		for key_index in range(key_count):
			var value = anim.track_get_key_value(track_index, key_index)
			if not value is Vector3:
				continue
			value.x = first_value.x
			value.z = first_value.z
			anim.track_set_key_value(track_index, key_index, value)
		return


func _physics_process(delta: float) -> void:
	if _state == EnemyState.DEAD:
		return

	_find_player()
	if not player:
		_set_state(EnemyState.IDLE)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _strafe_timer > 0.0:
		_strafe_timer -= delta

	if _state_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var dist_to_player := global_position.distance_to(player.global_position)
	_update_player_perception(delta, dist_to_player)

	if not _has_detected_player:
		_set_state(EnemyState.IDLE)
		velocity = Vector3.ZERO
	elif not _has_line_of_sight_to_player:
		_investigate_last_known_position()
	elif dist_to_player > attack_range:
		_chase_player()
	elif dist_to_player < retreat_range:
		_retreat_from_player()
	elif dist_to_player < hold_range:
		_combat_reposition()
	else:
		_hold_and_attack()

	move_and_slide()


func _find_player() -> void:
	if player:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as PlayerController


func _can_detect_player(dist_to_player: float) -> bool:
	if not player:
		return false
	if dist_to_player > sight_range:
		return false
	if not _has_line_of_sight_to_player:
		return false
	return _is_position_in_front_half_sphere(player.global_position)


func _update_player_perception(delta: float, dist_to_player: float) -> void:
	_has_line_of_sight_to_player = _can_see_player(dist_to_player)
	if _has_line_of_sight_to_player:
		_has_detected_player = true
		_remember_player_position()
		return

	if not _has_detected_player:
		_forget_player()
		return

	_time_since_player_seen += delta
	if _time_since_player_seen > last_known_memory_time:
		_forget_player()


func _can_see_player(dist_to_player: float) -> bool:
	if not player:
		return false
	if dist_to_player > sight_range:
		return false
	if not _has_detected_player and not _is_position_in_front_half_sphere(player.global_position):
		return false
	return _has_clear_line_to_player()


func _has_clear_line_to_player() -> bool:
	if not player:
		return false
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * line_of_sight_eye_height
	var to := player.global_position + Vector3.UP * line_of_sight_target_height
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Object = result.get("collider")
	if collider == player:
		return true
	return collider is Node and player.is_ancestor_of(collider as Node)


func _remember_player_position() -> void:
	_has_last_known_player_position = true
	_last_known_player_position = player.global_position
	_time_since_player_seen = 0.0


func _forget_player() -> void:
	_has_detected_player = false
	_has_line_of_sight_to_player = false
	_has_last_known_player_position = false
	_time_since_player_seen = 0.0


func _is_position_in_front_half_sphere(target_position: Vector3) -> bool:
	var to_target := target_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true

	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return true

	return forward.normalized().dot(to_target.normalized()) >= detection_front_dot_min


func _chase_player() -> void:
	var dir := _flat_direction_to(player.global_position)
	velocity = dir * run_speed
	_face(player.global_position, FacingMode.FACE_MOVEMENT)
	_set_state(EnemyState.CHASE)


func _retreat_from_player() -> void:
	var away := _flat_direction_from(player.global_position)
	velocity = away * backpedal_speed
	_face(player.global_position, FacingMode.FACE_PLAYER)
	if _attack_timer <= 0.0:
		_begin_attack()
		return
	if _has_animation(walk_backward_animation):
		_set_state(EnemyState.BACKPEDAL)
	else:
		_set_state(EnemyState.IDLE)


func _combat_reposition() -> void:
	if _strafe_timer <= 0.0:
		_strafe_direction = -1 if randf() < 0.5 else 1
		_strafe_timer = strafe_decision_interval

	var to_player := _flat_direction_to(player.global_position)
	var tangent := Vector3(-to_player.z, 0.0, to_player.x) * float(_strafe_direction)
	velocity = tangent * strafe_speed
	_face(player.global_position, FacingMode.FACE_PLAYER)

	if _strafe_direction < 0 and _has_animation(strafe_left_animation):
		_set_state(EnemyState.STRAFE_LEFT)
	elif _strafe_direction > 0 and _has_animation(strafe_right_animation):
		_set_state(EnemyState.STRAFE_RIGHT)
	else:
		_set_state(EnemyState.IDLE)

	if _attack_timer <= 0.0:
		_begin_attack()


func _hold_and_attack() -> void:
	velocity = Vector3.ZERO
	_face(player.global_position, FacingMode.FACE_PLAYER)
	if _attack_timer <= 0.0:
		_begin_attack()
	else:
		_set_state(EnemyState.IDLE)


func _investigate_last_known_position() -> void:
	if not _has_last_known_player_position:
		_forget_player()
		velocity = Vector3.ZERO
		_set_state(EnemyState.IDLE)
		return

	var flat_distance := _flat_distance_to(_last_known_player_position)
	if flat_distance <= last_known_arrival_distance:
		velocity = Vector3.ZERO
		_face(_last_known_player_position, FacingMode.FACE_PLAYER)
		_set_state(EnemyState.IDLE)
		return

	var dir := _flat_direction_to(_last_known_player_position)
	velocity = dir * run_speed
	_face(_last_known_player_position, FacingMode.FACE_MOVEMENT)
	_set_state(EnemyState.CHASE)


func _begin_attack() -> void:
	if _state_locked or not player:
		return
	if not _has_line_of_sight_to_player:
		return
	_attack_timer = attack_cooldown
	_state_locked = true
	_set_state(EnemyState.ATTACK)
	_play_animation(fire_single_animation)

	get_tree().create_timer(attack_windup).timeout.connect(func():
		if _state != EnemyState.ATTACK or not is_instance_valid(player):
			return
		if not _has_clear_line_to_player():
			return
		if ranged_weapon and ranged_weapon.has_method("fire_at_player"):
			ranged_weapon.fire_at_player(player)
	, CONNECT_ONE_SHOT)

	var attack_len := _current_animation_length(0.65)
	get_tree().create_timer(maxf(attack_len, attack_windup + 0.15)).timeout.connect(func():
		if _state == EnemyState.ATTACK:
			_state_locked = false
			_set_state(EnemyState.IDLE)
	, CONNECT_ONE_SHOT)


func take_damage(amount: float) -> void:
	if _state == EnemyState.DEAD:
		return
	health -= amount
	if hit_flash:
		hit_flash.flash()
	damaged.emit()

	if health <= 0.0:
		_die()
		return

	if _state != EnemyState.ATTACK:
		_state_locked = true
		_set_state(EnemyState.HIT)
		var hit_len := _current_animation_length(0.45)
		get_tree().create_timer(hit_len).timeout.connect(func():
			if _state == EnemyState.HIT:
				_state_locked = false
				_set_state(EnemyState.IDLE)
		, CONNECT_ONE_SHOT)


func _die() -> void:
	_state = EnemyState.DEAD
	_state_locked = true
	velocity = Vector3.ZERO
	_play_animation(death_front_animation)
	died.emit()
	collision_layer = 0
	collision_mask = 0

	var death_len := _current_animation_length(2.0)
	get_tree().create_timer(death_len).timeout.connect(queue_free, CONNECT_ONE_SHOT)


func _set_state(new_state: EnemyState) -> void:
	if _state == new_state:
		return
	_state = new_state
	match _state:
		EnemyState.IDLE:
			_play_animation(aim_idle_animation)
		EnemyState.CHASE:
			_play_animation(run_forward_animation)
		EnemyState.STRAFE_LEFT:
			_play_animation(strafe_left_animation)
		EnemyState.STRAFE_RIGHT:
			_play_animation(strafe_right_animation)
		EnemyState.BACKPEDAL:
			_play_animation(walk_backward_animation)
		EnemyState.RETREAT_AWAY:
			_play_animation(run_backward_animation if _has_animation(run_backward_animation) else run_forward_animation)
		EnemyState.ATTACK:
			_play_animation(fire_single_animation)
		EnemyState.RELOAD:
			_play_animation(reload_animation)
		EnemyState.HIT:
			_play_animation(hit_front_animation)
		EnemyState.DEAD:
			_play_animation(death_front_animation)


func _play_animation(anim_name: String) -> void:
	if not animation_player or anim_name.is_empty():
		return
	var lib_anim := ENEMY_ANIMATION_LIBRARY + "/" + anim_name
	if animation_player.has_animation(lib_anim):
		if animation_player.current_animation != lib_anim:
			animation_player.play(lib_anim, 0.12)
	elif animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name, 0.12)


func _has_animation(anim_name: String) -> bool:
	if not animation_player or anim_name.is_empty():
		return false
	return animation_player.has_animation(ENEMY_ANIMATION_LIBRARY + "/" + anim_name) or animation_player.has_animation(anim_name)


func _current_animation_length(fallback: float) -> float:
	if animation_player and animation_player.is_playing():
		return maxf(animation_player.current_animation_length, fallback)
	return fallback


func _flat_direction_to(target: Vector3) -> Vector3:
	var dir := target - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else -global_transform.basis.z


func _flat_direction_from(target: Vector3) -> Vector3:
	var dir := global_position - target
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else global_transform.basis.z


func _flat_distance_to(target: Vector3) -> float:
	var offset := target - global_position
	offset.y = 0.0
	return offset.length()


func _face(target: Vector3, _mode: FacingMode) -> void:
	var look_target := target
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) < 0.001:
		return
	look_at(look_target, Vector3.UP)
