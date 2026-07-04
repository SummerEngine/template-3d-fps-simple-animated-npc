extends Node3D
class_name HitFlash3D

@export var flash_material: Material = null
@export var flash_duration: float = 0.1
@export var flash_color: Color = Color(1.0, 0.3, 0.3)
@export var emission_multiplier: float = 2.0

var _snapshots: Array[Dictionary] = []
var _restore_tween: Tween = null
var _is_flashing: bool = false


func flash() -> void:
	if _restore_tween and _restore_tween.is_valid():
		_restore_tween.kill()
	if _is_flashing:
		_restore_materials()
	_apply_flash()
	_restore_tween = create_tween()
	_restore_tween.tween_interval(maxf(flash_duration, 0.01))
	_restore_tween.tween_callback(_restore_materials)


func _apply_flash() -> void:
	_snapshots.clear()
	_is_flashing = true
	var parent := get_parent()
	if parent:
		_recursive_flash(parent)


func _recursive_flash(node: Node) -> void:
	if node is MeshInstance3D:
		_flash_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_recursive_flash(child)


func _flash_mesh(mesh_instance: MeshInstance3D) -> void:
	var surface_count := _get_surface_count(mesh_instance)
	var surface_overrides: Array[Material] = []
	for surface_index in range(surface_count):
		surface_overrides.append(mesh_instance.get_surface_override_material(surface_index))

	_snapshots.append({
		"mesh_instance": mesh_instance,
		"material_override": mesh_instance.material_override,
		"surface_overrides": surface_overrides,
	})

	if mesh_instance.material_override:
		mesh_instance.material_override = _make_flash_material(mesh_instance.material_override)
		return

	if surface_count == 0:
		mesh_instance.material_override = _make_flash_material(null)
		return

	for surface_index in range(surface_count):
		var source_material := surface_overrides[surface_index]
		if not source_material and mesh_instance.mesh:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)
		mesh_instance.set_surface_override_material(surface_index, _make_flash_material(source_material))


func _restore_materials() -> void:
	_is_flashing = false
	for snapshot in _snapshots:
		var mesh_instance := snapshot.get("mesh_instance") as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		mesh_instance.material_override = snapshot.get("material_override") as Material
		var surface_overrides: Array = snapshot.get("surface_overrides", [])
		for surface_index in range(surface_overrides.size()):
			mesh_instance.set_surface_override_material(surface_index, surface_overrides[surface_index])
	_snapshots.clear()


func _get_surface_count(mesh_instance: MeshInstance3D) -> int:
	var override_count := mesh_instance.get_surface_override_material_count()
	if override_count > 0:
		return override_count
	if mesh_instance.mesh:
		return mesh_instance.mesh.get_surface_count()
	return 0


func _make_flash_material(source_material: Material) -> Material:
	var material: Material = null
	if flash_material:
		material = flash_material.duplicate() as Material
	elif source_material and source_material is BaseMaterial3D:
		material = source_material.duplicate() as Material
	else:
		material = StandardMaterial3D.new()

	var base_material := material as BaseMaterial3D
	if base_material:
		base_material.albedo_color = flash_color
		base_material.emission_enabled = true
		base_material.emission = flash_color
		base_material.emission_energy_multiplier = emission_multiplier
	return material
