extends Node
## Owns navigation and level selection; the gameplay scene owns eye scoring.

const LEVELS := [
	{"name": "First Contact", "hint": "One eye. Make it blink.", "eyes": [["TopWall", Vector3(0, 5, 1.06), 0.0]]},
	{"name": "Bank On It", "hint": "Three walls. Find your angles.", "eyes": [["TopWall", Vector3(-5, 5, 1.06), 0.0], ["RightWall", Vector3(9, 1, 1.06), -PI / 2], ["BottomWall", Vector3(3, -5, 1.06), PI]]},
	{"name": "All Eyes On You", "hint": "Six eyes. Keep moving.", "eyes": [["TopWall", Vector3(-5, 5, 1.06), 0.0], ["TopWall", Vector3(5, 5, 1.06), 0.0], ["RightWall", Vector3(9, 0, 1.06), -PI / 2], ["BottomWall", Vector3(-4, -5, 1.06), PI], ["BottomWall", Vector3(4, -5, 1.06), PI], ["LeftWall", Vector3(-9, 0, 1.06), PI / 2]]}
]
const MINT := Color("76f2c2")
const CREAM := Color("fff1cf")

var mode: String = "splash"
var active_level: int = 0
var gameplay: Node3D
var elapsed: float = 0.0
var _ui: Control
var _timer_label: Label
var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	var transition := get_node("/root/EasyTransition")
	if transition.has_meta("game_destination"):
		var destination: Dictionary = transition.get_meta("game_destination")
		transition.remove_meta("game_destination")
		match destination.mode:
			"menu": _build_menu()
			"select": _build_level_select()
			"playing": _build_level(destination.level)
	else:
		_show_splash()


func _process(delta: float) -> void:
	if mode == "playing" and not get_node("/root/EasyTransition").is_transitioning:
		elapsed += delta
		_timer_label.text = "%05.1f s" % elapsed


func _unhandled_input(event: InputEvent) -> void:
	if mode == "splash" and ((event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		show_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			show_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and mode in ["playing", "clear"]:
			start_level(active_level)
			get_viewport().set_input_as_handled()


func _reset_ui() -> void:
	if is_instance_valid(_ui):
		_layer.remove_child(_ui)
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_ui)


func _close_level() -> void:
	if is_instance_valid(gameplay):
		gameplay.get_node("Player")._cancel_aim()
		remove_child(gameplay)
		gameplay.queue_free()
	gameplay = null


func _show_splash() -> void:
	_reset_ui()
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(background)
	var logo := TextureRect.new()
	logo.texture = load("res://art/menu/kickflip_logo.png")
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	logo.offset_left = -250
	logo.offset_top = -280
	logo.offset_right = 250
	logo.offset_bottom = 220
	_ui.add_child(logo)
	var credit := _label("KICKFLIP GAMES", 24, CREAM)
	credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	credit.offset_left = -250
	credit.offset_right = 250
	credit.offset_top = -130
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(credit)
	await get_tree().create_timer(1.8).timeout
	if mode == "splash":
		show_menu()


func show_menu() -> void:
	_navigate("menu")


func show_level_select() -> void:
	_navigate("select")


func start_level(index: int) -> void:
	if index >= 0 and index < LEVELS.size():
		_navigate("playing", index)


func _navigate(destination: String, index: int = 0) -> void:
	var transition := get_node("/root/EasyTransition")
	if transition.is_transitioning:
		return
	transition.set_meta("game_destination", {"mode": destination, "level": index})
	# Stop launches and timer during cover; the new scene resumes after uncover.
	if is_instance_valid(gameplay):
		var player := gameplay.get_node("Player")
		player._cancel_aim()
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	for button in _ui.find_children("*", "Button", true, false):
		button.disabled = true
	transition.transition_to("res://scenes/game.tscn")


func _build_menu() -> void:
	mode = "menu"
	_close_level()
	_reset_ui()
	_add_menu_background()
	var box := _menu_box()
	box.add_child(_label("THE WALLS HAVE EYES", 18, MINT))
	box.add_child(_label("STOP\nSTARING", 82, CREAM))
	box.add_child(_label("Drag back. Ricochet. Pop every eye.", 18, Color("a4b7ba")))
	_spacer(box, 18)
	var start := _button("START", func(): start_level(0))
	box.add_child(start)
	box.add_child(_button("LEVEL SELECT", show_level_select))
	start.grab_focus()
	_footer("A small game about a very big staring problem.")


func _build_level_select() -> void:
	mode = "select"
	_close_level()
	_reset_ui()
	_add_menu_background()
	var box := _menu_box()
	box.add_child(_label("PICK YOUR ROOM", 18, MINT))
	box.add_child(_label("LEVEL SELECT", 46, CREAM))
	_spacer(box, 16)
	for index in range(LEVELS.size()):
		box.add_child(_button("%02d   %s" % [index + 1, LEVELS[index].name.to_upper()], start_level.bind(index)))
		box.add_child(_label(LEVELS[index].hint, 16, Color("a4b7ba")))
	box.add_child(_button("BACK", show_menu))
	box.get_child(3).grab_focus()
	_footer("All three rooms are available. Escape returns to the title.")


func _build_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		return
	_close_level()
	_reset_ui()
	active_level = index
	elapsed = 0.0
	mode = "playing"
	gameplay = load("res://scenes/main.tscn").instantiate()
	# Configure before ready so the existing eye counter connects every target.
	var original_eye := gameplay.get_node("Eye")
	gameplay.remove_child(original_eye)
	original_eye.free()
	var eye_scene := load("res://scenes/eye.tscn") as PackedScene
	for target in LEVELS[index].eyes:
		var eye := eye_scene.instantiate()
		eye.player_path = NodePath("../Player")
		eye.wall_path = NodePath("../Arena/" + target[0])
		eye.position = target[1]
		eye.rotation.z = target[2]
		gameplay.add_child(eye)
	gameplay.all_eyes_popped.connect(_on_level_clear)
	add_child(gameplay)
	if get_node("/root/EasyTransition").is_transitioning:
		_resume_after_transition()
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 28
	header.offset_right = -28
	header.offset_top = 10
	header.add_theme_constant_override("separation", 14)
	_ui.add_child(header)
	var name_label := _label("%02d  /  %s" % [index + 1, LEVELS[index].name.to_upper()], 20, CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	_timer_label = _label("000.0 s", 20, MINT)
	header.add_child(_timer_label)
	var retry := _button("RETRY  [R]", start_level.bind(index))
	retry.custom_minimum_size = Vector2(150, 44)
	header.add_child(retry)
	var menu := _button("MENU  [ESC]", show_menu)
	menu.custom_minimum_size = Vector2(150, 44)
	header.add_child(menu)


func _resume_after_transition() -> void:
	var player := gameplay.get_node("Player")
	var transition := get_node("/root/EasyTransition")
	var tree := get_tree()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	while is_inside_tree() and transition.is_transitioning:
		await tree.process_frame
	if is_inside_tree() and mode == "playing" and is_instance_valid(player):
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)


func _on_level_clear() -> void:
	if mode != "playing":
		return
	mode = "clear"
	var player := gameplay.get_node("Player")
	player._cancel_aim()
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	_reset_ui()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.065, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -230
	box.offset_right = 230
	box.offset_top = -190
	box.add_theme_constant_override("separation", 16)
	_ui.add_child(box)
	box.add_child(_label("ROOM CLEARED", 20, MINT))
	box.add_child(_label("NO MORE\nSTARING.", 56, CREAM))
	box.add_child(_label("%s  ·  %.1f seconds" % [LEVELS[active_level].name, elapsed], 20, CREAM))
	if active_level + 1 < LEVELS.size():
		box.add_child(_button("NEXT LEVEL", start_level.bind(active_level + 1)))
	else:
		box.add_child(_label("All three rooms cleared. Nicely done.", 18, MINT))
	box.add_child(_button("TRY AGAIN", start_level.bind(active_level)))
	box.add_child(_button("MAIN MENU", show_menu))
	box.get_child(3 if active_level + 1 < LEVELS.size() else 4).grab_focus()


func _add_menu_background() -> void:
	var backdrop := Control.new()
	backdrop.set_script(load("res://scripts/menu_backdrop.gd"))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(backdrop)


func _menu_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_left = 0.1
	box.anchor_top = 0.2
	box.anchor_right = 0.47
	box.anchor_bottom = 0.85
	box.add_theme_constant_override("separation", 12)
	_ui.add_child(box)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("132e28"))
	button.add_theme_color_override("font_focus_color", CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = MINT if state in ["hover", "pressed"] else Color("18302d")
		style.border_color = MINT
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 24
		style.content_margin_right = 24
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	return button


func _spacer(parent: Node, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	parent.add_child(space)


func _footer(text: String) -> void:
	var label := _label(text, 16, Color("809698"))
	label.anchor_left = 0.1
	label.anchor_top = 0.94
	_ui.add_child(label)
