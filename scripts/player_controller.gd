extends CharacterBody3D
class_name PlayerController

signal health_changed(new_health: float)
signal damaged(amount: float)
signal died()

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var ground_accel: float = 80.0
@export var ground_friction: float = 90.0
@export var air_accel: float = 25.0
@export var air_friction: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity_multiplier: float = 1.0
@export var fall_gravity_multiplier: float = 1.4
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var mouse_sensitivity: float = 0.002
@export var fov_default: float = 70.0
@export var fov_sprint: float = 80.0
@export var fov_aim: float = 50.0
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var external_damping: float = 8.0
@export var damage_camera_trauma: float = 0.25
@export var input_reader_path: NodePath = NodePath("InputReader")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var standing_shape: CollisionShape3D = $StandingShape
@onready var crouching_shape: CollisionShape3D = $CrouchingShape
@onready var ceiling_check: RayCast3D = $CeilingCheck
@onready var shoot_ray: RayCast3D = $Head/Camera3D/ShootRay
@onready var input_reader: FpsInputReader = get_node_or_null(input_reader_path) as FpsInputReader

var is_crouching: bool = false
var is_sprinting: bool = false
var is_dead: bool = false
var current_speed: float = 0.0
var stamina: float = 100.0
var stamina_regen_rate: float = 15.0
var stamina_drain_rate: float = 20.0
var external_velocity: Vector3 = Vector3.ZERO

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _previous_external_applied: Vector3 = Vector3.ZERO


func _ready() -> void:
	crouching_shape.disabled = true
	camera.fov = fov_default
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_look(delta)
	velocity -= _previous_external_applied
	_previous_external_applied = Vector3.ZERO
	_handle_gravity(delta)
	_handle_crouch_input()
	_handle_sprint(delta)
	_update_jump_timers(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_crouch_lerp(delta)
	_handle_fov(delta)
	_apply_external_velocity(delta)
	move_and_slide()


func _handle_look(delta: float) -> void:
	if not input_reader:
		return
	var look_delta := input_reader.consume_look_delta(delta)
	if look_delta == Vector2.ZERO:
		return
	rotate_y(-look_delta.x * mouse_sensitivity)
	head.rotate_x(-look_delta.y * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _handle_gravity(delta: float) -> void:
	var base_gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_multiplier
	if not is_on_floor():
		var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= base_gravity * gravity_scale * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if input_reader and input_reader.is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _handle_movement(delta: float) -> void:
	var input_dir := input_reader.get_movement_vector() if input_reader else Vector2.ZERO
	var direction := transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO

	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting and stamina > 0.0:
		current_speed = sprint_speed
	else:
		current_speed = walk_speed

	var accel := ground_accel if is_on_floor() else air_accel
	var friction := ground_friction if is_on_floor() else air_friction
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if direction.length_squared() > 0.0:
		horizontal = horizontal.move_toward(direction * current_speed, accel * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not is_crouching:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _handle_sprint(delta: float) -> void:
	var move_input := input_reader.get_movement_vector() if input_reader else Vector2.ZERO
	var wants_sprint := false
	if input_reader:
		wants_sprint = input_reader.is_sprint_pressed() and not is_crouching
	var moving := move_input.length() > 0.1
	if wants_sprint and moving and stamina > 0.0:
		is_sprinting = true
		stamina = maxf(stamina - stamina_drain_rate * delta, 0.0)
	else:
		is_sprinting = false
		stamina = minf(stamina + stamina_regen_rate * delta, 100.0)


func _handle_crouch_input() -> void:
	if input_reader and input_reader.is_crouch_just_pressed():
		_toggle_crouch()


func _toggle_crouch() -> void:
	if is_crouching:
		if ceiling_check.is_colliding():
			return
		is_crouching = false
		standing_shape.disabled = false
		crouching_shape.disabled = true
	else:
		is_crouching = true
		is_sprinting = false
		standing_shape.disabled = true
		crouching_shape.disabled = false


func _handle_crouch_lerp(delta: float) -> void:
	var target_y: float = 0.8 if is_crouching else 1.5
	head.position.y = lerpf(head.position.y, target_y, 8.0 * delta)


func _handle_fov(delta: float) -> void:
	var target_fov := fov_default
	if is_sprinting:
		target_fov = fov_sprint
	elif input_reader and input_reader.is_aim_pressed():
		target_fov = fov_aim
	camera.fov = lerpf(camera.fov, target_fov, 5.0 * delta)


func _apply_external_velocity(delta: float) -> void:
	velocity += external_velocity
	_previous_external_applied = external_velocity
	external_velocity = external_velocity.move_toward(Vector3.ZERO, external_damping * delta)


func add_external_velocity(impulse: Vector3) -> void:
	external_velocity += impulse


func take_damage(amount: float) -> void:
	if is_dead:
		return
	var previous_health := health
	health = maxf(health - amount, 0.0)
	var actual_damage := previous_health - health
	if actual_damage > 0.0:
		damaged.emit(actual_damage)
		_trigger_damage_camera_feedback()
	health_changed.emit(health)
	if health <= 0.0:
		_die()


func _trigger_damage_camera_feedback() -> void:
	var shake_node := camera.get_node_or_null("CameraShake")
	if shake_node and shake_node.has_method("add_trauma"):
		shake_node.add_trauma(damage_camera_trauma)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
	_previous_external_applied = Vector3.ZERO
	if input_reader:
		input_reader.release_pointer()
	died.emit()
