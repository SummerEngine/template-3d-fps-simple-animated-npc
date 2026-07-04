extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	_expect(packed_scene != null, "main scene loads")
	if not packed_scene:
		_finish()
		return

	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("Player") as PlayerController
	_expect(player != null, "main scene has PlayerController")
	if not player:
		_finish()
		return

	var reader := player.get_node_or_null("InputReader") as FpsInputReader
	_expect(reader != null, "Player has FpsInputReader child")
	_expect(player.input_reader == reader, "PlayerController reads from FpsInputReader")

	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	_expect(weapon_system != null, "Player has WeaponSystem")
	if weapon_system:
		_expect(weapon_system.input_reader == reader, "WeaponSystem reads from FpsInputReader")

	var weapon_loadout := player.get_node_or_null("WeaponLoadout") as WeaponLoadout
	_expect(weapon_loadout != null, "Player has WeaponLoadout")
	if weapon_loadout:
		_expect(weapon_loadout.input_reader == reader, "WeaponLoadout reads from FpsInputReader")

	if reader:
		_test_remappable_movement(reader)
		_test_remappable_look(reader)

	scene.queue_free()
	_finish()


func _test_remappable_movement(reader: FpsInputReader) -> void:
	var remap_forward := &"test_forward_remap"
	_ensure_action(remap_forward)
	reader.move_forward_action = remap_forward
	Input.action_press(remap_forward, 1.0)
	var movement := reader.get_movement_vector()
	Input.action_release(remap_forward)
	_expect(movement.y < -0.9, "movement uses reader action names, not fixed keys")


func _test_remappable_look(reader: FpsInputReader) -> void:
	var remap_look_right := &"test_look_right_remap"
	_ensure_action(remap_look_right)
	reader.look_right_action = remap_look_right
	Input.action_press(remap_look_right, 1.0)
	var look_delta := reader.consume_look_delta(0.1)
	Input.action_release(remap_look_right)
	_expect(look_delta.x > 0.0, "look uses reader action names, not only mouse motion")


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[input-reader-smoke] PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("[input-reader-smoke] FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("[input-reader-smoke] PASS: all checks")
		quit(0)
	else:
		print("[input-reader-smoke] FAILURES: %s" % ", ".join(_failures))
		quit(1)
