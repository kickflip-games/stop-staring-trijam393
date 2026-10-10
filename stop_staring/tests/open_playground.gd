extends SceneTree
## Headless checks exercise real swept movement, input projection, clear and retry.

var failures: Array[String] = []
var checks := 0
var game: Node
var level: Node3D
var player: CharacterBody3D
var camera: Camera3D
var indicators: Control
var travel_samples: Array[Dictionary] = []
var _sample_travel := false
var _prior_camera := Vector3.ZERO
var _maximum_camera_step := 0.0
var _maximum_camera_speed := 0.0
var _prior_frame_usec := 0


func _initialize() -> void:
	process_frame.connect(sample_camera)
	call_deferred("run_checks")


func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/playground_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	bind_level()
	await capture("center")
	check(level.remaining_eyes == 15, "experiment starts with fifteen eyes")
	check(level.playable_bounds.size == Vector2(45, 25), "playable dimensions")
	check(player.max_launch_speed == 18.0 and player.bounce_retention == 0.9 and player.movement_damping == 0.35, "movement tuning preserved")
	player.set_physics_process(false)
	camera.set_process(false)
	indicators.set_process(false)
	var before := camera.position
	player.position += Vector3(0.3, 0.2, 0)
	for frame in range(60):
		camera.advance(1.0 / 60.0)
	check(camera.position.is_equal_approx(before), "small motion stays inside dead zone")
	player.velocity = Vector3(18, 0, 0)
	for frame in range(120):
		camera.advance(1.0 / 60.0)
	check(camera.size > camera.normal_zoom + 1.0, "high speed zooms out subtly")
	check(camera.position.x > player.position.x, "velocity framing looks ahead")
	var press := Vector2(740, 410)
	player._begin_aim(press)
	for frame in range(120):
		camera.advance(1.0 / 60.0)
		player._update_aim(press, false)
	check(player.drag_vector.length() < 0.001, "stationary cursor creates no drag during pan and aim zoom")
	check(absf(camera.size - camera.aim_zoom) < 0.01, "aim zoom settles")
	var delta_pixels: float = 3.0 / player._screen_x.x
	var release := press - Vector2(delta_pixels, 0)
	player._release(release)
	check(player.velocity.distance_to(Vector3(18, 0, 0)) < 0.02, "moving-camera drag launches with original direction and speed")
	check(is_equal_approx(Engine.time_scale, 1.0), "release restores time")
	# Check every framing corner, including aspect changes and additive impact offsets.
	for viewport in [Vector2i(1280, 800), Vector2i(1920, 800), Vector2i(800, 1000)]:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		for corner in [Vector3(-22, -12, 0), Vector3(-22, 12, 0), Vector3(22, -12, 0), Vector3(22, 12, 0)]:
			player.position = corner
			camera.h_offset = 0.075
			camera.v_offset = -0.075
			for frame in range(60):
				camera.advance(1.0 / 60.0)
				check_camera_bounds()
				check(camera.rotation.is_zero_approx(), "camera never rotates")
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	await process_frame
	camera.h_offset = 0
	camera.v_offset = 0
	# Verify visibility membership, HUD exclusion and spacing throughout the arena.
	for point in [Vector3(-18, 3.2, 0), Vector3(18, 3.2, 0), Vector3(0, 0, 0), Vector3(-18, -10, 0), Vector3(18, 10, 0)]:
		player.position = point
		player.velocity = Vector3.ZERO
		for frame in range(90):
			camera.advance(1.0 / 60.0)
		indicators.update_markers()
		var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
		for eye in level._eyes:
			var marked: bool = indicators.markers.any(func(marker): return marker.eye == eye)
			check(marked == not viewport.has_point(camera.unproject_position(eye.position)), "only off-screen eyes have indicators")
		for marker in indicators.markers:
			check(viewport.grow(-indicators.icon_radius - 9.0).has_point(marker.position), "indicator has edge padding")
			check(not indicators.counter_reserved_rect.grow(indicators.icon_radius + 4.0).has_point(marker.position), "indicators avoid eye counter")
			check(marker.position.y >= indicators.hud_top_clearance, "indicators avoid header buttons")
		for a in range(indicators.markers.size()):
			for b in range(a + 1, indicators.markers.size()):
				check(indicators.markers[a].position.distance_to(indicators.markers[b].position) >= indicators.minimum_spacing - 0.1, "indicators do not overlap")
	# Real end-to-end travel in the broad upper and lower launch lanes, with aiming.
	player.set_physics_process(true)
	camera.set_process(true)
	indicators.set_process(true)
	for lane in [3.2, -3.8]:
		for direction in [1.0, -1.0]:
			player.position = Vector3(-direction * 20.0, lane, 0)
			player.velocity = Vector3.ZERO
			await create_timer(0.7, true, false, true).timeout
			await physics_frame
			if lane == 3.2 and direction == 1.0:
				await capture("west")
			launch(Vector3(direction, 0, 0))
			var start_x := player.position.x
			_maximum_camera_step = 0.0
			_maximum_camera_speed = 0.0
			_prior_camera = camera.position
			_prior_frame_usec = Time.get_ticks_usec()
			_sample_travel = true
			for frame in range(290):
				await physics_frame
				check_camera_bounds()
				if frame == 48:
					var origin := Vector2(700, 400)
					player._begin_aim(origin)
					for aim_frame in range(20):
						await physics_frame
						player._update_aim(origin, false)
					check(player.drag_vector.length() < 0.001, "mid-flight stationary mouse stays neutral")
					if lane == 3.2 and direction == 1.0:
						await capture("aim")
					player._release(origin - Vector2(direction * 3.0 / player._screen_x.x, 0))
				if direction * player.position.x > 20:
					break
			check(direction * player.position.x > 20, "real launch crosses entire open lane")
			check(absf(player.position.x - start_x) > 39, "travel exceeds a screen width")
			_sample_travel = false
			if lane == 3.2 and direction == 1.0:
				await capture("east")
			# Screenshot readback can stall rendering. Measure motion per real second,
			# rather than interpreting a long frame as a camera discontinuity.
			check(_maximum_camera_speed < player.max_launch_speed * 2.0, "camera has no travel snap after settling")
			travel_samples.append({"lane": lane, "direction": direction, "distance": absf(player.position.x-start_x), "max_camera_step": _maximum_camera_step, "max_camera_speed": _maximum_camera_speed})
	# Each target is hit via the player sweep and normal wall-contact signal.
	# Place only the setup position, then use the unchanged launch input to hit it.
	for eye in level._eyes:
		if not eye.active:
			continue
		var normal: Vector3 = eye.global_basis * Vector3.DOWN
		var start: Vector3 = eye.position + normal * 2.4
		start.z = 0
		player.position = start
		player.velocity = Vector3.ZERO
		await physics_frame
		launch(-normal)
		for frame in range(35):
			await physics_frame
			if not eye.active:
				break
		check(not eye.active, "real swept launch can reach and pop " + eye.name)
		indicators.update_markers()
		check(not indicators.markers.any(func(marker): return marker.eye == eye), "popped eye loses its indicator")
	check(level.remaining_eyes == 0 and game.mode == "clear", "final hit finishes experiment normally")
	check(not player.is_physics_processing() and not player.is_processing_unhandled_input(), "clear stops player input and motion")
	await create_timer(0.3, true, false, true).timeout
	await capture("clear")
	var retry := find_button("TRY AGAIN")
	check(retry != null, "clear offers retry")
	if retry:
		retry.pressed.emit()
		await settle_transition()
		bind_level()
		check(game.active_level == 3 and game.mode == "playing" and level.remaining_eyes == 15, "retry starts a fresh experiment with all eyes")
		check(not player.aiming and is_equal_approx(Engine.time_scale, 1.0), "retry clears gesture and slow motion")
		check(game.elapsed < 0.1, "retry resets timer")
		game.show_menu()
		await settle_transition()
		check(game.mode == "menu" and game.gameplay == null, "menu teardown remains clean")
		check(find_button("OPEN PLAYGROUND  ·  EXPERIMENT") != null, "main menu exposes separate experiment")
	print("TRAVEL: ", JSON.stringify(travel_samples))
	if failures.is_empty():
		print("PASS: %d checks; camera, indicators, real traversals, fifteen swept eye hits, clear, retry and menu" % checks)
	else:
		for failure in failures:
			push_error(failure)
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1, true, false, true).timeout
	quit(0 if failures.is_empty() else 1)


func bind_level() -> void:
	level = game.gameplay
	player = level.get_node("Player")
	camera = level.get_node("Camera")
	indicators = level.get_node("HUD/EyeIndicators")


func launch(direction: Vector3) -> void:
	var origin := Vector2(640, 400)
	player._begin_aim(origin)
	var drag_pixels := Vector2(direction.x * 3.0 / player._screen_x.x, direction.y * 3.0 / player._screen_y.y)
	player._release(origin - drag_pixels)


func check_camera_bounds() -> void:
	var viewport := root.get_visible_rect().size
	for corner in [Vector2.ZERO, viewport, Vector2(viewport.x, 0), Vector2(0, viewport.y)]:
		var point: Vector3 = Plane(Vector3.BACK, 0).intersects_ray(camera.project_ray_origin(corner), camera.project_ray_normal(corner))
		check(level.camera_bounds.grow(0.002).has_point(Vector2(point.x, point.y)), "camera viewport remains inside bounds at every zoom and aspect")


func sample_camera() -> void:
	if _sample_travel and is_instance_valid(camera):
		var now := Time.get_ticks_usec()
		var elapsed := float(now - _prior_frame_usec) / 1000000.0
		var distance := camera.position.distance_to(_prior_camera)
		_maximum_camera_step = maxf(_maximum_camera_step, distance)
		if elapsed > 0.0001:
			_maximum_camera_speed = maxf(_maximum_camera_speed, distance / elapsed)
		_prior_camera = camera.position
		_prior_frame_usec = now


func capture(area: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/stop-staring-playground-%s.png" % area)


func find_button(text: String) -> Button:
	for node in game._ui.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null


func settle_transition() -> void:
	while root.get_node("EasyTransition").is_transitioning:
		await process_frame
	game = current_scene


func check(passed: bool, message: String) -> void:
	checks += 1
	if not passed and not failures.has(message):
		failures.append(message)
