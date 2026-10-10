extends CharacterBody3D
## Slingshot input on the XY plane. Release replaces the current velocity.

signal wall_bounced(contact: Vector3, normal: Vector3, impact_speed: float)

@export_range(0.5, 6.0, 0.1) var max_drag_distance: float = 3.0
@export_range(0.01, 0.5, 0.01) var drag_deadzone: float = 0.12
@export_range(1.0, 30.0, 0.5) var min_launch_speed: float = 4.0
@export_range(1.0, 40.0, 0.5) var max_launch_speed: float = 18.0
@export_range(0.0, 1.0, 0.01) var bounce_retention: float = 0.9
@export_range(0.0, 3.0, 0.05) var movement_damping: float = 0.35
@export_range(0.0, 2.0, 0.05) var settle_speed: float = 0.35

const COLLISION_MARGIN: float = 0.001
const MAX_COLLISIONS_PER_STEP: int = 8

var aiming: bool = false
var drag_vector: Vector3 = Vector3.ZERO
var _drag_origin: Vector3
var _touch_index: int = -1


func _physics_process(delta: float) -> void:
	velocity.z = 0.0
	velocity *= exp(-movement_damping * delta)
	if velocity.length() < settle_speed:
		velocity = Vector3.ZERO
	var remaining_time := delta
	var played_wall_sound := false
	for step in range(MAX_COLLISIONS_PER_STEP):
		if velocity.is_zero_approx() or remaining_time <= 0.000001:
			break
		var motion := velocity * remaining_time
		var collision := move_and_collide(motion, false, COLLISION_MARGIN)
		if collision == null:
			break
		remaining_time *= clampf(collision.get_remainder().length() / motion.length(), 0.0, 1.0)
		var normal := collision.get_normal()
		# Recovery contacts can point away from travel. Only reflect incoming hits.
		if velocity.dot(normal) < -0.000001:
			if not played_wall_sound and collision.get_collider().is_in_group("walls"):
				$WallHitAudio.play()
				wall_bounced.emit(collision.get_position(), normal, -velocity.dot(normal))
				played_wall_sound = true
			velocity = velocity.bounce(normal) * bounce_retention
		if velocity.length() < settle_speed:
			velocity = Vector3.ZERO
	# The gameplay plane is fixed, including after collision recovery.
	position.z = 0.0


func get_launch_velocity() -> Vector3:
	if drag_vector.length() < drag_deadzone:
		return Vector3.ZERO
	var strength := inverse_lerp(drag_deadzone, maxf(max_drag_distance, drag_deadzone + 0.001), drag_vector.length())
	var speed := lerpf(min_launch_speed, maxf(min_launch_speed, max_launch_speed), clampf(strength, 0.0, 1.0))
	return drag_vector.normalized() * speed


func get_preview_endpoint(duration: float) -> Vector3:
	var predicted_velocity := get_launch_velocity()
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = global_transform
	parameters.margin = COLLISION_MARGIN
	var result := PhysicsTestMotionResult3D.new()
	var remaining_time := duration
	# Short sweeps match physics-step precision at the first contact.
	while remaining_time > 0.000001 and not predicted_velocity.is_zero_approx():
		var delta := minf(remaining_time, 1.0 / Engine.physics_ticks_per_second)
		predicted_velocity *= exp(-movement_damping * delta)
		if predicted_velocity.length() < settle_speed:
			break
		parameters.motion = predicted_velocity * delta
		if PhysicsServer3D.body_test_motion(get_rid(), parameters, result):
			return parameters.from.origin + result.get_travel()
		parameters.from.origin += parameters.motion
		remaining_time -= delta
	return parameters.from.origin


func _unhandled_input(event: InputEvent) -> void:
	# Touch is handled directly; ignore its synthetic mouse events.
	if event is InputEventMouse and event.device == -1:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not aiming:
			_touch_index = event.index
			_begin_aim(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release(event.position, event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_aim(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_index != -1:
			return
		if event.pressed:
			_begin_aim(event.position)
		elif aiming:
			_release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and aiming and _touch_index == -1:
		_update_aim(event.position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_aim()


func _begin_aim(screen_position: Vector2) -> void:
	$StretchAudio.stop()
	_drag_origin = _on_plane(screen_position)
	drag_vector = Vector3.ZERO
	aiming = true


func _update_aim(screen_position: Vector2, update_audio: bool = true) -> void:
	drag_vector = (_drag_origin - _on_plane(screen_position)).limit_length(max_drag_distance)
	if not update_audio:
		return
	if drag_vector.length() >= drag_deadzone:
		if not $StretchAudio.playing:
			$StretchAudio.play()
	else:
		$StretchAudio.stop()


func _release(screen_position: Vector2, canceled: bool = false) -> void:
	_update_aim(screen_position, false)
	if not canceled and drag_vector.length() >= drag_deadzone:
		velocity = get_launch_velocity()
	_cancel_aim()


func _cancel_aim() -> void:
	$StretchAudio.stop()
	aiming = false
	_touch_index = -1
	drag_vector = Vector3.ZERO


func _on_plane(screen_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var hit: Vector3 = Plane(Vector3.BACK, 0.0).intersects_ray(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	return hit
