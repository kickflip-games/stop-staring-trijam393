extends SceneTree
## Godot --headless --path stop_staring --script res://tests/ricochets.gd

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = scene.get_node("Player")
	# Direct-step stress tests do not advance the mixer between impacts.
	player.get_node("WallHitAudio").stream = null
	player.set_physics_process(false)
	player.movement_damping = 0.0
	for sign_value in [-1.0, 1.0]:
		player.position = Vector3(sign_value * 8.0, 0, 0)
		player.velocity = Vector3(sign_value * 12, 12, 0)
		player._physics_process(0.1)
		check(player.velocity.is_equal_approx(Vector3(-sign_value * 10.8, 10.8, 0)), "45 degree side-wall reflection and retention")
		player.position = Vector3(0, sign_value * 4.0, 0)
		player.velocity = Vector3(12, sign_value * 12, 0)
		player._physics_process(0.1)
		check(player.velocity.is_equal_approx(Vector3(10.8, -sign_value * 10.8, 0)), "45 degree horizontal-wall reflection and retention")
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			player.position = Vector3(x_sign * 8.4, y_sign * 4.4, 0)
			player.velocity = Vector3(x_sign * 18, y_sign * 18, 0)
			player._physics_process(0.1)
			check(player.velocity.x * x_sign < 0 and player.velocity.y * y_sign < 0, "corner reflects both axes")
			check(player.velocity.length() > 15, "corner does not stick")
	player.position = Vector3(8.0, 0, 0)
	player.velocity = Vector3(40, 0.01, 0)
	player._physics_process(0.1)
	check(player.velocity.x < -35 and player.velocity.y > 0, "glancing high-speed hit reflects without sliding")
	player.position = Vector3(8.549, 0, 0)
	player.velocity = Vector3(-10, 0, 0)
	player._physics_process(0.1)
	check(player.position.x < 8 and player.velocity.x < 0, "launch away from contact is not reflected back")
	player.position = Vector3.ZERO
	player.velocity = Vector3(0.2, 0, 0)
	player._physics_process(0.1)
	check(player.velocity.is_zero_approx() and player.position.is_zero_approx(), "slow movement settles without jitter")
	player.velocity = Vector3(10, 0, 0)
	player.movement_damping = 0.35
	player._physics_process(0.1)
	check(absf(player.velocity.x - 10 * exp(-0.035)) < 0.001, "damping uses elapsed time")
	player.movement_damping = 0.0
	player.bounce_retention = 1.0
	var reference := Vector3.ZERO
	for hz in [30, 60, 120]:
		player.position = Vector3.ZERO
		player.velocity = Vector3(40, 23, 9)
		for frame in range(hz * 2):
			player._physics_process(1.0 / hz)
			check(absf(player.position.x) <= 8.551 and absf(player.position.y) <= 4.551, "fast repeated ricochets remain contained")
			check(is_zero_approx(player.position.z) and is_zero_approx(player.velocity.z), "ricochets preserve plane")
		if hz == 30:
			reference = player.position
		else:
			check(player.position.distance_to(reference) < 0.05, "trajectory agrees across physics rates")
	player.position = Vector3.ZERO
	player.drag_vector = Vector3(3, 0, 0)
	var endpoint: Vector3 = player.get_preview_endpoint(0.8)
	check(absf(endpoint.x - 8.55) < 0.04 and absf(endpoint.y) < 0.001, "sphere preview stops at first wall contact")
	player.drag_vector = Vector3(0.13, 0, 0)
	check(player.get_preview_endpoint(0.8).x < endpoint.x, "preview length scales with power")
	player.drag_vector = Vector3(3, 3, 0).limit_length(3)
	endpoint = player.get_preview_endpoint(0.8)
	check(endpoint.distance_to(Vector3(4.55, 4.55, 0)) < 0.02, "diagonal preview includes sphere radius")
	player.drag_vector = Vector3(0.6, 0, 0)
	player.movement_damping = 0.35
	endpoint = player.get_preview_endpoint(0.5)
	check(player.position.is_zero_approx(), "preview does not move player")
	player.velocity = player.get_launch_velocity()
	for frame in range(30):
		player._physics_process(1.0 / 60)
	check(player.position.distance_to(endpoint) < 0.001, "preview agrees with actual damped free-flight motion")
	player.position = Vector3(8.549, 0, 0)
	player.drag_vector = Vector3(-3, 0, 0)
	check(player.get_preview_endpoint(0.1).x < 7, "preview from wall contact can point away")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		player.position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		player.aiming = true
		player.drag_vector = Vector3(3, 1.6, 0).limit_length(3.0)
		player.set_process_unhandled_input(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/stop-staring-ricochet-preview.png")
	if failures.is_empty():
		print("PASS: 45 degree reflections, retention, corners, glancing shots, settling, damping, 30/60/120 Hz containment and first-contact preview")
	else:
		for failure in failures:
			push_error(failure)
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func check(passed: bool, message: String) -> void:
	if not passed and not failures.has(message):
		failures.append(message)
