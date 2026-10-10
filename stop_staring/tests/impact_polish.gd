extends SceneTree
## Real-time runtime checks; omit --headless to capture matched polish frames.
var failures: Array[String] = []
var scene: Node3D
var player: CharacterBody3D
var camera: Camera3D
var time_effects: Node
var feedback: Node3D
var visual: Node3D

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("Player")
	camera = scene.get_node("Camera")
	time_effects = scene.get_node("TimeEffects")
	feedback = scene.get_node("ImpactFeedback")
	visual = player.get_node("VisualPivot")
	await real_wait(0.5)
	player.movement_damping = 0.0
	player.velocity = Vector3(10, 0, 0)
	player.position = Vector3(-4, 0, 0)
	var start := player.position.x
	await real_wait(0.12)
	var normal_distance := player.position.x - start
	var origin := camera.unproject_position(player.position)
	mouse_press(origin, true)
	mouse_drag(origin - Vector2(180, 0))
	check(player.aiming and Engine.time_scale == 0.25, "mouse aim immediately enters 0.25x")
	start = player.position.x
	await real_wait(0.12)
	var slow_distance := player.position.x - start
	check(slow_distance > 0.0 and slow_distance < normal_distance * 0.45, "moving gameplay slows while held aim")
	check(visual.scale.x > 1.05 and visual.position.x < -0.02, "anticipation remains responsive in slow motion")
	await capture("/tmp/stop-staring-polish-aim.png")
	mouse_press(origin - Vector2(180, 0), false)
	check(Engine.time_scale == 1.0 and not player.aiming and player.velocity.x > 10, "release restores exact 1.0 and immediate launch")
	player._begin_aim(origin)
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Engine.time_scale == 1.0 and not player.aiming, "focus loss restores normal time")
	player._begin_aim(origin)
	paused = true
	await real_wait(0.03)
	check(Engine.time_scale == 1.0 and not player.aiming, "pause clears aim and restores normal time")
	paused = false

	# A real swept wall contact, then aim, launch, and a real swept eye contact.
	player.position = Vector3(8.4, 0, 0)
	player.velocity = Vector3(18, 0, 0)
	await real_wait(0.025)
	check(player.velocity.x < 0 and Engine.time_scale == 1.0, "wall bounce retains mechanics without hit-stop")
	var wall_squash := visual.scale.x
	check(feedback._bursts.is_empty(), "ordinary walls do not emit full eye bursts")
	player._begin_aim(camera.unproject_position(player.position))
	check(Engine.time_scale == player.aim_time_scale, "aim after wall bounce slows gameplay")
	player._release(camera.unproject_position(player.position - Vector3(0, 3, 0)))
	check(Engine.time_scale == 1.0 and player.velocity.y > 17.9, "second launch is immediate")
	player.position = Vector3(0, 4.25, 0)
	player.velocity = Vector3(0, 18, 0)
	var eye: Node3D = scene.get_node("Eye")
	var timeout := Time.get_ticks_msec() + 500
	while eye.active and Time.get_ticks_msec() < timeout:
		await process_frame
	check(not eye.active and Engine.time_scale == 0.0, "successful swept eye hit enters hit-stop")
	var stopped_at := Time.get_ticks_usec()
	check(visual.scale.x < wall_squash and visual.scale.x < 0.45, "eye squash is stronger than wall squash")
	check(feedback._bursts.size() == 1 and feedback._bursts[0].node.multimesh.instance_count == 14, "eye emits fourteen 3D fragments")
	check(eye.get_node("Eyeball").scale.x > 1.2, "eye bulges immediately")
	check(feedback._kick.length() > feedback.wall_camera_kick, "eye camera kick exceeds wall response")
	check(eye.get_node("PopAudio").pitch_scale >= 0.9 and eye.get_node("PopAudio").pitch_scale <= 1.1, "pop pitch stays within 0.9 to 1.1")
	# Entering aim during hit-stop must not overwrite its priority.
	origin = camera.unproject_position(player.position)
	player._begin_aim(origin)
	player._update_aim(origin - Vector2(100, 0), false)
	check(Engine.time_scale == 0.0, "hit-stop wins over a new aim gesture")
	check(camera.h_offset == 0.0 and camera.v_offset == 0.0, "aim clears camera offsets before projecting input")
	await capture("/tmp/stop-staring-polish-impact.png")
	while Engine.time_scale == 0.0:
		await process_frame
	var elapsed := float(Time.get_ticks_usec() - stopped_at) / 1000000.0
	check(elapsed >= 0.035 and elapsed < 0.14, "hit-stop ends after about 0.05 seconds real time")
	check(Engine.time_scale == 0.25, "hit-stop returns to the current aim state")
	player._release(origin - Vector2(100, 0))
	check(Engine.time_scale == 1.0 and player.velocity.x > 0, "launch after eye hit returns to full speed")
	player.velocity = Vector3.ZERO
	await real_wait(0.3)
	check(not eye.get_node("Eyeball").visible and eye.get_node("Socket").visible, "pop retracts once and leaves socket")
	check(feedback._bursts.is_empty() and camera.h_offset == 0.0 and camera.v_offset == 0.0, "particles clean up and camera returns exactly")
	check(visual.scale.distance_to(Vector3.ONE) < 0.02, "blob recovers without stuck scale")
	check(player.scale == Vector3.ONE and player.get_node("Collision").scale == Vector3.ONE, "collision geometry is untouched")
	await capture("/tmp/stop-staring-polish-after.png")

	# Closely spaced hits extend one deadline, without stale timers restoring time.
	for index in range(12):
		player._begin_aim(camera.unproject_position(player.position))
		time_effects.hit_stop()
		await real_wait(0.01)
		time_effects.hit_stop()
		player._cancel_aim()
		await real_wait(0.025)
		check(Engine.time_scale == 0.0, "overlapping hit-stop never ends from an older deadline")
		await real_wait(0.04)
		check(Engine.time_scale == 1.0, "rapid hit-stop returns to normal")
		visual.eye_impact(Vector3.DOWN, 18)
		feedback.eye_hit(Vector3(0, 5, 0), Vector3.DOWN, 18)
		check(visual.scale.is_finite() and visual.scale.x >= 0.3, "rapid impact squash remains clamped")
	player._begin_aim(camera.unproject_position(player.position))
	time_effects.hit_stop()
	scene.queue_free()
	await process_frame
	await process_frame
	check(Engine.time_scale == 1.0, "freeing scene during aim and hit-stop restores exact normal time")
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._build_level(1)
	await process_frame
	var live_player: Node = game.gameplay.get_node("Player")
	live_player._begin_aim(game.gameplay.get_node("Camera").unproject_position(live_player.position))
	game.gameplay.get_node("TimeEffects").hit_stop()
	game.start_level(1)
	check(Engine.time_scale == 1.0, "restart clears time effects before cover starts")
	while root.get_node("EasyTransition").is_transitioning:
		await process_frame
	check(Engine.time_scale == 1.0 and current_scene.mode == "playing", "actual scene reload resumes at normal time")
	current_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real moving aim/release, focus, pause, wall/eye hierarchy, hit-stop %.3fs, particles, camera, pitch, repeat hits and restart" % elapsed)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func real_wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)

func mouse_press(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse_drag(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check(value: bool, message: String) -> void:
	if not value and not failures.has(message):
		failures.append(message)
