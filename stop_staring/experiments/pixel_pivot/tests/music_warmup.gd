extends SceneTree
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0, "Web music and SFX use streamed playback")
	var music = root.get_node("Music")
	var home = load("res://ui/home_screen.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	check(music.playing, "Song starts in menu")
	check(music.stream is AudioStreamWAV, "Uses the supplied WAV")
	check(music.stream.data == preload("res://audio/music/BeepBox-Song.wav").data, "Uses the BeepBox song")
	check(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.stream.loop_end > 0, "WAV loops across the whole song")
	check(music.stream.get_length() > 12.0 and music.stream.get_length() < 15.0, "Imported song excludes the long silent tail")
	check(home.menu.get_node("Play").disabled, "Play waits for warmup")
	while not home._effects_ready:
		await process_frame
	check(music.effects_warmed, "Effects warmed")
	check(not home.menu.get_node("Play").disabled, "Play enabled")
	check(AudioServer.get_bus_index("EffectWarmup") == -1, "Muted warmup bus removed")
	var song_id = music.get_instance_id()
	home.start_game()
	await process_frame
	await process_frame
	check(root.get_node("Music").get_instance_id() == song_id, "Music survives transition")
	var arena = current_scene.get_node("View/World/PixelArena")
	arena.set_focused(true)
	arena.get_node("Clock").set_aiming(true)
	check(is_equal_approx(music.pitch_scale, 0.25), "Aim slows music")
	arena.toggle_pause()
	check(music.stream_paused, "Pause pauses music")
	change_scene_to_file("res://ui/home_screen.tscn")
	await process_frame
	await process_frame
	check(music.playing and not music.stream_paused and is_equal_approx(music.pitch_scale, 1.0), "Home restores continuous normal music")
	check(current_scene._effects_ready, "Returning home reuses warmup")
	print("Menu music and effect warmup checks: ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)
