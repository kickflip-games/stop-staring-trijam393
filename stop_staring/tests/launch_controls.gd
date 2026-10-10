extends SceneTree
## Run with Godot --headless --path stop_staring --script res://tests/launch_controls.gd

var failures: Array[String] = []
var player: CharacterBody3D
var camera: Camera3D


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	# Allow native window focus/mouse notifications to settle before injection.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
	player = scene.get_node("Player")
	camera = scene.get_node("Camera")
	player.movement_damping = 0.0
	var origin := camera.unproject_position(Vector3.ZERO)
	var long_drag := camera.unproject_position(Vector3(-10, 0, 0))
	mouse_button(origin, true)
	check(player.aiming, "mouse press starts aiming")
	var motion := InputEventMouseMotion.new()
	motion.position = long_drag
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	check(is_equal_approx(player.drag_vector.length(), player.max_drag_distance), "drag clamps")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/stop-staring-aim.png")
		# Native pointer motion can arrive while rendering the snapshot.
		mouse_button(origin, true)
	mouse_button(long_drag, false)
	check(not player.aiming, "release ends aiming")
	check(player.velocity.is_equal_approx(Vector3(player.max_launch_speed, 0, 0)), "long drag launches opposite drag at maximum speed")
	mouse_button(origin, true)
	mouse_button(origin, false)
	check(player.velocity.is_equal_approx(Vector3(player.max_launch_speed, 0, 0)), "click preserves momentum")
	var minimum_drag := camera.unproject_position(Vector3(0, -(player.drag_deadzone + 0.001), 0))
	mouse_button(origin, true)
	mouse_button(minimum_drag, false)
	check(absf(player.velocity.length() - player.min_launch_speed) < 0.02, "small valid drag uses minimum strength")
	check(player.velocity.y > 0 and absf(player.velocity.x) < 0.001, "relaunch replaces momentum")
	var medium_drag := camera.unproject_position(Vector3(-1.5, 0, 0))
	mouse_button(origin, true)
	mouse_button(medium_drag, false)
	check(player.velocity.length() > player.min_launch_speed and player.velocity.length() < player.max_launch_speed, "drag distance maps to strength")
	var before := player.velocity
	touch(origin, true, false)
	check(player.aiming, "touch starts aiming")
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = camera.unproject_position(Vector3(0, 3, 0))
	Input.parse_input_event(touch_drag)
	Input.flush_buffered_events()
	touch(touch_drag.position, false, true)
	check(player.velocity.is_equal_approx(before), "canceled touch preserves momentum")
	touch(origin, true, false)
	touch(touch_drag.position, false, false)
	check(player.velocity.is_equal_approx(Vector3(0, -player.max_launch_speed, 0)), "touch releases in correct direction")
	mouse_button(origin, true)
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.aiming, "focus loss cancels aim")
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]:
		player.position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		await physics_frame
		mouse_button(origin, true)
		mouse_button(camera.unproject_position(-direction * 3.0), false)
		for frame in range(100):
			await physics_frame
			check(absf(player.position.z) < 0.001, "repeated launches stay in XY")
			check(absf(player.position.x) < 9 and absf(player.position.y) < 5, "launch stays in arena")
	if failures.is_empty():
		print("PASS: mouse/touch launch, strength mapping, clamp, deadzone, cancellation, repeated launches and planar containment")
	else:
		for failure in failures:
			push_error(failure)
	for audio in scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func touch(position: Vector2, pressed: bool, canceled: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func check(passed: bool, message: String) -> void:
	if not passed and not failures.has(message):
		failures.append(message)
