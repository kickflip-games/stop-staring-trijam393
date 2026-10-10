extends Node2D
signal remaining_eyes_changed(remaining: int)
signal all_eyes_popped

@export var spawn_position := Vector2(320, 256)
@export var arena_bounds := Rect2(0, 0, 768, 480)
var eyes: Array[Node] = []
var remaining_eyes := 0
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
		eye.popped.connect(_on_popped)
	$Slime.wall_contact.connect(_on_wall_contact)
	$Slime.launched.connect(_on_launched)
	retry()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if started and not cleared and not suspended:
		elapsed += maxf(0.0, (now - _last_tick) / 1000000.0)
	_last_tick = now

func _on_launched(_velocity: Vector2) -> void:
	if not started:
		started = true
		_last_tick = Time.get_ticks_usec()

func _on_wall_contact(wall: Node2D, point: Vector2, normal: Vector2, speed: float) -> void:
	if cleared:
		return
	for eye in eyes:
		if eye.try_hit(wall, point, normal, speed):
			$Clock.hit_stop()
			$Slime.impact(normal, true)
			$Effects.pop_at(point, normal)

func _on_popped(_eye: Node2D) -> void:
	remaining_eyes -= 1
	remaining_eyes_changed.emit(remaining_eyes)
	if remaining_eyes == 0:
		# Capture real time up to this contact, then block launches immediately.
		if started and not suspended:
			elapsed += maxf(0.0, (Time.get_ticks_usec() - _last_tick) / 1000000.0)
		cleared = true
		$Slime.cancel_aim()
		$Slime.input_enabled = false
		$Slime.velocity = Vector2.ZERO
		all_eyes_popped.emit()
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
	$HUD/Control.update_hud()
	remaining_eyes_changed.emit(remaining_eyes)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			retry()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_P, KEY_ESCAPE]:
			_explicit_pause = not _explicit_pause
			update_pause()
			get_viewport().set_input_as_handled()

func set_focused(value: bool) -> void:
	_focused = value
	update_pause()

func update_pause() -> void:
	# Include the last active interval before suspension; discard paused intervals.
	var now := Time.get_ticks_usec()
	if started and not cleared and not suspended:
		elapsed += maxf(0.0, (now - _last_tick) / 1000000.0)
	_last_tick = now
	suspended = _explicit_pause or not _focused
	$Slime.cancel_aim()
	$Clock.suspended = suspended
	$Clock.reset()
	$HUD/Control.update_hud()
