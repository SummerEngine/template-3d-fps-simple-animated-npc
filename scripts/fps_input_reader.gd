extends Node
class_name FpsInputReader

signal pointer_capture_changed(captured: bool)

@export_group("Movement Actions")
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var move_forward_action: StringName = &"move_forward"
@export var move_back_action: StringName = &"move_back"
@export var jump_action: StringName = &"jump"
@export var sprint_action: StringName = &"sprint"
@export var crouch_action: StringName = &"crouch"

@export_group("Combat Actions")
@export var shoot_action: StringName = &"shoot"
@export var aim_action: StringName = &"aim"
@export var reload_action: StringName = &"reload"
@export var weapon_1_action: StringName = &"weapon_1"
@export var weapon_2_action: StringName = &"weapon_2"

@export_group("Look Actions")
@export var look_left_action: StringName = &"look_left"
@export var look_right_action: StringName = &"look_right"
@export var look_up_action: StringName = &"look_up"
@export var look_down_action: StringName = &"look_down"
@export var action_look_pixels_per_second: float = 480.0

@export_group("Pointer Capture")
@export var capture_pointer_on_ready: bool = true
@export var release_pointer_action: StringName = &"ui_cancel"
@export var recapture_pointer_action: StringName = &"shoot"

var _pointer_look_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	if capture_pointer_on_ready:
		capture_pointer()


func _unhandled_input(event: InputEvent) -> void:
	if _event_action_pressed(event, release_pointer_action):
		release_pointer()
		get_viewport().set_input_as_handled()
		return

	if not is_pointer_captured() and _event_action_pressed(event, recapture_pointer_action):
		capture_pointer()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and is_pointer_captured():
		_pointer_look_delta += event.relative
		get_viewport().set_input_as_handled()


func get_movement_vector() -> Vector2:
	return _get_action_vector(move_left_action, move_right_action, move_forward_action, move_back_action)


func consume_look_delta(delta: float) -> Vector2:
	var look_delta := _pointer_look_delta
	_pointer_look_delta = Vector2.ZERO
	look_delta += _get_action_vector(look_left_action, look_right_action, look_up_action, look_down_action) * action_look_pixels_per_second * delta
	return look_delta


func is_jump_just_pressed() -> bool:
	return _is_action_just_pressed(jump_action)


func is_sprint_pressed() -> bool:
	return _is_action_pressed(sprint_action)


func is_crouch_just_pressed() -> bool:
	return _is_action_just_pressed(crouch_action)


func is_shoot_pressed() -> bool:
	return _is_action_pressed(shoot_action)


func is_shoot_just_pressed() -> bool:
	return _is_action_just_pressed(shoot_action)


func is_aim_pressed() -> bool:
	return _is_action_pressed(aim_action)


func is_reload_just_pressed() -> bool:
	return _is_action_just_pressed(reload_action)


func is_weapon_slot_just_pressed(slot_index: int) -> bool:
	match slot_index:
		0:
			return _is_action_just_pressed(weapon_1_action)
		1:
			return _is_action_just_pressed(weapon_2_action)
		_:
			return false


func capture_pointer() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pointer_capture_changed.emit(true)


func release_pointer() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pointer_capture_changed.emit(false)


func is_pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _get_action_vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName) -> Vector2:
	var vector := Vector2(
		_get_action_strength(positive_x) - _get_action_strength(negative_x),
		_get_action_strength(positive_y) - _get_action_strength(negative_y)
	)
	return vector.normalized() if vector.length_squared() > 1.0 else vector


func _get_action_strength(action: StringName) -> float:
	if not _has_action(action):
		return 0.0
	return Input.get_action_strength(action)


func _is_action_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_pressed(action)


func _is_action_just_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_just_pressed(action)


func _event_action_pressed(event: InputEvent, action: StringName) -> bool:
	return _has_action(action) and event.is_action_pressed(action)


func _has_action(action: StringName) -> bool:
	return not String(action).is_empty() and InputMap.has_action(action)
