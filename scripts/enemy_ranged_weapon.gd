extends Node3D
class_name EnemyRangedWeapon

@export var damage: float = 8.0
@export var shot_range: float = 45.0
@export var spread_degrees: float = 2.0
@export var fire_cooldown: float = 1.0
@export var shoot_mask: int = 3  # environment + player (layers 1 and 2)
@export var require_line_of_sight: bool = true
@export var target_height: float = 1.0

# Audio
@export var fire_sound: AudioStream = null
@export var fire_sound_segments: Array[Vector2] = []
@export var randomize_fire_sound_segments: bool = true
@export var fire_volume_db: float = -9.0
@export var fire_max_distance: float = 32.0
@export var fire_unit_size: float = 5.0
@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var muzzle_flash_path: NodePath = NodePath("Muzzle/MuzzleFlash")

@onready var muzzle_node: Node3D = _resolve_muzzle_node()
@onready var muzzle_flash: Sprite3D = _resolve_muzzle_flash()

var _can_fire: bool = true
var _space_state: PhysicsDirectSpaceState3D
var _tracer_scene: PackedScene


func _ready() -> void:
	_space_state = get_world_3d().direct_space_state
	if muzzle_flash:
		muzzle_flash.visible = false
	# Try to preload tracer scene
	if ResourceLoader.exists("res://scenes/vfx/BulletTracer3D.tscn"):
		_tracer_scene = load("res://scenes/vfx/BulletTracer3D.tscn")


func _resolve_muzzle_node() -> Node3D:
	var configured := get_node_or_null(muzzle_path) as Node3D
	if configured:
		return configured
	var fallback := get_node_or_null("Muzzle") as Node3D
	if fallback:
		return fallback
	push_warning("[EnemyRangedWeapon] No muzzle found; using weapon node position.")
	return self


func _resolve_muzzle_flash() -> Sprite3D:
	var configured := get_node_or_null(muzzle_flash_path) as Sprite3D
	if configured:
		return configured
	if muzzle_node:
		return muzzle_node.get_node_or_null("MuzzleFlash") as Sprite3D
	return null


func fire_at_player(player: PlayerController) -> void:
	if not _can_fire:
		return
	if not player:
		return
	if require_line_of_sight and not _has_clear_line_to_player(player):
		return

	_can_fire = false
	_perform_shot(player)
	_show_muzzle_flash()
	_play_fire_audio()

	get_tree().create_timer(fire_cooldown).timeout.connect(func():
		_can_fire = true
	, CONNECT_ONE_SHOT)


func _has_clear_line_to_player(player: PlayerController) -> bool:
	var muzzle_pos := muzzle_node.global_position
	var target_pos := player.global_position + Vector3.UP * target_height
	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, target_pos, shoot_mask)
	query.exclude = [get_parent(), self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Object = result.get("collider")
	if collider == player:
		return true
	return collider is Node and player.is_ancestor_of(collider as Node)


func _perform_shot(player: PlayerController) -> void:
	var muzzle_pos := muzzle_node.global_position
	var to_player := player.global_position - muzzle_pos

	# Apply spread
	var spread_rad := deg_to_rad(spread_degrees)
	var spread := Vector3(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad),
		0.0
	)
	var dir := to_player.normalized()
	dir = dir.rotated(Vector3.UP, spread.x)
	dir = dir.rotated(Vector3.RIGHT, spread.y)

	var target := muzzle_pos + dir * shot_range

	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, target, shoot_mask)
	query.exclude = [get_parent()]
	var result := _space_state.intersect_ray(query)

	# Spawn tracer
	_spawn_tracer(muzzle_pos, result.get("position", target))

	if not result.is_empty():
		var collider: Object = result.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage)

		# Spawn impact
		_spawn_impact(result["position"], result.get("normal", Vector3.UP))


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var root := get_tree().current_scene
	if _tracer_scene:
		var tracer := _tracer_scene.instantiate()
		root.add_child(tracer)
		tracer.start_point = from
		tracer.end_point = to
	else:
		# Quick runtime tracer
		var tracer := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.02, from.distance_to(to))
		tracer.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.1)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tracer.material_override = mat
		root.add_child(tracer)
		tracer.global_position = from.lerp(to, 0.5)
		if tracer.is_inside_tree():
			tracer.look_at(to, Vector3.UP)
		get_tree().create_timer(0.15).timeout.connect(tracer.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var effects_node := get_tree().current_scene.get_node_or_null("Effects")
	if not effects_node:
		return
	var impact := Node3D.new()
	effects_node.add_child(impact)
	impact.global_position = point
	if normal.length() > 0.01:
		if abs(normal.x) > 0.5:
			impact.look_at(point + normal, Vector3.UP)
		else:
			impact.look_at(point + normal, Vector3.FORWARD)
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 6
	particles.lifetime = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.spread = 30.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.color = Color(0.9, 0.5, 0.2, 1.0)
	particles.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = qm
	particles.finished.connect(particles.queue_free)
	impact.add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(impact.queue_free, CONNECT_ONE_SHOT)


func _show_muzzle_flash() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
		, CONNECT_ONE_SHOT)


func _play_fire_audio() -> void:
	if not fire_sound:
		return
	var segments := fire_sound_segments
	if segments.is_empty():
		return

	var seg: Vector2 = segments[randi() % segments.size()]

	var asp := AudioStreamPlayer3D.new()
	asp.stream = fire_sound
	asp.bus = &"SFX"
	asp.volume_db = fire_volume_db
	asp.max_distance = fire_max_distance
	asp.unit_size = fire_unit_size
	add_child(asp)
	asp.global_position = muzzle_node.global_position

	asp.play(seg.x)
	var duration := seg.y - seg.x
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(asp):
			asp.stop()
			asp.queue_free()
	, CONNECT_ONE_SHOT)
