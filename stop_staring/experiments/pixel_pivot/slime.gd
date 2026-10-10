extends CharacterBody2D
## Pull back in viewport coordinates. Camera movement cannot change the drag.

signal launched(launch_velocity: Vector2)
signal wall_contact(wall: Node2D, contact: Vector2, normal: Vector2, impact_speed: float)
signal wall_bounced(contact: Vector2, normal: Vector2, impact_speed: float)

@export var max_drag_distance := 48.0
@export var drag_deadzone := 2.0
@export var min_launch_speed := 64.0
@export var max_launch_speed := 288.0
@export var bounce_retention := 0.9
@export var movement_damping := 0.35
@export var settle_speed := 5.6
@export var aim_time_scale := 0.25

const MAX_COLLISIONS := 8
var aiming := false
var drag_vector := Vector2.ZERO
var input_enabled := true
var _press_position := Vector2.ZERO
var _touch_index := -1
var _impact_amount := 0.0
var _impact_direction := Vector2.RIGHT
var _wobble_time := 0.0
# Filled synchronously by the arena during wall_contact. An eye gets one
# strong reaction, without a second wall sound/squash on the same contact.
var eye_hit_this_contact := false
@onready var arena := get_parent()
@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite

func _physics_process(delta: float) -> void:
	if arena.suspended or arena.cleared:
		return
	advance(delta)

func advance(delta: float) -> void:
	velocity *= exp(-movement_damping * delta)
	if velocity.length() < settle_speed:
		velocity = Vector2.ZERO
	var remaining := delta
	for index in range(MAX_COLLISIONS):
		if velocity.is_zero_approx() or remaining <= 0.000001:
			break
		var motion := velocity * remaining
		var collision := move_and_collide(motion, false, 0.01)
		if collision == null:
			break
		remaining *= clampf(collision.get_remainder().length() / motion.length(), 0.0, 1.0)
		var normal := collision.get_normal()
		var speed := -velocity.dot(normal)
		if speed > 0.001:
			eye_hit_this_contact = false
			wall_contact.emit(collision.get_collider(), collision.get_position(), normal, speed)
			if arena.cleared:
				velocity = Vector2.ZERO
				break
			velocity = velocity.bounce(normal) * bounce_retention
			wall_bounced.emit(collision.get_position(), normal, speed)
			if not eye_hit_this_contact:
				impact(normal, false)
				if index == 0:
					arena.get_node("Effects").wall_at(collision.get_position(), normal, speed)
		else:
			# A recovery/separating contact must not flip velocity a second time.
			position += normal * 0.02
		if velocity.length() < settle_speed:
			velocity = Vector2.ZERO

func get_launch_velocity() -> Vector2:
	if drag_vector.length() < drag_deadzone:
		return Vector2.ZERO
	var fraction := inverse_lerp(drag_deadzone, max_drag_distance, drag_vector.length())
	return drag_vector.normalized() * lerpf(min_launch_speed, max_launch_speed, clampf(fraction, 0.0, 1.0))

func begin_aim(pointer: Vector2) -> void:
	if not input_enabled or arena.cleared or arena.suspended:
		return
	aiming = true
	_wobble_time = 0.0
	_press_position = pointer
	drag_vector = Vector2.ZERO
	arena.get_node("Clock").set_aiming(true, aim_time_scale)

func update_aim(pointer: Vector2) -> void:
	if not aiming:
		return
	# Fixed Camera2D zoom, fixed SubViewport: one viewport pixel is one world pixel.
	drag_vector = (_press_position - pointer).limit_length(max_drag_distance)
	arena.get_node("Effects").aim_sound(drag_vector.length() >= drag_deadzone, drag_vector.length() / max_drag_distance)

func release_aim(pointer: Vector2, canceled := false) -> void:
	if not aiming:
		return
	update_aim(pointer)
	if not canceled and input_enabled and not arena.cleared and not arena.suspended and drag_vector.length() >= drag_deadzone:
		velocity = get_launch_velocity()
		# Full speed and the visual recoil arrive in the same input event.
		cancel_aim()
		visual.scale = Vector2(0.74, 1.24)
		launched.emit(velocity)
	else:
		cancel_aim()

func cancel_aim() -> void:
	aiming = false
	drag_vector = Vector2.ZERO
	_touch_index = -1
	if is_inside_tree():
		arena.get_node("Clock").set_aiming(false)
		arena.get_node("Effects").aim_sound(false)
		_wobble_time = 0.0
		visual.position = Vector2.ZERO

func _input(event: InputEvent) -> void:
	# GUI can consume a release after a gameplay press. Cancel it before GUI routing.
	if not aiming:
		return
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed and event.index == _touch_index)
	if released and arena.get_node("HUD/Control").blocks_pointer(event.position):
		cancel_aim()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or arena.cleared or arena.suspended:
		return
	if event is InputEventMouse and event.device == -1:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and arena.get_node("HUD/Control").blocks_pointer(event.position):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch_index == -1:
		if event.pressed:
			begin_aim(event.position)
		else:
			release_aim(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and aiming and _touch_index == -1:
		update_aim(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and not aiming:
			_touch_index = event.index
			begin_aim(event.position)
		elif not event.pressed and event.index == _touch_index:
			release_aim(event.position, event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		update_aim(event.position)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	# Hold the contact silhouette during hit-stop; resolve in real time after it.
	if not arena.get_node("Clock").is_hit_stopping():
		_impact_amount = move_toward(_impact_amount, 0.0, dt * 7.0)
	var direction := drag_vector.normalized() if aiming and drag_vector.length() > drag_deadzone else velocity.normalized()
	if _impact_amount > 0.0:
		direction = _impact_direction
	visual.rotation = direction.angle() if not direction.is_zero_approx() else 0.0
	var strength := clampf(drag_vector.length() / max_drag_distance, 0.0, 1.0) if aiming else clampf(velocity.length() / max_launch_speed, 0.0, 1.0) * 0.45
	_wobble_time += dt
	var wobble := sin(_wobble_time * 62.0) * strength * strength if aiming else 0.0
	visual.position = direction.orthogonal() * roundf(wobble)
	var target := Vector2(1.0 + strength * 0.6 - _impact_amount * 0.38 + wobble * 0.035, 1.0 - strength * 0.3 + _impact_amount * 0.42)
	visual.scale = visual.scale.lerp(target, 1.0 - exp(-24.0 * dt))
	# Keep the supplied face upright while the visual body squashes along travel.
	sprite.rotation = -visual.rotation
	sprite.position = Vector2(0, -4).rotated(-visual.rotation)
	var animation := "slime_idle" if velocity.length() < 12.0 else "slime_run"
	if sprite.animation != animation:
		sprite.play(animation)
	queue_redraw()

func impact(normal: Vector2, eye_hit: bool) -> void:
	_impact_direction = normal
	_impact_amount = maxf(_impact_amount, 1.0 if eye_hit else 0.32)
	visual.rotation = normal.angle()
	visual.scale = Vector2(0.58, 1.48) if eye_hit else Vector2(0.84, 1.16)

func _draw() -> void:
	if not aiming or drag_vector.length() < drag_deadzone:
		return
	var direction := drag_vector.normalized()
	var length := minf(38.0, drag_vector.length())
	var tension := drag_vector.length() / max_drag_distance
	var color := Color("fff1cf").lerp(Color.WHITE, tension)
	for distance in range(10, int(length), 4):
		var point := (direction * distance).round()
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color(0.6, 1.0, 0.7, 0.18 * tension))
		draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)), color)
	var end := direction * length
	draw_line(end, end - direction.rotated(0.6) * 5, color, 2.0 if tension > 0.7 else 1.0)
	draw_line(end, end - direction.rotated(-0.6) * 5, color, 2.0 if tension > 0.7 else 1.0)

func reset_at(point: Vector2) -> void:
	cancel_aim()
	position = point
	velocity = Vector2.ZERO
	input_enabled = true
	_impact_amount = 0.0
	eye_hit_this_contact = false
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE
	visual.rotation = 0.0
	sprite.rotation = 0.0
	sprite.play("slime_idle")

func _exit_tree() -> void:
	if is_instance_valid(arena):
		var clock := arena.get_node_or_null("Clock")
		if clock != null:
			clock.reset()
