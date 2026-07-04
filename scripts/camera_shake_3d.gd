extends Node3D
class_name CameraShake3D

@export var target_camera_path: NodePath
@export var trauma_reduction: float = 2.5
@export var max_offset: Vector2 = Vector2(0.035, 0.025)
@export var max_rotation: Vector3 = Vector3(1.25, 0.85, 0.35)
@export var noise_speed: float = 18.0

var trauma: float = 0.0
var noise: FastNoiseLite
var _shake_target: Node3D
var _noise_time: float = 0.0
var _last_position_offset: Vector3 = Vector3.ZERO
var _last_rotation_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_shake_target = _resolve_shake_target()
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.8


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_shake_target):
		_shake_target = null

	if _shake_target == null:
		_shake_target = _resolve_shake_target()
		if _shake_target == null:
			return

	_remove_last_offset()

	if trauma <= 0.0:
		trauma = 0.0
		set_process(false)
		return

	var shake := trauma * trauma
	_noise_time += delta * noise_speed

	_last_position_offset = Vector3(
		noise.get_noise_2d(_noise_time, 0.0) * max_offset.x * shake,
		noise.get_noise_2d(0.0, _noise_time) * max_offset.y * shake,
		0.0
	)
	_last_rotation_offset = Vector3(
		noise.get_noise_2d(_noise_time * 1.3, 100.0) * deg_to_rad(max_rotation.x) * shake,
		noise.get_noise_2d(_noise_time * 1.5, 200.0) * deg_to_rad(max_rotation.y) * shake,
		noise.get_noise_2d(_noise_time * 1.7, 300.0) * deg_to_rad(max_rotation.z) * shake
	)
	_shake_target.position += _last_position_offset
	_shake_target.rotation += _last_rotation_offset
	trauma = maxf(trauma - trauma_reduction * delta, 0.0)


func _exit_tree() -> void:
	_remove_last_offset()


func _remove_last_offset() -> void:
	if not is_instance_valid(_shake_target):
		_shake_target = null
		_last_position_offset = Vector3.ZERO
		_last_rotation_offset = Vector3.ZERO
		return
	if _shake_target == null:
		return
	if _last_position_offset != Vector3.ZERO:
		_shake_target.position -= _last_position_offset
		_last_position_offset = Vector3.ZERO
	if _last_rotation_offset != Vector3.ZERO:
		_shake_target.rotation -= _last_rotation_offset
		_last_rotation_offset = Vector3.ZERO


func _resolve_shake_target() -> Node3D:
	if not target_camera_path.is_empty():
		var configured_target := get_node_or_null(target_camera_path)
		if configured_target is Node3D:
			return configured_target as Node3D

	var parent_node := get_parent()
	if parent_node is Camera3D:
		return parent_node as Node3D
	return self
