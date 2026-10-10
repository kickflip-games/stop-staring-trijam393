extends SceneTree
## Run headless for checks, or without --headless for runtime screenshots.

var failures: Array[String] = []
var player: CharacterBody3D
var visual: Node3D
var collision: CollisionShape3D
var trail: CPUParticles3D


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	root.size = Vector2i(1148, 717)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame
	player = scene.get_node("Player")
	visual = player.get_node("VisualPivot")
	collision = player.get_node("Collision")
	trail = player.get_node("MotionTrail")
	player.set_physics_process(false)
	visual.set_process(false)
	player.get_node("WallHitAudio").stream = null
	player.get_node("StretchAudio").stream = null
	check(is_equal_approx((collision.shape as SphereShape3D).radius, 0.45), "original sphere radius is retained")
	check(visual.get_node("Mesh").get_parent() == visual, "mesh belongs to the visual pivot")
	check(not trail.local_coords, "trail particles stay in world space after bounces")
	advance_visual(0.5)
	check(visual.scale.is_equal_approx(Vector3.ONE), "rest shape is normal")
	player.velocity = Vector3(12, 12, 0)
	advance_visual(0.5)
	check(visual.scale.x > 1.1 and visual.scale.y < 1.0 and visual.scale.z < 1.0, "fast movement stretches and compresses perpendicular axes")
	check(axis_alignment(player.velocity) > 0.999, "stretch axis follows diagonal velocity")
	check(trail.emitting and trail.color.a > 0.1, "fast travel enables a subtle trail")
	player.velocity = Vector3(-12, 12, 0)
	var previous_angle := visual.rotation.z
	visual._process(1.0 / 60)
	check(absf(visual.rotation.z - previous_angle) < 0.5, "direction changes interpolate instead of snapping")
	advance_visual(0.5)
	check(axis_alignment(player.velocity) > 0.999, "new direction settles correctly")
	player.velocity = Vector3(1, 0, 0)
	advance_visual(1.0)
	check(visual.scale.distance_to(Vector3.ONE) < 0.001 and not trail.emitting, "slow movement restores shape and stops trail")

	player.movement_damping = 0.0
	player.position = Vector3(8.4, 0, 0)
	player.velocity = Vector3(18, 0, 0)
	player._physics_process(1.0 / 60)
	check(player.velocity.is_equal_approx(Vector3(-16.2, 0, 0)), "wall squash leaves bounce velocity unchanged")
	check(visual.scale.x <= 0.6 and visual.scale.y >= 1.3, "real wall collision immediately pancakes the visual")
	check(axis_alignment(Vector3.RIGHT) > 0.999, "impact compresses along wall normal")
	advance_visual(0.3)
	check(visual.scale.x > 1.1 and axis_alignment(player.velocity) > 0.999, "bounce recovers into outgoing speed stretch")
	for frame in range(120):
		# Alternate corner normals rapidly; exercise every wall_contact in a step.
		var sign_value := -1.0 if frame % 2 else 1.0
		player.position = Vector3(sign_value * 8.4, sign_value * 4.4, 0)
		player.velocity = Vector3(sign_value * 18, sign_value * 18, 0)
		player._physics_process(0.1)
		visual._process(1.0 / 60)
		check(visual.scale.is_finite() and visual.scale.x > 0.0, "rapid contacts keep deformation valid")
		check_physics_shape()
	player.velocity = Vector3.ZERO
	advance_visual(1.0)
	check(visual.scale.distance_to(Vector3.ONE) < 0.001, "rapid collisions do not leave a stuck squash")

	player.position = Vector3.ZERO
	var camera: Camera3D = scene.get_node("Camera")
	var origin := camera.unproject_position(Vector3.ZERO)
	var end := camera.unproject_position(Vector3(-4, 0, 0))
	player._begin_aim(origin)
	player._update_aim(end, false)
	advance_visual(0.5)
	check(visual.position.x < -0.09 and visual.scale.x > 1.09, "aim pulls the blob opposite the launch direction")
	check(player.velocity.is_zero_approx(), "anticipation does not move the body")
	player._release(end)
	check(player.velocity.distance_to(Vector3(18, 0, 0)) < 0.001, "launch replaces velocity immediately")
	check(visual.scale.x < 0.9 and visual.position.is_zero_approx(), "release compresses immediately without gameplay delay")
	advance_visual(0.2)
	check(visual.scale.x > 1.15, "release snaps into speed stretch")
	player.velocity = Vector3.ZERO
	player._begin_aim(origin)
	player._update_aim(end, false)
	advance_visual(0.3)
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	advance_visual(0.5)
	check(visual.position.length() < 0.001 and visual.scale.distance_to(Vector3.ONE) < 0.001, "canceled aim restores the visual")
	check_physics_shape()

	if DisplayServer.get_name() != "headless":
		await capture_examples(scene, camera)
	if failures.is_empty():
		print("PASS: rest, directional stretch, smoothing, wall squash, bounce recovery, rapid corners, aim/cancel, immediate launch, trail and unchanged collision transforms")
	else:
		for failure in failures:
			push_error(failure)
	for audio in scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func capture_examples(_scene: Node3D, camera: Camera3D) -> void:
	# Settle native window focus before driving the existing launch controls.
	await create_timer(0.5).timeout
	player.set_process_unhandled_input(false)
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	advance_visual(1.0)
	await snapshot("rest")
	var origin := camera.unproject_position(Vector3.ZERO)
	var end := camera.unproject_position(Vector3(-3, -1.5, 0))
	player._begin_aim(origin)
	player._update_aim(end, false)
	advance_visual(0.5)
	await snapshot("aim")
	player._release(end)
	await snapshot("release")
	player.set_physics_process(true)
	visual.set_process(true)
	for frame in range(12):
		await physics_frame
	player.set_physics_process(false)
	visual.set_process(false)
	await snapshot("fast")
	player.position = Vector3(8.4, -1.5, 0)
	player.velocity = Vector3(18, 0, 0)
	player._physics_process(1.0 / 60)
	await snapshot("impact")
	player.set_physics_process(true)
	visual.set_process(true)
	for frame in range(12):
		await physics_frame
	player.set_physics_process(false)
	visual.set_process(false)
	await snapshot("bounce")


func snapshot(stage: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/stop-staring-blob-%s.png" % stage)


func advance_visual(duration: float) -> void:
	for frame in range(ceili(duration * 60)):
		visual._process(1.0 / 60)
		check_physics_shape()


func axis_alignment(direction: Vector3) -> float:
	return absf(visual.basis.x.normalized().dot(direction.normalized()))


func check_physics_shape() -> void:
	check(player.scale.is_equal_approx(Vector3.ONE) and collision.scale.is_equal_approx(Vector3.ONE), "body and collision stay at unit scale")
	check(player.basis.is_equal_approx(Basis.IDENTITY) and collision.basis.is_equal_approx(Basis.IDENTITY), "visual rotation never rotates physics")


func check(passed: bool, message: String) -> void:
	if not passed and not failures.has(message):
		failures.append(message)
