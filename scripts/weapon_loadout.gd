extends Node3D
class_name WeaponLoadout

signal weapon_changed(weapon: FPSWeaponProfile)

const RIFLE_MATERIAL_PATH := "res://materials/first_person_rifle_material.tres"
const PISTOL_MATERIAL_PATH := "res://materials/first_person_pistol_material.tres"
const MUZZLE_FLASH_LOCAL_OFFSET := Vector3(0.0, 0.05, 0.0)

@export var weapon_profiles: Array = []
@export var weapon_system_path: NodePath
@export var input_reader_path: NodePath = NodePath("../InputReader")

@onready var weapon_system: WeaponSystem = get_node(weapon_system_path)
@onready var weapon_holder: Node3D = weapon_system.get_node("../Head/Camera3D/WeaponHolder")
@onready var input_reader: FpsInputReader = get_node_or_null(input_reader_path) as FpsInputReader

var current_index: int = -1
var _weapon_models: Dictionary = {}
var _weapon_anim_players: Dictionary = {}
var _weapon_anim_player: AnimationPlayer = null


func _ready() -> void:
	if weapon_profiles.size() > 0:
		switch_to(0)


func _process(_delta: float) -> void:
	if not input_reader:
		return
	if input_reader.is_weapon_slot_just_pressed(0):
		switch_to(0)
	elif input_reader.is_weapon_slot_just_pressed(1):
		switch_to(1)


func switch_to(index: int) -> void:
	if index < 0 or index >= weapon_profiles.size():
		return
	if index == current_index:
		return

	var profile := weapon_profiles[index] as FPSWeaponProfile
	if not profile:
		return

	var viewmodel := _get_or_load_weapon_model(index, profile)
	if not viewmodel:
		push_warning("[WeaponLoadout] Could not equip %s because its viewmodel failed to load." % profile.weapon_name)
		return

	for child in weapon_holder.get_children():
		if child is Node3D:
			(child as Node3D).visible = false

	viewmodel.visible = true
	_activate_weapon_model(index, viewmodel)
	current_index = index
	weapon_system.equip(profile)
	weapon_changed.emit(profile)


func _get_or_load_weapon_model(index: int, profile: FPSWeaponProfile) -> Node3D:
	var cached := _weapon_models.get(index) as Node3D
	if is_instance_valid(cached):
		return cached
	_weapon_models.erase(index)

	var viewmodel := _load_weapon_model(index, profile)
	if viewmodel:
		_weapon_models[index] = viewmodel
	return viewmodel


func _load_weapon_model(index: int, profile: FPSWeaponProfile) -> Node3D:
	var viewmodel: Node3D = null

	if index == 0:
		viewmodel = weapon_holder.get_node_or_null("RifleViewmodel") as Node3D

	if not viewmodel:
		viewmodel = _create_viewmodel(profile)
		if viewmodel:
			weapon_holder.add_child(viewmodel)

	if not viewmodel:
		return null

	_prepare_viewmodel(index, viewmodel, profile)
	viewmodel.visible = false
	return viewmodel


func _create_viewmodel(profile: FPSWeaponProfile) -> Node3D:
	var weapon_vis := _instantiate_model(profile.weapon_model_path, "WeaponVisual")
	if not weapon_vis:
		return null

	var viewmodel := Node3D.new()
	var clean_name := profile.weapon_name.strip_edges().replace(" ", "")
	viewmodel.name = ("%sViewmodel" % clean_name) if not clean_name.is_empty() else "WeaponViewmodel"

	weapon_vis.transform = _weapon_viewmodel_transform()
	viewmodel.add_child(weapon_vis)

	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	viewmodel.add_child(muzzle)

	var muzzle_flash := _make_muzzle_flash()
	muzzle_flash.name = "MuzzleFlash"
	muzzle.add_child(muzzle_flash)

	return viewmodel


func _instantiate_model(model_path: String, node_name: String) -> Node3D:
	if model_path.is_empty():
		return null
	if not ResourceLoader.exists(model_path):
		push_warning("[WeaponLoadout] Missing model: %s" % model_path)
		return null
	var scene := load(model_path) as PackedScene
	if not scene:
		push_warning("[WeaponLoadout] Could not load model scene: %s" % model_path)
		return null
	var instance := scene.instantiate() as Node3D
	if not instance:
		push_warning("[WeaponLoadout] Model root is not Node3D: %s" % model_path)
		return null
	instance.name = node_name
	return instance


func _prepare_viewmodel(index: int, viewmodel: Node3D, profile: FPSWeaponProfile) -> void:
	var weapon_vis := _get_weapon_visual(viewmodel)
	var muzzle_flash := _get_muzzle_flash(viewmodel)

	if weapon_vis:
		_apply_weapon_material(weapon_vis, profile)
		_align_muzzle_to_barrel(viewmodel, weapon_vis, muzzle_flash)

	_import_animations(index, viewmodel, profile)


func _activate_weapon_model(index: int, viewmodel: Node3D) -> void:
	_weapon_anim_player = _weapon_anim_players.get(index) as AnimationPlayer

	if not is_instance_valid(_weapon_anim_player):
		_weapon_anim_player = _get_or_create_anim_player(_get_weapon_visual(viewmodel))


func _get_weapon_visual(viewmodel: Node) -> Node3D:
	var explicit := viewmodel.get_node_or_null("WeaponVisual") as Node3D
	if explicit:
		return explicit
	var rifle_visual := viewmodel.get_node_or_null("RifleVisual") as Node3D
	if rifle_visual:
		return rifle_visual
	for child in viewmodel.get_children():
		if child is Node3D and child.name != "Muzzle":
			return child as Node3D
	return null


func _get_muzzle_flash(viewmodel: Node) -> Sprite3D:
	var nested := viewmodel.get_node_or_null("Muzzle/MuzzleFlash") as Sprite3D
	if nested:
		return nested
	return viewmodel.get_node_or_null("MuzzleFlash") as Sprite3D


func _apply_weapon_material(node: Node, profile: FPSWeaponProfile) -> void:
	var material_path := _get_weapon_material_path(profile)
	if material_path.is_empty():
		return
	_apply_material(node, material_path)


func _get_weapon_material_path(profile: FPSWeaponProfile) -> String:
	var key := ("%s %s" % [profile.weapon_name, profile.weapon_model_path]).to_lower()
	if key.contains("pistol"):
		return PISTOL_MATERIAL_PATH
	if key.contains("rifle"):
		return RIFLE_MATERIAL_PATH
	return ""


func _apply_material(node: Node, material_path: String) -> void:
	var mat := load(material_path) as StandardMaterial3D
	if not mat:
		push_warning("[WeaponLoadout] Failed to load material: %s" % material_path)
		return
	for mesh_inst in node.find_children("*", "MeshInstance3D", true, false):
		(mesh_inst as MeshInstance3D).material_override = mat


func _import_animations(index: int, viewmodel: Node, profile: FPSWeaponProfile) -> void:
	var weapon_ap := _get_or_create_anim_player(_get_weapon_visual(viewmodel))

	_merge_fbx_animations(weapon_ap, [
		[profile.weapon_anim_base_pose_fbx, profile.base_pose_anim],
		[profile.weapon_anim_fire_fbx, profile.fire_anim],
		[profile.weapon_anim_reload_fbx, profile.reload_anim],
	], "weapon")

	_weapon_anim_players[index] = weapon_ap
	_weapon_anim_player = weapon_ap

	_play_base_pose(weapon_ap, "weapon", profile.base_pose_anim)


func _get_or_create_anim_player(parent: Node) -> AnimationPlayer:
	if not parent:
		return null
	for child in parent.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	parent.add_child(ap)
	return ap


func _merge_fbx_animations(ap: AnimationPlayer, fbx_pairs: Array, label: String) -> void:
	if not ap:
		return
	var merged := AnimationLibrary.new()
	for entry in fbx_pairs:
		var fbx_path: String = entry[0] as String
		var target_name: String = entry[1] as String
		if fbx_path.is_empty() or target_name.is_empty():
			continue
		var lib := _extract_animation(fbx_path)
		if lib:
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				if anim and not merged.has_animation(target_name):
					merged.add_animation(target_name, anim.duplicate())
					break
		else:
			push_warning("[WeaponLoadout] Failed to extract animation from %s" % fbx_path)

	if merged.get_animation_list().is_empty():
		return

	if ap.has_animation_library(label):
		ap.remove_animation_library(label)
	ap.add_animation_library(label, merged)


func _extract_animation(fbx_path: String) -> AnimationLibrary:
	var scene := load(fbx_path) as PackedScene
	if not scene:
		push_warning("[WeaponLoadout] Failed to load animation scene: %s" % fbx_path)
		return null
	var inst := scene.instantiate()
	var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not ap or ap.get_animation_list().is_empty():
		push_warning("[WeaponLoadout] No AnimationPlayer in %s" % fbx_path)
		inst.queue_free()
		return null
	var lib := AnimationLibrary.new()
	for anim_name in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		if anim:
			lib.add_animation(anim_name, anim.duplicate())
	inst.queue_free()
	return lib


func _play_base_pose(ap: AnimationPlayer, library_name: String, anim_name: String) -> void:
	if not ap or anim_name.is_empty():
		return
	var pose_path := "%s/%s" % [library_name, anim_name]
	if ap.has_animation(pose_path):
		ap.play(pose_path)
	elif ap.has_animation(anim_name):
		ap.play(anim_name)


func _align_muzzle_to_barrel(viewmodel: Node3D, weapon_vis: Node3D, muzzle_flash: Sprite3D) -> void:
	var muzzle := viewmodel.get_node_or_null("Muzzle") as Node3D
	if not muzzle:
		muzzle = Node3D.new()
		muzzle.name = "Muzzle"
		viewmodel.add_child(muzzle)

	var barrel_pos := Vector3(0.25, -0.05, -0.85)
	var best_z := INF
	for child in weapon_vis.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		var mesh := mesh_inst.mesh
		if mesh:
			var aabb := mesh.get_aabb()
			for x in [aabb.position.x, aabb.position.x + aabb.size.x]:
				for y in [aabb.position.y, aabb.position.y + aabb.size.y]:
					for z in [aabb.position.z, aabb.position.z + aabb.size.z]:
						var local_corner := Vector3(x, y, z)
						var world_corner := mesh_inst.global_transform * local_corner
						var viewmodel_corner := viewmodel.to_local(world_corner)
						if viewmodel_corner.z < best_z:
							best_z = viewmodel_corner.z
							barrel_pos = viewmodel_corner

	barrel_pos.z -= 0.05
	muzzle.position = barrel_pos

	if muzzle_flash:
		if muzzle_flash.get_parent() != muzzle:
			muzzle_flash.reparent(muzzle, false)
		muzzle_flash.position = MUZZLE_FLASH_LOCAL_OFFSET
		muzzle_flash.visible = false


func _make_muzzle_flash() -> Sprite3D:
	var source := weapon_holder.get_node_or_null("RifleViewmodel/Muzzle/MuzzleFlash") as Sprite3D
	if not source:
		source = weapon_holder.get_node_or_null("RifleViewmodel/MuzzleFlash") as Sprite3D
	var flash := source.duplicate() as Sprite3D if source else Sprite3D.new()
	flash.visible = false
	return flash


func _weapon_viewmodel_transform() -> Transform3D:
	return Transform3D(
		Basis(
			Vector3(0.0, 0.0, -1.0),
			Vector3(0.0, 1.0, 0.0),
			Vector3(1.0, 0.0, 0.0)
		),
		Vector3.ZERO
	)
