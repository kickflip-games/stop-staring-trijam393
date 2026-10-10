extends SceneTree
## Real 2D sweeps, native GUI routing, timing composition and a complete target clear.
const ContactFixture = preload("res://experiments/pixel_pivot/tests/eye_contact_fixture.gd")
const BASE := "res://experiments/pixel_pivot/"
var failures: Array[String] = []
var checks := 0
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var camera: Camera2D
var clock: Node
var contacts := 0

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
	camera = arena.get_node("CameraRig/Camera2D")
	clock = arena.get_node("Clock")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await wait_real(0.15)
	arena.set_focused(true)
	player.set_physics_process(false)
	check(arena.remaining_eyes == 16 and arena.eyes.size() == 16, "Sixteen targets matching the chosen reference composition")
	check(arena.get_node("WallPhysics").get_child_count() == 10, "Four perimeter bodies, four quadrant islands and two attached wall lips")
	for layer in ["Floor", "WallArt", "WallTops", "WallEdges", "WallInsets"]:
		check(not arena.get_node(layer).collision_enabled, "No duplicate tile collision")
	check(player.scale == Vector2.ONE and player.get_node("CollisionShape2D").scale == Vector2.ONE, "Circle collider unscaled")
	check(player.get_node("CollisionShape2D").shape.radius == 5.0, "Fixed collider radius")
	check(is_equal_approx(presentation.display_scale, 800.0 / 336.0), "Display fills the window with uniform aspect scaling")
	check(camera.zoom == Vector2.ONE, "Fixed camera zoom")
	test_quadrant_geometry()
	test_controls()
	await test_native_input()
	await test_timing()
	test_camera()
	await test_ricochets()
	await test_targets_and_clear()
	await test_final_indicator()
	test_reachable_layout()
	if DisplayServer.get_name() != "headless":
		await capture_regions()
	arena.retry()
	presentation.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "Leaving gameplay restores time")
	# Exercise the configured project entry point after removing the old prototype.
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(main_scene == "res://ui/home_screen.tscn", "Default project entry point is the pixel home screen")
	var home: Node = load(main_scene).instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	var menu_deadline := Time.get_ticks_usec() + 5000000
	while not home._effects_ready and Time.get_ticks_usec() < menu_deadline:
		await process_frame
	check(home._effects_ready, "Home finishes the existing shader/audio warmup before Play")
	home.start_game()
	await process_frame
	await process_frame
	await physics_frame
	var game := current_scene
	var main_arena: Node2D = game.get_node("View/World/PixelArena")
	check(main_arena.get_node("Slime") is CharacterBody2D and main_arena.remaining_eyes == 16, "Default game starts with the 2D player and sixteen targets")
	check(game.get_node("View/World").disable_3d, "Gameplay viewport disables 3D rendering")
	game.queue_free()
	await process_frame
	print("Pixel pivot: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func test_quadrant_geometry() -> void:
	var center: Vector2 = arena.spawn_position
	var expected := {
		"UpperLeft": Rect2(96, 112, 64, 48),
		"UpperRight": Rect2(288, 112, 64, 48),
		"LowerLeft": Rect2(96, 208, 64, 48),
		"LowerRight": Rect2(288, 208, 64, 48),
	}
	check(arena.arena_bounds == Rect2(0, 0, 448, 336) and center == Vector2(224, 184), "Arena size and spawn unchanged")
	for name in expected:
		var body: StaticBody2D = arena.get_node("WallPhysics/" + name)
		var size: Vector2 = body.get_node("CollisionShape2D").shape.size
		check(Rect2(body.position - size * 0.5, size) == expected[name], "Solid 64 by 48 quadrant block: " + name)
	for name in ["LeftLip", "RightLip"]:
		var body: StaticBody2D = arena.get_node("WallPhysics/" + name)
		var size: Vector2 = body.get_node("CollisionShape2D").shape.size
		var origin := Vector2(32, 160) if name == "LeftLip" else Vector2(400, 160)
		check(Rect2(body.position - size * 0.5, size) == Rect2(origin, Vector2(16, 48)), "Matching 16px deep, 48px tall attached lip: " + name)
	check(arena.eyes[14].wall.name == "LeftLip" and arena.eyes[14].position == Vector2(48, 184), "Left midpoint eye sits on the lip's exposed face")
	check(arena.eyes[15].wall.name == "RightLip" and arena.eyes[15].position == Vector2(400, 184), "Right midpoint eye sits on the lip's exposed face")
	var upper_left: Rect2 = expected.UpperLeft
	var upper_right: Rect2 = expected.UpperRight
	var lower_left: Rect2 = expected.LowerLeft
	check(upper_right.position.x - upper_left.end.x == 128.0, "128px open vertical center lane")
	check(lower_left.position.y - upper_left.end.y == 48.0, "48px uninterrupted horizontal center lane")
	check(upper_left.position.x - 32.0 == 64.0 and 416.0 - upper_right.end.x == 64.0, "64px side routes")
	check(upper_left.position.y - 64.0 == 48.0 and 304.0 - lower_left.end.y == 48.0, "48px top and bottom routes")
	var perimeter_eyes := 0
	for eye in arena.eyes:
		if str(eye.wall.name) in ["TopWall", "BottomWall", "LeftWall", "RightWall", "LeftLip", "RightLip"]:
			perimeter_eyes += 1
		for axis in [Vector2(-1, 1), Vector2(1, -1)]:
			var mirrored: Vector2 = center + (eye.position - center) * axis
			var mirrored_normal: Vector2 = eye.facing_normal * axis
			var found := false
			for other in arena.eyes:
				if other.position.is_equal_approx(mirrored) and other.facing_normal.is_equal_approx(mirrored_normal):
					found = true
					break
			check(found, "Eye position and hit face mirror across each axis: " + str(eye.name))
	check(perimeter_eyes == 12, "Twelve perimeter eyes and four interior eyes")
	var props := arena.get_node("Props").get_children()
	for prop in props:
		if not prop is StaticBody2D:
			continue
		var shape: Shape2D = prop.get_node("CollisionShape2D").shape
		var half_size: Vector2
		if shape is CircleShape2D:
			half_size = Vector2.ONE * shape.radius
		else:
			half_size = shape.size * 0.5
		var footprint := Rect2(prop.position - half_size, half_size * 2.0)
		check(not footprint.intersects(Rect2(160, 64, 128, 240)) and not footprint.intersects(Rect2(32, 160, 384, 48)), "Scattered props leave the entire central cross clear")
		for axis in [Vector2(-1, 1), Vector2(1, -1)]:
			var mirrored: Vector2 = center + (prop.position - center) * axis
			var found := false
			for other in props:
				if other is StaticBody2D and other.position.is_equal_approx(mirrored):
					var other_shape: Shape2D = other.get_node("CollisionShape2D").shape
					found = other_shape.get_class() == shape.get_class()
					if found:
						break
			check(found, "Scattered prop collisions remain mirrored: " + str(prop.name))

func test_controls() -> void:
	player.begin_aim(Vector2(180, 120))
	check(player.aiming and is_equal_approx(Engine.time_scale, 0.25), "Aim slows time immediately")
	player.update_aim(Vector2(179, 120))
	player.release_aim(Vector2(179, 120))
	check(player.velocity == Vector2.ZERO and not arena.started, "Tiny gesture does not launch or start timer")
	player.begin_aim(Vector2(180, 120))
	player.update_aim(Vector2(132, 120))
	check(player.get_launch_velocity().is_equal_approx(Vector2(288, 0)), "Pull-back launches opposite pointer displacement")
	player.release_aim(Vector2(132, 120))
	check(arena.started and player.velocity.is_equal_approx(Vector2(288, 0)), "Release launches and starts timer")
	player.velocity = Vector2(-150, 100)
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(180, 168))
	check(player.velocity.is_equal_approx(Vector2(0, -288)), "Mid-flight relaunch replaces velocity")
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(132, 120), true)
	check(player.velocity.is_equal_approx(Vector2(0, -288)) and not player.aiming, "Canceled gesture preserves previous velocity")
	arena.retry()

func mouse(local: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = presentation.get_node("View").position + local * presentation.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func test_native_input() -> void:
	mouse(Vector2(412, 12), true)
	mouse(Vector2(412, 12), false)
	await process_frame
	check(not player.aiming and not arena.started, "Native retry button clicks cannot launch")
	mouse(Vector2(50, 12), true)
	mouse(Vector2(50, 12), false)
	check(not player.aiming, "HUD header consumes mouse clicks")
	mouse(Vector2(180, 12), true)
	mouse(Vector2(180, 12), false)
	check(not player.aiming and not arena.started, "HUD instruction clicks cannot launch")
	mouse(Vector2(180, 120), true)
	mouse(Vector2(100, 12), false)
	check(not player.aiming and player.velocity == Vector2.ZERO and Engine.time_scale == 1.0, "Release over GUI cancels aim safely")
	mouse(Vector2(180, 120), true)
	mouse(Vector2(-5, 120), false)
	check(not player.aiming and player.velocity == Vector2.ZERO, "Release outside letterboxed view cancels aim")
	mouse(Vector2(180, 120), true)
	check(player.aiming, "Container forwards gameplay press at fractional scale")
	var before: Vector2 = player.drag_vector
	player.position += Vector2(80, 0)
	for index in range(30):
		camera.advance(1.0 / 60.0)
	var motion := InputEventMouseMotion.new()
	motion.position = presentation.get_node("View").position + Vector2(180, 120) * presentation.display_scale
	motion.global_position = motion.position
	root.push_input(motion)
	check(player.drag_vector.is_equal_approx(before), "Stationary pointer never drifts while camera follows")
	mouse(Vector2(132, 120), false)
	check(player.velocity.is_equal_approx(Vector2(288, 0)), "Native viewport drag remains correct after camera pan")
	player.begin_aim(Vector2(180, 120))
	root.size = Vector2i(800, 500)
	await process_frame
	presentation.fit_view()
	arena.set_focused(true)
	check(not player.aiming, "Resize cancels unfinished gesture")
	check(is_equal_approx(presentation.display_scale, 500.0 / 336.0), "Resize uses the full available height")
	mouse(Vector2(180, 120), true)
	mouse(Vector2(132, 120), false)
	check(player.velocity.is_equal_approx(Vector2(288, 0)), "Drag speed/direction correct after resize")
	root.size = Vector2i(1280, 800)
	await process_frame
	presentation.fit_view()
	arena.retry()

func test_timing() -> void:
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await wait_real(0.12)
	arena.set_focused(true)
	player.begin_aim(Vector2(180, 120))
	clock.hit_stop()
	check(Engine.time_scale == 0.0, "Hit-stop outranks current aiming")
	await wait_real(0.065)
	check(is_equal_approx(Engine.time_scale, 0.25), "Hit-stop restores current aim state (scale=%s, aim=%s, suspended=%s)" % [Engine.time_scale, player.aiming, arena.suspended])
	clock.hit_stop()
	player.cancel_aim()
	await wait_real(0.065)
	check(is_equal_approx(Engine.time_scale, 1.0), "Aim cancellation during stop restores normal time")
	for index in range(4):
		player.begin_aim(Vector2(180, 120))
		clock.hit_stop()
		arena.retry()
		check(Engine.time_scale == 1.0 and not player.aiming and arena.remaining_eyes == arena.eyes.size(), "Rapid retry resets aim and hit-stop")
	await wait_real(0.065)
	check(Engine.time_scale == 1.0, "Old stop deadlines cannot overwrite retry")
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(132, 120))
	var time_before: float = arena.elapsed
	player.begin_aim(Vector2(180, 120))
	await wait_real(0.065)
	check(arena.elapsed - time_before >= 0.055, "Timer includes real aiming time")
	arena.set_focused(false)
	var paused_time: float = arena.elapsed
	await wait_real(0.065)
	check(is_equal_approx(arena.elapsed, paused_time) and Engine.time_scale == 1.0 and not player.aiming, "Focus loss suspends timer and clears slow motion")
	arena.set_focused(true)
	arena.retry()

func test_camera() -> void:
	for point in [Vector2(40, 72), Vector2(408, 72), Vector2(40, 296), Vector2(408, 296)]:
		player.position = point
		camera.snap_to(point)
		var visible: Rect2 = camera.visible_world_rect()
		check(arena.arena_bounds.encloses(visible), "Camera view stays inside map at each corner")
		check(camera.rotation == 0.0 and camera.zoom == Vector2.ONE, "Camera never rotates or changes zoom")
		check(visible == arena.arena_bounds, "One fixed view contains the entire level")
	arena.retry()

func bounced(_point: Vector2, _normal: Vector2, _speed: float) -> void:
	contacts += 1

func test_ricochets() -> void:
	clock.set_process(false)
	player.set_process(false)
	player.wall_bounced.connect(bounced)
	for eye in arena.eyes:
		eye.state = eye.State.CLOSED
	player.position = Vector2(400, 296)
	player.velocity = Vector2.ONE.normalized() * player.max_launch_speed
	player.movement_damping = 0.0
	contacts = 0
	player.advance(0.2)
	check(contacts >= 2 and player.velocity.x < 0 and player.velocity.y < 0, "Remaining sweep time handles a two-wall corner bank shot")
	for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		player.position = arena.spawn_position
		camera.snap_to(player.position)
		player.velocity = direction.normalized() * player.max_launch_speed
		for step in range(180):
			player.advance(1.0 / 30.0)
			camera.advance(1.0 / 30.0)
			check(Rect2(36, 68, 376, 232).has_point(player.position), "Maximum-speed movement cannot tunnel through perimeter")
			var query := PhysicsPointQueryParameters2D.new()
			query.position = player.global_position
			query.collision_mask = 1
			check(player.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Slime center never enters a solid island")
			check(camera.visible_world_rect().grow(-16).has_point(player.position), "Slime cannot outrun bounded camera follow")
	# Actual sweeps against broad horizontal and vertical island faces.
	# Mirrored shots must retain mirrored positions and reflected velocities.
	# Allow subpixel solver drift after several corner/flat contacts (2s),
	# rather than requiring bit-identical floating-point collision normals.
	for direction in [Vector2(-4, -1), Vector2(-2, -1)]:
		var reference := trace_quadrant_bank(direction)
		check(not reference.normals.is_empty(), "Quadrant bank has a real wall contact")
		var expected_normal := Vector2.DOWN if direction.x == -4.0 else Vector2.RIGHT
		check(not reference.normals.is_empty() and reference.normals[0].is_equal_approx(expected_normal), "Bank reaches the intended flat island face")
		for axis in [Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var mirrored := trace_quadrant_bank(direction * axis)
			check(mirrored.position.distance_to(arena.spawn_position + (reference.position - arena.spawn_position) * axis) < 0.5, "Mirrored bank routes have mirrored physical positions")
			check(mirrored.velocity.distance_to(reference.velocity * axis) < 0.75, "Mirrored bank routes have mirrored reflected velocities")
	for direction in [Vector2.LEFT, Vector2.RIGHT]:
		var bank := trace_quadrant_bank(direction, 84)
		var wall_name := "LeftLip" if direction == Vector2.LEFT else "RightLip"
		check(not bank.walls.is_empty() and bank.walls[0] == wall_name, "Horizontal launch contacts the new lip before the old side wall")
		check(not bank.normals.is_empty() and bank.normals[0].is_equal_approx(-direction) and bank.velocity.dot(direction) < 0.0, "New lip reflects the live swept slime cleanly")
	player.movement_damping = 0.35
	player.wall_bounced.disconnect(bounced)
	clock.set_process(true)
	player.set_process(true)
	arena.retry()
	await physics_frame

func trace_quadrant_bank(direction: Vector2, steps := 240) -> Dictionary:
	var normals: Array[Vector2] = []
	var walls: Array[String] = []
	var listener := func(wall: Node2D, _point: Vector2, normal: Vector2, _speed: float):
		normals.append(normal)
		walls.append(str(wall.name))
	player.wall_contact.connect(listener)
	player.position = arena.spawn_position
	player.velocity = direction.normalized() * player.max_launch_speed
	for step in range(steps):
		player.advance(1.0 / 120.0)
	player.wall_contact.disconnect(listener)
	return {"position": player.position, "velocity": player.velocity, "normals": normals, "walls": walls}

func hit_with_real_sweep(eye: Node2D) -> void:
	check(ContactFixture.sweep(player, eye), "Actual collision sweep can reach " + str(eye.name))
	clock.reset()

func test_targets_and_clear() -> void:
	clock.set_process(false)
	for index in range(arena.eyes.size()):
		var eye: Node2D = arena.eyes[index]
		check(not eye.try_hit(eye.wall, eye.position, eye.facing_normal, 47.0), "Shallow/weak impact cannot pop eye")
		check(not eye.try_hit(eye.wall, eye.position, -eye.facing_normal, 288.0), "Wrong surface normal cannot pop eye")
		check(not eye.try_hit(arena.get_node("WallPhysics/LowerRight") if eye.wall.name != "LowerRight" else arena.get_node("WallPhysics/UpperLeft"), eye.position, eye.facing_normal, 288.0), "Wrong wall cannot pop eye")
		hit_with_real_sweep(eye)
		check(not eye.active, "Each target reachable through an actual swept wall contact")
		check(arena.remaining_eyes == arena.eyes.size() - 1 - index, "Each target counts once")
		check(not eye.try_hit(eye.wall, eye.position, eye.facing_normal, 288.0), "Inactive eye cannot count twice")
	check(arena.cleared and not player.input_enabled and player.velocity == Vector2.ZERO, "Final pop clears and blocks gameplay immediately")
	player.begin_aim(Vector2(180, 120))
	check(not player.aiming, "Cannot relaunch after clear")
	arena.retry()
	check(arena.remaining_eyes == arena.eyes.size() and player.position == arena.spawn_position and arena.elapsed == 0.0, "Immediate retry resets the entire game loop")
	clock.set_process(true)
	await physics_frame
	# One eye tracks from all directions while remaining inside the white.
	var eye: Node2D = arena.eyes[0]
	clock.real_delta = 1.0 / 60.0
	for offset in [Vector2(100, 0), Vector2(-100, 0), Vector2(0, 100), Vector2(0, -100)]:
		player.position = eye.get_node("Visual").global_position + offset
		for index in range(40):
			eye._process(0.0)
		check(eye.get_node("Visual/Eyeball/Pupil").position.length() <= 3.1, "Tracking pupil stays bounded")
	arena.retry()

func test_final_indicator() -> void:
	var final_eye: Node2D = arena.eyes[7]
	for eye in arena.eyes:
		if eye != final_eye:
			eye.try_hit(eye.wall, eye.position, eye.facing_normal, 288.0)
	var hud: Control = arena.get_node("HUD/Control")
	camera.snap_to(arena.spawn_position)
	hud.update_hud()
	check(arena.remaining_eyes == 1 and not hud.marker_visible, "Whole-room view needs no off-screen indicator")
	check(camera.visible_world_rect().has_point(final_eye.get_node("Visual").global_position), "Final eye remains visible in the single room")
	hit_with_real_sweep(final_eye)
	hud.update_hud()
	check(arena.cleared and not hud.marker_visible, "Final pop immediately removes indicator")
	arena.retry()
	await process_frame

func test_reachable_layout() -> void:
	# Flood free circle positions at 4px spacing, using walls AND prop colliders.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var space := player.get_world_2d().direct_space_state
	var spawn := Vector2i(arena.spawn_position / 4.0)
	var visited := {spawn: true}
	var inspected := {spawn: true}
	var pending: Array[Vector2i] = [spawn]
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = point + direction
			if inspected.has(next) or not Rect2(32, 64, 384, 240).has_point(Vector2(next) * 4.0):
				continue
			inspected[next] = true
			query.transform = Transform2D(0.0, Vector2(next) * 4.0)
			if space.intersect_shape(query, 1).is_empty():
				visited[next] = true
				pending.append(next)
	var center: Vector2 = arena.spawn_position / 4.0
	var symmetric := true
	for cell: Vector2i in visited:
		for axis in [Vector2(-1, 1), Vector2(1, -1)]:
			if not visited.has(Vector2i(center + (Vector2(cell) - center) * axis)):
				symmetric = false
	check(symmetric, "All physically reachable circle positions mirror across both axes")
	for eye in arena.eyes:
		var approach: Vector2 = ContactFixture.approach(player, eye)
		check(approach.is_finite() and visited.has(Vector2i(approach / 4.0)), "Physical circle route from spawn reaches " + str(eye.name))
	# Probe the central cross and all four outer lanes with the real collider.
	for point in [Vector2(64, 184), Vector2(384, 184), Vector2(224, 88), Vector2(224, 280), Vector2(128, 88), Vector2(320, 88), Vector2(128, 280), Vector2(320, 280), arena.spawn_position]:
		check(visited.has(Vector2i(point / 4.0)), "Broad central and outer lanes connect to spawn")
	check(arena.get_node("Props").get_child_count() == 20, "Eight barrels, four crates, six torches, one gate and one banner")

func capture_regions() -> void:
	root.size = Vector2i(1280, 800)
	await process_frame
	presentation.fit_view()
	arena.retry()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/Users/avi/Documents/game_dev/godot/stop-staring-trijam393/docs/pixel_pivot/level.png")
	for eye in arena.eyes.slice(0, 4):
		hit_with_real_sweep(eye)
	await wait_real(0.2)
	player.position = arena.spawn_position
	camera.snap_to(player.position)
	arena.get_node("HUD/Control").update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/Users/avi/Documents/game_dev/godot/stop-staring-trijam393/docs/pixel_pivot/level_after_hits.png")
