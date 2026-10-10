extends Node
## Sole time-scale owner; no delayed restoration callbacks.

@export var hit_stop_duration := 0.04
var real_delta := 0.0
var aiming := false
var suspended := false
var _aim_scale := 0.25
var _stop_until := 0
var _last_usec := 0
var music: AudioStreamPlayer
var warming_up := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_last_usec = Time.get_ticks_usec()
	music = get_node("/root/Music")
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

func hit_stop(duration := -1.0) -> void:
	var hold := hit_stop_duration if duration < 0.0 else duration
	_stop_until = maxi(_stop_until, Time.get_ticks_usec() + int(hold * 1000000))
	apply(Time.get_ticks_usec())

func is_hit_stopping() -> bool:
	return not suspended and Time.get_ticks_usec() < _stop_until

func apply(now: int) -> void:
	if warming_up:
		return
	Engine.time_scale = 1.0 if suspended else (0.0 if now < _stop_until else (_aim_scale if aiming else 1.0))
	if is_instance_valid(music):
		music.follow_clock(Engine.time_scale, suspended)

func reset() -> void:
	aiming = false
	_stop_until = 0
	_last_usec = Time.get_ticks_usec()
	real_delta = 0.0
	apply(_last_usec)

func _exit_tree() -> void:
	reset()
	if not warming_up and is_instance_valid(music):
		music.menu_mode()
