extends SceneTree
## Run headless for checks, or without --headless for runtime screenshots.

var failures: Array[String] = []
var player: CharacterBody3D
var visual: Node3D
var collision: CollisionShape3D
var trail: CPUParticles3D
var face: Node3D
var mouth: Sprite3D
var camera: Camera3D


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
	face = visual.get_node("FacePivot")
	mouth = face.get_node("Mouth")
	camera = scene.get_node("Camera")
	player.set_physics_process(false)
	visual.set_process(false)
	player.get_node("WallHitAudio").stream = null
	player.get_node("StretchAudio").stream = null
	check(is_equal_approx((collision.shape as SphereShape3D).radius, 0.45), "original sphere radius is retained")
	check(visual.get_node("Mesh").get_parent() == visual, "mesh belongs to the visual pivot")
	check(visual.get_node("Mesh").mesh is ArrayMesh, "visual jelly is a separate custom mesh")
	check(face.get_parent() == visual, "mouth has its own visual face pivot")
	check(not trail.local_coords, "trail particles stay in world space after bounces")
	advance_visual(0.5)
	check(visual.scale.is_equal_approx(Vector3.ONE), "rest shape is normal")
	check(mouth.texture.resource_path.ends_with("mouth_happy.svg"), "rest uses happy mouth")
	var first_breath: float = visual.get_node("Mesh").scale.y
	advance_visual(0.75)
	var second_breath: float = visual.get_node("Mesh").scale.y
	check(absf(first_breath - second_breath) > 0.01, "idle body breathes slowly")
	check(absf(first_breath - 1.0) < 0.02 and absf(second_breath - 1.0) < 0.02, "idle breathing stays subtle")
	player.velocity = Vector3(12, 12, 0)
	advance_visual(0.5)
	check(visual.scale.x > 1.1 and visual.scale.y < 1.0 and visual.scale.z < 1.0, "fast movement stretches and compresses perpendicular axes")
	check(axis_alignment(player.velocity) > 0.999, "stretch axis follows diagonal velocity")
	check(trail.emitting and trail.color.a > 0.1, "fast travel enables a subtle trail")
	check(mouth.texture.resource_path.ends_with("mouth_excited.svg"), "fast travel uses excited mouth")
	check_face()
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
	check(mouth.texture.resource_path.ends_with("mouth_impact.svg"), "wall contact changes expression immediately")
	check_face()
	check(axis_alignment(Vector3.RIGHT) > 0.999, "impact compresses along wall normal")
	advance_visual(0.3)
	check(visual.scale.x > 1.1 and axis_alignment(player.velocity) > 0.999, "bounce recovers into outgoing speed stretch")
	check(mouth.texture.resource_path.ends_with("mouth_excited.svg"), "impact expression recovers into flight")
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
	var origin := camera.unproject_position(Vector3.ZERO)
	var end := camera.unproject_position(Vector3(-4, 0, 0))
	player._begin_aim(origin)
	player._update_aim(end, false)
	advance_visual(0.5)
	check(visual.position.x < -0.09 and visual.scale.x > 1.09, "aim pulls the blob opposite the launch direction")
	check(visual.scale.x > 1.5 and visual.scale.y < 0.75, "full aim is stronger than flight stretch")
	check(mouth.texture.resource_path.ends_with("mouth_excited.svg"), "aim uses excited mouth")
	check_face()
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
	# The face must stay on the front, upright and readable for every heading.
	for direction in range(8):
		var angle := direction * TAU / 8.0
		player.velocity = Vector3(cos(angle), sin(angle), 0) * 18.0
		advance_visual(0.5)
		check_face()
		visual.eye_impact(-player.velocity.normalized(), 18.0)
		check(visual.scale.x <= 0.31 and visual.scale.y >= 1.5, "fast eye hit gives a stronger bounded pancake")
		check(mouth.texture.resource_path.ends_with("mouth_impact.svg"), "eye impact uses impact mouth")
		check_face()
		advance_visual(0.3)
		check(mouth.texture.resource_path.ends_with("mouth_excited.svg"), "eye impact expression recovers")

	if DisplayServer.get_name() != "headless":
		await capture_examples(scene, camera)
	if failures.is_empty():
		print("PASS: jelly idle breathing, three expressions, upright front-facing mouth in eight headings/eye pancakes, directional stretch, wall squash/recovery, rapid corners, aim/cancel, launch, trail and unchanged sphere transforms")
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
	check(is_equal_approx((collision.shape as SphereShape3D).radius, 0.45), "deformation never changes the spherical collider")


func check_face() -> void:
	check(face.global_basis.orthonormalized().is_equal_approx(camera.global_basis.orthonormalized()), "mouth stays upright toward camera independently of the stretch axis")
	var front_depth := (mouth.global_position - visual.global_position).dot(camera.global_basis.z)
	check(front_depth > 0.45 * visual.scale.z, "mouth remains in front of the stretched body")
	var face_scale := face.global_basis.get_scale()
	check(face_scale.x >= 0.77 and face_scale.y >= 0.71, "mouth never collapses during a strong pancake")


func check(passed: bool, message: String) -> void:
	if not passed and not failures.has(message):
		failures.append(message)
