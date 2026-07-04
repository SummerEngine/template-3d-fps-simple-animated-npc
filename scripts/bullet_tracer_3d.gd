extends Node3D
class_name BulletTracer3D

@export var speed: float = 80.0
@export var lifetime: float = 0.5

var start_point: Vector3
var end_point: Vector3
var time_alive: float = 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, 1.0)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)
	global_position = start_point
	look_at(end_point, Vector3.UP)


func _process(delta: float) -> void:
	time_alive += delta
	var t := time_alive / lifetime
	if t >= 1.0:
		queue_free()
		return
	global_position = start_point.lerp(end_point, t)
