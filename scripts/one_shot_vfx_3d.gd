extends Node3D
class_name OneShotVFX3D

@export var particle_lifetime: float = 0.8
@export var auto_free: bool = true

var _timer: float = 0.0


func _ready() -> void:
	# Start any GPUParticles3D children
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			child.one_shot = true


func _process(delta: float) -> void:
	_timer += delta
	if auto_free and _timer >= particle_lifetime:
		queue_free()
