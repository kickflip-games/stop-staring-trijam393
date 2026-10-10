extends Control
## Scale the complete room viewport, with letterboxing, never individual PNGs.
@onready var logical_size := Vector2($View/World.size)
var display_scale := 1.0
var _old_scale_mode := 0
var _old_scale_size := Vector2i.ZERO
var _old_minimum := Vector2i.ZERO
@onready var arena := $View/World/PixelArena

func _ready() -> void:
	var window := get_window()
	_old_scale_mode = window.content_scale_mode
	_old_scale_size = window.content_scale_size
	_old_minimum = window.min_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	window.min_size = Vector2i(logical_size)
	get_viewport().size_changed.connect(fit_view)
	fit_view()

func fit_view() -> void:
	var window_size := get_viewport_rect().size
	display_scale = maxf(0.001, minf(window_size.x / logical_size.x, window_size.y / logical_size.y))
	$View.scale = Vector2.ONE * display_scale
	$View.position = (window_size - logical_size * display_scale) * 0.5
	# A resize changes pointer mapping. Cancel the gesture instead of launching it.
	arena.get_node("Slime").cancel_aim()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		arena.set_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		arena.set_focused(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var point: Vector2 = (event.position - $View.position) / display_scale
		if not Rect2(Vector2.ZERO, logical_size).has_point(point):
			arena.get_node("Slime").cancel_aim()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		arena.get_node("Slime").cancel_aim()
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(fit_view)
	var window := get_window()
	window.content_scale_mode = _old_scale_mode
	window.content_scale_size = _old_scale_size
	window.min_size = _old_minimum
