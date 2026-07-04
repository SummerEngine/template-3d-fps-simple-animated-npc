extends Node3D
class_name WeaponSystem

signal ammo_changed(current: int, reserve: int)
signal reloading_changed(is_reloading: bool)

@export var camera_path: NodePath
@export var hud_path: NodePath
@export var camera_shake_path: NodePath
@export var input_reader_path: NodePath = NodePath("../InputReader")

@onready var weapon_holder: Node3D = get_node(camera_path).get_node("WeaponHolder")
@onready var shoot_ray: RayCast3D = get_node(camera_path).get_node("ShootRay")
@onready var fallback_muzzle_node: Node3D = get_node_or_null("Muzzle") as Node3D
@onready var input_reader: FpsInputReader = get_node_or_null(input_reader_path) as FpsInputReader

var current_weapon: FPSWeaponProfile = null
var magazine_ammo: int = 0
var reserve_ammo: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var shoot_timer: float = 0.0
var _fire_stream_players: Array[AudioStreamPlayer3D] = []
var _ammo_state_by_weapon: Dictionary = {}
var _reload_tween: Tween = null
var _reload_sequence: int = 0
var _reload_weapon_key: String = ""


func _process(delta: float) -> void:
	if shoot_timer > 0.0:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			can_shoot = true

	if not current_weapon:
		return

	if input_reader and input_reader.is_reload_just_pressed() and not is_reloading:
		_start_reload()

	if is_reloading:
		return

	if current_weapon.is_automatic:
		if input_reader and input_reader.is_shoot_pressed():
			_fire()
	else:
		if input_reader and input_reader.is_shoot_just_pressed():
			_fire()


func equip(weapon: FPSWeaponProfile) -> void:
	if not weapon:
		return
	_save_current_ammo_state()
	_cancel_reload()
	current_weapon = weapon
	_load_ammo_state(weapon)
	can_shoot = true
	shoot_timer = 0.0
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	_play_weapon_anim(weapon.draw_anim if not weapon.draw_anim.is_empty() else weapon.base_pose_anim)


func _get_weapon_key(weapon: FPSWeaponProfile) -> String:
	if not weapon:
		return ""
	if not weapon.resource_path.is_empty():
		return weapon.resource_path
	return "%s:%d" % [weapon.weapon_name, weapon.get_instance_id()]


func _save_current_ammo_state() -> void:
	if not current_weapon:
		return
	_ammo_state_by_weapon[_get_weapon_key(current_weapon)] = {
		"magazine": magazine_ammo,
		"reserve": reserve_ammo,
	}


func _load_ammo_state(weapon: FPSWeaponProfile) -> void:
	var weapon_key := _get_weapon_key(weapon)
	if _ammo_state_by_weapon.has(weapon_key):
		var state: Dictionary = _ammo_state_by_weapon[weapon_key]
		magazine_ammo = clampi(int(state.get("magazine", weapon.magazine_size)), 0, weapon.magazine_size)
		reserve_ammo = clampi(int(state.get("reserve", weapon.max_ammo)), 0, weapon.max_ammo)
	else:
		magazine_ammo = weapon.magazine_size
		reserve_ammo = weapon.max_ammo
	_save_current_ammo_state()


func _fire() -> void:
	if not can_shoot or is_reloading:
		return
	if magazine_ammo <= 0:
		_start_reload()
		return

	magazine_ammo -= 1
	can_shoot = false
	shoot_timer = current_weapon.fire_rate
	_save_current_ammo_state()
	ammo_changed.emit(magazine_ammo, reserve_ammo)

	_perform_hitscan()
	_play_fire_audio()
	_show_muzzle_flash()
	_trigger_camera_shake(current_weapon.fire_camera_trauma)
	_play_weapon_anim(current_weapon.fire_anim)


func _perform_hitscan() -> void:
	var spread_angle := deg_to_rad(current_weapon.spread_degrees)
	var spread_radius := sqrt(randf()) * spread_angle
	var spread_theta := randf_range(0.0, TAU)
	var yaw := cos(spread_theta) * spread_radius
	var pitch := sin(spread_theta) * spread_radius
	var shot_direction := Vector3.FORWARD
	shot_direction = shot_direction.rotated(Vector3.UP, yaw)
	shot_direction = shot_direction.rotated(Vector3.RIGHT, pitch)
	shoot_ray.target_position = shot_direction.normalized() * current_weapon.shot_range

	shoot_ray.force_raycast_update()
	if shoot_ray.is_colliding():
		var collider := shoot_ray.get_collider()
		var hit_point := shoot_ray.get_collision_point()
		var hit_normal := shoot_ray.get_collision_normal()

		_spawn_impact(hit_point, hit_normal)

		if collider.has_method("take_damage"):
			collider.take_damage(current_weapon.damage)
			_trigger_camera_shake(current_weapon.hit_camera_trauma)

	shoot_ray.target_position = Vector3.FORWARD * current_weapon.shot_range


func _start_reload() -> void:
	if not current_weapon:
		return
	if is_reloading:
		return
	if magazine_ammo >= current_weapon.magazine_size:
		return
	if reserve_ammo <= 0:
		return

	is_reloading = true
	can_shoot = false
	reloading_changed.emit(true)

	_play_weapon_anim(current_weapon.reload_anim)

	_reload_sequence += 1
	_reload_weapon_key = _get_weapon_key(current_weapon)
	var reload_sequence := _reload_sequence
	var reload_weapon_key := _reload_weapon_key
	_reload_tween = create_tween()
	_reload_tween.tween_interval(current_weapon.reload_time)
	_reload_tween.tween_callback(func():
		_finish_reload(reload_sequence, reload_weapon_key)
	)


func _finish_reload(reload_sequence: int, weapon_key: String) -> void:
	if not current_weapon:
		return
	if reload_sequence != _reload_sequence or weapon_key != _get_weapon_key(current_weapon):
		return
	if not is_reloading:
		return
	var needed := current_weapon.magazine_size - magazine_ammo
	var available := mini(needed, reserve_ammo)
	magazine_ammo += available
	reserve_ammo -= available
	is_reloading = false
	can_shoot = true
	_reload_tween = null
	_reload_weapon_key = ""
	_save_current_ammo_state()
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	reloading_changed.emit(false)


func _cancel_reload() -> void:
	var was_reloading := is_reloading
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_tween = null
	_reload_sequence += 1
	_reload_weapon_key = ""
	is_reloading = false
	if current_weapon:
		can_shoot = true
	if was_reloading:
		reloading_changed.emit(false)


func _play_fire_audio() -> void:
	if not current_weapon.fire_sound:
		return

	var segments := current_weapon.fire_sound_segments
	if segments.is_empty():
		return

	var seg: Vector2 = segments[randi() % segments.size()]

	var asp := AudioStreamPlayer3D.new()
	asp.stream = current_weapon.fire_sound
	asp.bus = &"SFX"
	asp.unit_size = 2.0
	asp.max_distance = 50.0
	asp.autoplay = false
	asp.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	add_child(asp)
	asp.global_position = _get_active_muzzle().global_position

	asp.play(seg.x)
	_fire_stream_players.append(asp)

	# Stop after segment duration and free
	var duration := seg.y - seg.x
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(asp):
			asp.stop()
			asp.queue_free()
		_fire_stream_players.erase(asp)
	, CONNECT_ONE_SHOT)


func _show_muzzle_flash() -> void:
	var flash := _get_active_muzzle_flash()
	if not flash:
		return
	flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(flash):
			flash.visible = false
	, CONNECT_ONE_SHOT)


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var effects_node := get_tree().current_scene.get_node_or_null("Effects")
	if not effects_node:
		effects_node = get_tree().current_scene

	var impact := Node3D.new()
	effects_node.add_child(impact)
	impact.global_position = point
	if normal.length() > 0.01:
		if abs(normal.x) > 0.5:
			impact.look_at(point + normal, Vector3.UP)
		else:
			impact.look_at(point + normal, Vector3.FORWARD)

	# Simple GPUParticles3D for impact
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.5
	particles.process_material = _make_impact_material()
	var draw_pass := QuadMesh.new()
	draw_pass.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = draw_pass
	particles.finished.connect(particles.queue_free)
	impact.add_child(particles)
	# Auto-free after lifetime
	get_tree().create_timer(1.0).timeout.connect(impact.queue_free, CONNECT_ONE_SHOT)


func _make_impact_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.spread = 45.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color(0.8, 0.7, 0.5, 1.0)
	mat.color_ramp = _make_color_ramp()
	return mat


func _make_color_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 0.8, 1), Color(0.6, 0.4, 0.2, 0.5), Color(0.3, 0.2, 0.1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


func _trigger_camera_shake(trauma: float) -> void:
	if not camera_shake_path or camera_shake_path.is_empty():
		return
	var shake_node := get_node_or_null(camera_shake_path) as Node
	if shake_node and shake_node.has_method("add_trauma"):
		shake_node.add_trauma(trauma)


func _get_active_viewmodel() -> Node3D:
	if not weapon_holder:
		return null
	for child in weapon_holder.get_children():
		if child is Node3D and child.visible:
			return child as Node3D
	return weapon_holder.get_node_or_null("RifleViewmodel") as Node3D


func _get_active_muzzle() -> Node3D:
	var viewmodel := _get_active_viewmodel()
	var viewmodel_muzzle := viewmodel.get_node_or_null("Muzzle") as Node3D if viewmodel else null
	if viewmodel_muzzle:
		return viewmodel_muzzle
	return fallback_muzzle_node


func _get_active_muzzle_flash() -> Sprite3D:
	var viewmodel := _get_active_viewmodel()
	if not viewmodel:
		return null
	var muzzle_flash := viewmodel.get_node_or_null("Muzzle/MuzzleFlash") as Sprite3D
	if muzzle_flash:
		return muzzle_flash
	return viewmodel.get_node_or_null("MuzzleFlash") as Sprite3D


func _get_loadout() -> WeaponLoadout:
	return get_parent().get_node_or_null("WeaponLoadout") as WeaponLoadout


func _play_weapon_anim(anim_name: String) -> void:
	if anim_name.is_empty():
		return
	var loadout := _get_loadout()
	if not loadout:
		return
	var ap := loadout._weapon_anim_player
	if not ap:
		return
	var library_list: Array = ap.get_animation_library_list()
	if library_list.is_empty():
		return
	var full_name: String = library_list[0] + "/" + anim_name
	if ap.has_animation(full_name):
		ap.play(full_name, 0.05)
	elif ap.has_animation(anim_name):
		ap.play(anim_name, 0.05)
