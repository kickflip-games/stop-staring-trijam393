extends SceneTree
## Scripted native-input/live-physics shot, then swept contacts to preview cues.
const BASE := "res://experiments/pixel_pivot/"
const ContactFixture := preload("res://experiments/pixel_pivot/tests/eye_contact_fixture.gd")
const PRESS := Vector2(224, 200)
var presentation: Control
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	call_deferred("run")

func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = presentation.get_node("View").position + point * presentation.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = presentation.get_node("View").position + point * presentation.display_scale
	event.global_position = event.position
	root.push_input(event)

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	presentation = load(BASE + "pixel_pivot.tscn").instantiate()
	root.add_child(presentation)
	current_scene = presentation
	await process_frame
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	root.grab_focus()
	var previous := Time.get_ticks_usec()
	for frame in range(520):
		# MovieWriter fixes delta; pace wall time as well for the production clock.
		var wait_usec := 16667 - (Time.get_ticks_usec() - previous)
		if wait_usec > 0:
			OS.delay_usec(wait_usec)
		previous = Time.get_ticks_usec()
		# Keep the recording fixture running if another app is focused while
		# capturing; ordinary gameplay still suspends on focus loss.
		if not arena._focused:
			arena.set_focused(true)
		if frame == 10:
			arena.set_focused(true)
			arena.retry()
		if frame == 20:
			player.position = ContactFixture.approach(player, arena.eyes[10])
			button(PRESS, true)
		if frame >= 20 and frame <= 50:
			if not player.aiming:
				button(PRESS, true)
			motion(PRESS + arena.eyes[10].facing_normal * (48.0 * (frame - 20) / 30.0))
		if frame == 55:
			if not player.aiming:
				button(PRESS, true)
			button(PRESS + arena.eyes[10].facing_normal * 48.0, false)
		if frame == 80:
			player.set_physics_process(false)
		if frame >= 100 and frame <= 154 and frame % 9 == 1:
			ContactFixture.sweep(player, arena.eyes[(frame - 100) / 9])
		if frame == 185:
			arena.eyes[0].closed_remaining = 3.0
		if frame == 240:
			arena.eyes[0].closed_remaining = 0.4
		if frame >= 290 and frame < 410 and (frame - 290) % 8 == 0:
			var index := (frame - 290) / 8
			if index < arena.eyes.size() - 1:
				ContactFixture.sweep(player, arena.eyes[index])
		if frame == 425:
			ContactFixture.sweep(player, arena.eyes[-1])
		await process_frame
	print("Juice preview: final clear=", arena.cleared, ", remaining=", arena.remaining_eyes)
	var success: bool = arena.cleared and arena.remaining_eyes == 0
	presentation.queue_free()
	await process_frame
	quit(0 if success else 1)
