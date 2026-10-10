extends AudioStreamPlayer
## One continuous song across menu and gameplay scene changes.
var effects_warmed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var song := preload("res://audio/music/BeepBox-Song.wav").duplicate() as AudioStreamWAV
	song.loop_mode = AudioStreamWAV.LOOP_FORWARD
	song.loop_begin = 0
	song.loop_end = int(song.get_length() * song.mix_rate)
	stream = song
	volume_db = -14.0
	play()

func follow_clock(scale_value: float, suspended: bool) -> void:
	var should_pause := suspended or scale_value == 0.0
	# The clock runs every frame; only send actual audio state transitions.
	if stream_paused != should_pause:
		stream_paused = should_pause
	if scale_value > 0.0 and not is_equal_approx(pitch_scale, scale_value):
		pitch_scale = scale_value

func menu_mode() -> void:
	follow_clock(1.0, false)
