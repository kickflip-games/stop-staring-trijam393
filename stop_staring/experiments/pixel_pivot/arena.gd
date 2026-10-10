extends Node2D
signal remaining_eyes_changed(remaining: int)
signal all_eyes_popped

@export var spawn_position := Vector2(224, 224)
@export var arena_bounds := Rect2(0, 0, 448, 384)
@export var final_hit_stop_duration := 0.12
var eyes: Array[Node] = []
var remaining_eyes := 0
var closed_eyes: int:
	get:
		return eyes.size() - remaining_eyes
var elapsed := 0.0
var started := false
var cleared := false
var suspended := false
var _explicit_pause := false
var _focused := true
var _last_tick := 0

func _ready() -> void:
	process_priority = -90
	_last_tick = Time.get_ticks_usec()
	eyes = $Eyes.get_children()
	for eye in eyes:
		eye.closed.connect(_on_eye_closed)
		eye.reopened.connect(_on_eye_reopened)
	$Slime.wall_contact.connect(_on_wall_contact)
	$Slime.launched.connect(_on_launched)
	retry()

func _process(_delta: float) -> void:
	advance_time()

func advance_time() -> void:
	# Monotonic wall time, not scaled delta or Clock's capped visual delta.
	# Also called before valid hits and pause transitions to settle deadlines.
	var now := Time.get_ticks_usec()
	var dt := maxf(0.0, (now - _last_tick) / 1000000.0)
	_last_tick = now
	if cleared or suspended:
		return
	if started:
		elapsed += dt
	# Each eye owns its remaining duration; this shared unscaled delta only
	# excludes pause/focus intervals and settles expiry before physical hits.
	for eye in eyes:
		eye.advance_closed_time(dt)

func _on_launched(launch_velocity: Vector2) -> void:
	advance_time()
	if not started:
		started = true
	$Effects.launch_at($Slime.position, launch_velocity)

func _on_wall_contact(wall: Node2D, point: Vector2, normal: Vector2, speed: float) -> void:
	advance_time()
	if cleared or suspended:
		return
	for eye in eyes:
		if eye.try_hit(wall, point, normal, speed):
			$Slime.eye_hit_this_contact = true
			return

func _on_eye_closed(eye: Node2D) -> void:
	# try_hit has settled every deadline and marked this eye CLOSED.
	remaining_eyes -= 1
	remaining_eyes_changed.emit(remaining_eyes)
	if remaining_eyes == 0:
		cleared = true
		$Slime.cancel_aim()
		$Slime.input_enabled = false
		$Slime.velocity = Vector2.ZERO
		for target in eyes:
			target.freeze_closed_timer()
		$Effects.finish()
		$HUD/Control.finish()
		all_eyes_popped.emit()
	$Clock.hit_stop(final_hit_stop_duration if cleared else -1.0)
	$Slime.impact(eye.facing_normal, true)
	$Effects.pop_at(eye.visual.global_position, eye.facing_normal, cleared)
	$HUD/Control.update_hud()

func _on_eye_reopened(_eye: Node2D) -> void:
	remaining_eyes += 1
	remaining_eyes_changed.emit(remaining_eyes)
	$HUD/Control.update_hud()

func retry() -> void:
	$Clock.reset()
	started = false
	cleared = false
	elapsed = 0.0
	_explicit_pause = false
	suspended = not _focused
	$Clock.suspended = suspended
	_last_tick = Time.get_ticks_usec()
	$Slime.reset_at(spawn_position)
	for eye in eyes:
		eye.reset_eye()
	remaining_eyes = eyes.size()
	$Effects.reset()
	$CameraRig/Camera2D.snap_to(spawn_position)
	$HUD/Control.reset_feedback()
	$HUD/Control.update_hud()
	remaining_eyes_changed.emit(remaining_eyes)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			retry()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_P, KEY_ESCAPE]:
			toggle_pause()
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	_explicit_pause = not _explicit_pause
	update_pause()

func resume() -> void:
	_explicit_pause = false
	update_pause()

func set_focused(value: bool) -> void:
	_focused = value
	update_pause()

func update_pause() -> void:
	# Include the last active interval before suspension; discard paused intervals.
	advance_time()
	suspended = _explicit_pause or not _focused
	$Slime.cancel_aim()
	$Clock.suspended = suspended
	$Clock.reset()
	$Effects.set_suspended(suspended)
	$HUD/Control.update_hud()
