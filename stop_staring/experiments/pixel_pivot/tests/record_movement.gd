extends SceneTree
## A reproducible native-input demonstration; gameplay physics stays enabled.
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var holding := false
var target := Vector2.ZERO
var launch_count := 0
var bounce_count := 0
const PRESS := Vector2(180, 120)

func _initialize() -> void:
	call_deferred("run")

func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = presentation.get_node("View").position + point * presentation.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func pointer() -> Vector2:
	return PRESS - (target - player.position).normalized() * 48.0

func begin_shot(point: Vector2) -> void:
	target = point
	holding = true
	button(PRESS, true)

func end_shot() -> void:
	button(pointer(), false)
	holding = false

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	presentation = load("res://experiments/pixel_pivot/pixel_pivot.tscn").instantiate()
	root.add_child(presentation)
	current_scene = presentation
	await process_frame
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	root.grab_focus()
	player.launched.connect(func(_velocity: Vector2): launch_count += 1)
	player.wall_bounced.connect(func(_point: Vector2, _normal: Vector2, _speed: float): bounce_count += 1)
	var previous := Time.get_ticks_usec()
	for frame in range(480):
		# MovieWriter forces a fixed delta. Pace it in real time too because the
		# prototype deliberately uses a real clock for camera, hit-stop and HUD.
		var wait_usec := 16667 - (Time.get_ticks_usec() - previous)
		if wait_usec > 0:
			OS.delay_usec(wait_usec)
		previous = Time.get_ticks_usec()
		match frame:
			10:
				arena.set_focused(true)
				arena.retry()
			20: begin_shot(arena.eyes[10].position)
			40: end_shot()
			85: begin_shot(arena.eyes[1].position)
			105: end_shot()
			220: begin_shot(arena.eyes[7].position)
			240: end_shot()
			350: begin_shot(arena.eyes[12].position)
			370: end_shot()
		if holding:
			var event := InputEventMouseMotion.new()
			event.position = presentation.get_node("View").position + pointer() * presentation.display_scale
			event.global_position = event.position
			root.push_input(event)
		await process_frame
	print("Recorded native input: ", launch_count, " launches, ", bounce_count, " bounces, eyes left: ", arena.remaining_eyes)
	quit(0 if launch_count == 4 and bounce_count > 0 and arena.remaining_eyes < arena.eyes.size() else 1)
