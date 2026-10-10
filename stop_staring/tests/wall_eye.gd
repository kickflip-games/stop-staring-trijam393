extends SceneTree
## Run with --headless for checks; omit it to save matched runtime captures.
var failures: Array[String] = []
var pop_events := 0
var completed_events := 0


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = scene.get_node("Player")
	var eye: Node3D = scene.get_node("Eye")
	var wall: Node3D = scene.get_node("Arena/TopWall")
	player.set_physics_process(false)
	player.get_node("WallHitAudio").stream = null
	eye.set_process(false)
	eye.popped.connect(func(_eye: Node3D): pop_events += 1)
	scene.all_eyes_popped.connect(func(): completed_events += 1)
	check(scene.remaining_eyes == 1, "level counts its eye")
	for position_value in [Vector3(-8, -4, 0), Vector3(8, -4, 0), Vector3(0, -4, 0)]:
		player.position = position_value
		for step in range(180):
			eye._process(1.0 / 60.0)
		var pupil: Vector3 = eye.get_node("Eyeball/Pupil").position
		check(Vector2(pupil.x, pupil.y).length() <= eye.tracking_limit + 0.00001, "pupil remains inside sclera")
		check(pupil.y < 0 and (absf(position_value.x) < 0.01 or pupil.x * position_value.x > 0), "pupil tracks player")
	player.position = Vector3.ZERO
	player.aiming = true
	player.drag_vector = Vector3(0, 3, 0)
	for step in range(90):
		eye._process(1.0 / 60.0)
	await capture("/tmp/stop-staring-eye-tracking.png")
	player._cancel_aim()
	check(not eye.try_hit(wall, Vector3(0, 5, 0), Vector3.DOWN, 2.9), "slow contact rejected")
	check(not eye.try_hit(scene.get_node("Arena/BottomWall"), Vector3(0, 5, 0), Vector3.DOWN, 10), "other wall rejected")
	check(not eye.try_hit(wall, Vector3(0, 5, 0), Vector3.UP, 10), "wrong wall face rejected")
	# Actual swept collisions check target width and normal impact speed.
	player.movement_damping = 0
	player.position = Vector3(2, 4, 0)
	player.velocity = Vector3(0, 12, 0)
	player._physics_process(0.1)
	check(eye.active and player.velocity.y < 0, "wall hit away from eye ricochets without popping")
	player.position = Vector3(-1, 4.54, 0)
	player.velocity = Vector3(30, 2, 0)
	player._physics_process(0.03)
	check(eye.active, "fast grazing contact needs sufficient normal speed")
	# Launch right, ricochet, then strike the top eye in the same large step.
	player.position = Vector3(7.5, 0, 0)
	player.velocity = Vector3(40, 18.94737, 0)
	player.bounce_retention = 1.0
	player._physics_process(0.25)
	check(not eye.active and player.velocity.x < 0 and player.velocity.y < 0, "launch to side ricochet to eye pop works with swept contacts")
	check(pop_events == 1 and scene.remaining_eyes == 0 and completed_events == 1, "pop updates level and completion once")
	check(not eye.try_hit(wall, Vector3(0, 5, 0), Vector3.DOWN, 10) and pop_events == 1, "popped eye cannot score twice")
	await create_timer(0.4).timeout
	check(not eye.get_node("Eyeball").visible and eye.get_node("Socket").visible, "pop leaves an empty socket")
	await capture("/tmp/stop-staring-eye-popped.png")
	# Reuse the scene on a rotated side wall and prove tracking/contact transforms.
	var rotated := load("res://scenes/eye.tscn").instantiate() as Node3D
	rotated.player_path = NodePath("../Player")
	rotated.wall_path = NodePath("../Arena/RightWall")
	rotated.position = Vector3(9, 0, 1.06)
	rotated.rotation.z = -PI / 2
	scene.add_child(rotated)
	rotated.set_process(false)
	player.position = Vector3.ZERO
	for step in range(120):
		rotated._process(1.0 / 60.0)
	check(rotated.get_node("Eyeball/Pupil").position.y < 0, "rotated eye tracks into arena")
	check(rotated.try_hit(scene.get_node("Arena/RightWall"), Vector3(9, 0, 0), Vector3.LEFT, 3), "rotated eye accepts threshold hit")
	if failures.is_empty():
		print("PASS: tracking clamp, wall/face/speed filters, grazing hit, swept ricochet-to-pop, one-shot count, socket and rotated reuse")
	else:
		for failure in failures:
			push_error(failure)
	# Stop active audio before teardown so decoder playback is released cleanly.
	for audio in scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
