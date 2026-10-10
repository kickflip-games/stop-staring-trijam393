extends RigidBody3D
## Slingshot input on the XY plane. Release replaces the current velocity.

@export_range(0.5, 6.0, 0.1) var max_drag_distance: float = 3.0
@export_range(0.01, 0.5, 0.01) var drag_deadzone: float = 0.12
@export_range(1.0, 30.0, 0.5) var min_launch_speed: float = 4.0
@export_range(1.0, 40.0, 0.5) var max_launch_speed: float = 18.0

var aiming: bool = false
var drag_vector: Vector3 = Vector3.ZERO
var _drag_origin: Vector3
var _touch_index: int = -1


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
	_drag_origin = _on_plane(screen_position)
	drag_vector = Vector3.ZERO
	aiming = true


func _update_aim(screen_position: Vector2) -> void:
	drag_vector = (_drag_origin - _on_plane(screen_position)).limit_length(max_drag_distance)


func _release(screen_position: Vector2, canceled: bool = false) -> void:
	_update_aim(screen_position)
	if not canceled and drag_vector.length() >= drag_deadzone:
		var strength := inverse_lerp(drag_deadzone, maxf(max_drag_distance, drag_deadzone + 0.001), drag_vector.length())
		var speed := lerpf(min_launch_speed, maxf(min_launch_speed, max_launch_speed), clampf(strength, 0.0, 1.0))
		sleeping = false
		linear_velocity = drag_vector.normalized() * speed
	_cancel_aim()


func _cancel_aim() -> void:
	aiming = false
	_touch_index = -1
	drag_vector = Vector3.ZERO


func _on_plane(screen_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var hit: Vector3 = Plane(Vector3.BACK, 0.0).intersects_ray(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	return hit
