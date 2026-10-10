extends Control
## Keep the home screen on the same pixel grid as the playable room.
const LOGICAL_SIZE := Vector2i(448, 384)
const GAME := preload("res://experiments/pixel_pivot/pixel_pivot.tscn")
var display_scale := 1.0
var _old_scale_mode := 0
var _old_scale_size := Vector2i.ZERO
var _old_minimum := Vector2i.ZERO
var _starting := false
var _effects_ready := false
@onready var menu: Control = $View/World/Menu

func _ready() -> void:
	get_node("/root/Music").menu_mode()
	var window := get_window()
	_old_scale_mode = window.content_scale_mode
	_old_scale_size = window.content_scale_size
	_old_minimum = window.min_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	window.min_size = LOGICAL_SIZE
	get_viewport().size_changed.connect(fit_view)
	fit_view()
	menu.get_node("Play").pressed.connect(start_game)
	menu.get_node("HowToPlay").pressed.connect(show_guide)
	menu.get_node("Guide/Panel/Back").pressed.connect(hide_guide)
	menu.get_node("Play").disabled = true
	menu.get_node("Play").text = "Loading..."
	warm_effects.call_deferred()

func warm_effects() -> void:
	var music := get_node("/root/Music")
	if not music.effects_warmed:
		# Render the actual room offscreen, including its screen-reading shader.
		var view := SubViewport.new()
		view.size = Vector2i(448, 336)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.gui_disable_input = true
		add_child(view)
		var room := preload("res://experiments/pixel_pivot/pixel_arena.tscn").instantiate()
		room.get_node("Clock").warming_up = true
		view.add_child(room)
		room.set_process_input(false)
		room.set_process_unhandled_input(false)
		room.get_node("Slime").input_enabled = false
		var bus_index := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus_index, "EffectWarmup")
		AudioServer.set_bus_mute(bus_index, true)
		var sounds: Array[Node] = room.find_children("*", "AudioStreamPlayer", true, false)
		for sound in sounds:
			sound.bus = &"EffectWarmup"
		var fx := room.get_node("Effects")
		fx.launch_at(Vector2(224, 184), Vector2(180, 0))
		fx.wall_at(Vector2(224, 184), Vector2.UP, 180.0)
		fx.pop_at(Vector2(224, 184), Vector2.UP, true)
		fx.aim_sound(true, 1.0)
		for sound in sounds:
			sound.play()
		# Wait for real rendered frames; headless checks have no GPU draw signal.
		for frame in range(3):
			if DisplayServer.get_name() == "headless":
				await get_tree().process_frame
			else:
				await RenderingServer.frame_post_draw
		for sound in sounds:
			sound.stop()
		room.free()
		view.queue_free()
		AudioServer.remove_bus(bus_index)
		music.effects_warmed = true
	_effects_ready = true
	menu.get_node("Play").text = "Play"
	menu.get_node("Play").disabled = false
	if not menu.get_node("Guide").visible:
		menu.get_node("Play").grab_focus()

func fit_view() -> void:
	var window_size := get_viewport_rect().size
	display_scale = maxf(0.001, minf(window_size.x / LOGICAL_SIZE.x, window_size.y / LOGICAL_SIZE.y))
	$View.scale = Vector2.ONE * display_scale
	$View.position = (window_size - Vector2(LOGICAL_SIZE) * display_scale) * 0.5

func start_game() -> void:
	if _starting or not _effects_ready:
		return
	_starting = true
	menu.get_node("Play").disabled = true
	get_tree().change_scene_to_packed.call_deferred(GAME)

func show_guide() -> void:
	menu.get_node("Guide").show()
	menu.get_node("Play").focus_mode = Control.FOCUS_NONE
	menu.get_node("HowToPlay").focus_mode = Control.FOCUS_NONE
	menu.get_node("Guide/Panel/Back").grab_focus()

func hide_guide() -> void:
	menu.get_node("Guide").hide()
	menu.get_node("Play").focus_mode = Control.FOCUS_ALL
	menu.get_node("HowToPlay").focus_mode = Control.FOCUS_ALL
	menu.get_node("HowToPlay").grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and menu.get_node("Guide").visible:
		hide_guide()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(fit_view)
	var window := get_window()
	window.content_scale_mode = _old_scale_mode
	window.content_scale_size = _old_scale_size
	window.min_size = _old_minimum
