extends SceneTree
## Matched native captures and state/occlusion checks for the eye gaze cones.
const BASE := "res://experiments/pixel_pivot/"
const CAPTURES := "res://../docs/gaze_cones/"
const ContactFixture := preload(BASE + "tests/eye_contact_fixture.gd")
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var clock: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
	await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES + filename + ".png")) == OK, "Saved " + filename)

func bodies_at(point: Vector2) -> Array[Dictionary]:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return player.get_world_2d().direct_space_state.intersect_point(query)

func point_eye(eye: Node2D, point: Vector2) -> void:
	# Settle the pupil through its actual tracking code in a stationary fixture.
	player.position = point
	var old_delta: float = clock.real_delta
	clock.real_delta = 0.05
	for step in range(30):
		eye._process(0.0)
	clock.real_delta = old_delta
	eye.get_node("GazeCone").update_gaze(0.0, true)

func check_blocked(eye: Node2D, label: String) -> void:
	var cone: Node2D = eye.get_node("GazeCone")
	var middle: int = cone.ray_lengths.size() / 2
	var length: float = cone.ray_lengths[middle]
	var ray: Vector2 = cone.ray_directions[middle]
	var end: Vector2 = cone.apex + ray * length
	check(cone.visible and length > 20.0 and length < eye.gaze_length - 10.0, label + " truncates the beam before its maximum range")
	check(bodies_at(end).is_empty(), label + " leaves the beam endpoint outside the solid")
	check(not bodies_at(end + ray * 1.0).is_empty(), label + " stops immediately in front of the real collider")

func test_cones() -> void:
	for eye in arena.eyes:
		var cone: Node2D = eye.get_node_or_null("GazeCone")
		check(cone != null, "Every wall eye has a gaze cone")
		check(cone.z_index < eye.z_index and cone.z_index < player.z_index and not cone.z_as_relative, "Gaze stays beneath eyes and slime")
	var eye: Node2D = arena.eyes[1]
	var cone: Node2D = eye.get_node("GazeCone")
	point_eye(eye, arena.spawn_position)
	check(cone.visible and cone.direction.dot(Vector2.DOWN) > 0.99, "Top eye projects toward the tracked slime")
	check(is_equal_approx(cone.ray_lengths[cone.ray_lengths.size() / 2], eye.gaze_length), "Clear center ray reaches its bounded range")
	point_eye(eye, arena.get_node("WallPhysics/UpperRight").global_position)
	check_blocked(eye, "Quadrant island")
	var score_before: float = arena.elapsed
	var timer_before: float = eye.closed_remaining
	var velocity_before := player.velocity
	cone.update_gaze(0.0, true)
	check(arena.elapsed == score_before and eye.closed_remaining == timer_before and player.velocity == velocity_before, "Cone geometry never changes scoring, eye timers or movement")
	# The current decorative barrels are embedded in solid islands. Put a
	# barrel-sized collider in the clear center lane to isolate prop occlusion.
	var prop := StaticBody2D.new()
	prop.position = arena.spawn_position
	prop.collision_layer = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	prop.add_child(shape)
	arena.add_child(prop)
	await physics_frame
	point_eye(eye, prop.global_position)
	check_blocked(eye, "Barrel-sized prop")
	prop.queue_free()
	await physics_frame
	point_eye(eye, Vector2(224, 20))
	check(eye.active and not cone.visible, "An open eye cannot project through the back of its supporting wall")
	point_eye(eye, Vector2(224, 92))
	check(cone.visible, "Exposed gaze returns when the slime crosses back in front")
	var angle_before: Vector2 = cone.direction
	arena.toggle_pause()
	await wait_real(0.06)
	check(cone.direction == angle_before and clock.real_delta == 0.0, "Pause freezes the gaze with the scene's real clock")
	arena.resume()
	check(ContactFixture.sweep(player, eye), "A real wall sweep closes the eye")
	check(not cone.visible and not eye.active, "Cone switches off synchronously on the hit frame")
	eye.closed_remaining = 0.001
	arena._last_tick -= 10000
	arena.advance_time()
	check(eye.active and cone.visible and eye._snap_age >= 0.0, "Independent reopen switches the cone back on with the eye snap")
	check(cone.direction.is_equal_approx(eye._pupil_offset.normalized()), "Reopened cone locks onto the same direction as the pupil")
	eye.gaze_enabled = false
	cone.update_gaze(0.0, true)
	check(not cone.visible and eye.active, "Per-eye visibility tuning changes only the cone")
	eye.gaze_enabled = true
	arena.retry()
	for target in arena.eyes:
		check(ContactFixture.sweep(player, target), "Real sweep closes " + str(target.name))
	check(arena.cleared, "Closing every eye still wins with gaze cones enabled")
	for target in arena.eyes:
		check(not target.get_node("GazeCone").visible, "No gaze survives the final clear")
	arena.retry()
	await wait_real(0.12)
	var visible_cones := 0
	for target in arena.eyes:
		if target.get_node("GazeCone").visible:
			visible_cones += 1
	check(visible_cones > 0 and arena.closed_eyes == 0 and Engine.time_scale == 1.0, "Retry restores live open-eye gaze without stale clear/time state")

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	presentation = load(BASE + "pixel_pivot.tscn").instantiate()
	root.add_child(presentation)
	current_scene = presentation
	await process_frame
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	clock = arena.get_node("Clock")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await wait_real(0.15)
	arena.set_focused(true)
	player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	var prefix := "before_" if "--baseline" in OS.get_cmdline_user_args() else "after_"
	if prefix == "after_":
		await test_cones()
	else:
		# Matched layout and lighting, with only the new gaze effect disabled.
		for eye in arena.eyes:
			eye.gaze_enabled = false
			eye.get_node("GazeCone").update_gaze(0.0, true)
	await wait_real(0.15)
	await capture(prefix + "room")
	player.position = Vector2(224, 92)
	await wait_real(0.3)
	await capture(prefix + "tracking")
	# Native fixture screenshots can outlive an OS focus change. Resume this
	# scripted contact explicitly; production focus suspension remains intact.
	arena.set_focused(true)
	check(ContactFixture.sweep(player, arena.eyes[1]), "Swept contact closes the top eye")
	check(ContactFixture.sweep(player, arena.eyes[10]), "Swept contact closes an interior eye")
	player.position = arena.spawn_position
	player.velocity = Vector2.ZERO
	await wait_real(0.24)
	await capture(prefix + "closed")
	arena.retry()
	# Let stopped audio playback release before tearing down the fixture.
	await wait_real(0.05)
	presentation.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Scene exit restores normal time")
	print("Gaze cones: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
