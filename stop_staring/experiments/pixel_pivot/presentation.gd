extends Control
## Scale the complete 384x240 viewport, with letterboxing, never individual PNGs.
const LOGICAL_SIZE := Vector2(384, 240)
var display_scale := 1
@onready var arena := $View/World/PixelArena

func _ready() -> void:
	get_viewport().size_changed.connect(fit_view)
	fit_view()

func fit_view() -> void:
	var window_size := get_viewport_rect().size
	display_scale = maxi(1, int(minf(window_size.x / LOGICAL_SIZE.x, window_size.y / LOGICAL_SIZE.y)))
	$View.scale = Vector2.ONE * display_scale
	$View.position = ((window_size - LOGICAL_SIZE * display_scale) * 0.5).floor()
	# A resize changes pointer mapping. Cancel the gesture instead of launching it.
	arena.get_node("Slime").cancel_aim()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		arena.set_focused(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		arena.set_focused(true)
