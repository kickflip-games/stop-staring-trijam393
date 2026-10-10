extends Node
## The only writer of Engine.time_scale. Deadlines use the monotonic real clock.
## Priority: hit-stop, then aim anticipation, then normal gameplay.

@export_range(0.0, 0.1, 0.005) var hit_stop_duration: float = 0.05
var real_delta: float = 1.0 / 60.0
var _aiming := false
var _aim_scale := 0.25
var _stop_until_usec: int = 0
var _last_usec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_last_usec = Time.get_ticks_usec()
	reset()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	real_delta = minf(float(now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	if get_tree().paused:
		var player := get_node_or_null("../Player")
		if player != null and player.aiming:
			player._cancel_aim()
		reset()
	else:
		_apply(now)

func set_aiming(value: bool, time_scale: float = 0.25) -> void:
	_aiming = value
	_aim_scale = clampf(time_scale, 0.1, 1.0)
	_apply(Time.get_ticks_usec())

func hit_stop() -> void:
	_stop_until_usec = maxi(_stop_until_usec, Time.get_ticks_usec() + int(hit_stop_duration * 1000000.0))
	_apply(Time.get_ticks_usec())

func reset() -> void:
	_aiming = false
	_stop_until_usec = 0
	Engine.time_scale = 1.0

func _apply(now: int) -> void:
	Engine.time_scale = 0.0 if now < _stop_until_usec else (_aim_scale if _aiming else 1.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()

func _exit_tree() -> void:
	reset()
