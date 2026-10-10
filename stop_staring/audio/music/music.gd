extends AudioStreamPlayer
## One continuous song across menu and gameplay scene changes.
var effects_warmed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var song := preload("res://audio/music/arcade_ride.mp3").duplicate() as AudioStreamMP3
	song.loop = true
	stream = song
	volume_db = -14.0
	play()

func follow_clock(scale_value: float, suspended: bool) -> void:
	stream_paused = suspended or scale_value == 0.0
	if scale_value > 0.0:
		pitch_scale = scale_value

func menu_mode() -> void:
	follow_clock(1.0, false)
