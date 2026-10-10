extends Node2D
## The origin is the contacted surface. The face stays upright on every side.
signal closed(eye: Node2D)
signal reopened(eye: Node2D)
enum State { OPEN, CLOSED }

@export var wall_path: NodePath
@export var facing_normal := Vector2.DOWN
# The unchanged 24px socket has a 12px visible radius; contact gets 25% slack.
@export var hit_radius := 15.0
@export_range(0.1, 120.0, 0.1, "or_greater") var closed_duration := 20.0
@export var reopen_warning_duration := 3.0
@export var reopen_snap_duration := 0.1
@export var min_impact_speed := 48.0
@export var tracking_limit := 3.0
@export var gaze_enabled := true
@export_range(32.0, 256.0, 1.0) var gaze_length := 160.0
@export_range(4.0, 24.0, 1.0) var gaze_half_angle_degrees := 12.0
@export_range(0.0, 0.3, 0.01) var gaze_opacity := 0.18
var state := State.OPEN
# Retain the existing target-query API for HUD indicators.
var active: bool:
	get:
		return state == State.OPEN
var closed_remaining := 0.0
var closed_timer_active: bool:
	get:
		return state == State.CLOSED and closed_remaining > 0.0
var _pop_age := -1.0
var _snap_age := -1.0
var _pupil_offset := Vector2.ZERO
var _socket_color := Color.WHITE
var _gaze: Node2D
@onready var wall: StaticBody2D = get_node(wall_path)
@onready var arena := get_parent().get_parent()
@onready var visual: Node2D = $Visual
@onready var eyeball: Node2D = $Visual/Eyeball
@onready var pupil: Sprite2D = $Visual/Eyeball/Pupil
@onready var closed_visual: Sprite2D = $Visual/Closed

func _ready() -> void:
	visual.position = -facing_normal * 16.0
	_socket_color = $Visual/Socket.self_modulate
	_gaze = Node2D.new()
	_gaze.name = "GazeCone"
	_gaze.set_script(preload("res://experiments/pixel_pivot/gaze_cone.gd"))
	add_child(_gaze)

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	if active:
		var target: Vector2 = (arena.get_node("Slime").global_position - visual.global_position).normalized() * tracking_limit
		_pupil_offset = _pupil_offset.lerp(target, 1.0 - exp(-14.0 * dt)).limit_length(tracking_limit)
		pupil.position = _pupil_offset.round()
		if _snap_age >= 0.0:
			_snap_age += dt
			var t := clampf(_snap_age / maxf(0.001, reopen_snap_duration), 0.0, 1.0)
			eyeball.scale = Vector2(1.0, lerpf(0.45, 1.0, 1.0 - pow(1.0 - t, 3.0)))
			if t >= 1.0:
				_snap_age = -1.0
	elif closed_timer_active and closed_remaining <= reopen_warning_duration and not arena.cleared:
		# Only this eye warns; its timer is independent of every other eye.
		_pop_age = -1.0
		eyeball.hide()
		closed_visual.show()
		var phase: float = (reopen_warning_duration - closed_remaining) * TAU * 3.0
		visual.position = -facing_normal * 16.0 + facing_normal.orthogonal() * roundf(sin(phase) * 1.0)
		closed_visual.rotation = sin(phase) * 0.07
	elif _pop_age >= 0.0:
		_pop_age += dt
		if _pop_age < 0.045:
			eyeball.scale = Vector2(1.28, 1.18)
		elif _pop_age < 0.11:
			var t := (_pop_age - 0.045) / 0.065
			eyeball.scale = Vector2(1.28 - t * 0.3, maxf(0.02, 1.18 * (1.0 - t)))
		else:
			eyeball.hide()
			closed_visual.show()
			visual.position = -facing_normal * 16.0 + facing_normal * roundf(sin((_pop_age - 0.11) * 80.0) * exp(-(_pop_age - 0.11) * 28.0))
			if _pop_age >= 0.18:
				visual.position = -facing_normal * 16.0
				_pop_age = -1.0
	_gaze.update_gaze(dt)

func try_hit(contact_wall: Node2D, point: Vector2, normal: Vector2, speed: float) -> bool:
	if contact_wall != wall or speed < min_impact_speed or normal.dot(facing_normal) < 0.95:
		return false
	var offset := point - global_position
	var tangent := facing_normal.orthogonal()
	if absf(offset.dot(tangent)) > hit_radius or absf(offset.dot(facing_normal)) > 0.5:
		return false
	# Settle all independent deadlines before accepting a contact or winning.
	# A still-CLOSED eye cannot refresh; an expired eye is OPEN again.
	arena.advance_time()
	if not active or arena.cleared or arena.suspended:
		return false
	state = State.CLOSED
	closed_remaining = maxf(0.001, closed_duration)
	_snap_age = -1.0
	visual.position = -facing_normal * 16.0
	closed_visual.rotation = 0.0
	closed_visual.hide()
	eyeball.show()
	_pop_age = 0.0
	pupil.hide()
	eyeball.scale = Vector2(1.28, 1.18)
	$Visual/Socket.self_modulate = _socket_color * Color(0.78, 0.78, 0.84, 1.0)
	closed.emit(self)
	return true

func advance_closed_time(real_seconds: float) -> void:
	if not closed_timer_active or arena.cleared or arena.suspended:
		return
	closed_remaining = maxf(0.0, closed_remaining - real_seconds)
	if closed_remaining <= 0.0:
		reopen()

func freeze_closed_timer() -> void:
	closed_remaining = 0.0
	visual.position = -facing_normal * 16.0
	closed_visual.rotation = 0.0

func reopen(lock_on := true, animate := true) -> void:
	if arena.cleared:
		return
	var was_closed := state == State.CLOSED
	state = State.OPEN
	closed_remaining = 0.0
	# Both visual reactions are age-driven. Reset every transform synchronously;
	# no old Tween or delayed callback can overwrite a new hit or retry.
	_pop_age = -1.0
	_snap_age = 0.0 if animate and was_closed else -1.0
	_pupil_offset = Vector2.ZERO
	visual.position = -facing_normal * 16.0
	if lock_on:
		_pupil_offset = (arena.get_node("Slime").global_position - visual.global_position).normalized() * tracking_limit
	pupil.position = _pupil_offset.round()
	pupil.show()
	eyeball.scale = Vector2(1.0, 0.45) if _snap_age >= 0.0 else Vector2.ONE
	eyeball.show()
	closed_visual.hide()
	closed_visual.rotation = 0.0
	$Visual/Socket.self_modulate = _socket_color
	if was_closed:
		reopened.emit(self)

func reset_eye() -> void:
	reopen(false, false)
