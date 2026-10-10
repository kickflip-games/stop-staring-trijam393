extends Node
## Sole time-scale owner; no delayed restoration callbacks.

@export var hit_stop_duration := 0.04
var real_delta := 0.0
var aiming := false
var suspended := false
var _aim_scale := 0.25
var _stop_until := 0
var _last_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_last_usec = Time.get_ticks_usec()
	reset()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	real_delta = 0.0 if suspended else minf((now - _last_usec) / 1000000.0, 0.05)
	_last_usec = now
	apply(now)

func set_aiming(value: bool, scale_value := 0.25) -> void:
	aiming = value
	_aim_scale = clampf(scale_value, 0.1, 1.0)
	apply(Time.get_ticks_usec())

func hit_stop() -> void:
	_stop_until = maxi(_stop_until, Time.get_ticks_usec() + int(hit_stop_duration * 1000000))
	apply(Time.get_ticks_usec())

func apply(now: int) -> void:
	Engine.time_scale = 1.0 if suspended else (0.0 if now < _stop_until else (_aim_scale if aiming else 1.0))

func reset() -> void:
	aiming = false
	_stop_until = 0
	_last_usec = Time.get_ticks_usec()
	real_delta = 0.0
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	reset()
