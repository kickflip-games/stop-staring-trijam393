extends Control
var marker_visible := false
var marker_position := Vector2.ZERO
var marker_direction := Vector2.RIGHT
var marker_target: Node2D
@onready var arena := get_parent().get_parent()

func _ready() -> void:
	process_priority = 80
	$Retry.pressed.connect(arena.retry)
	update_hud()

func _process(_delta: float) -> void:
	update_hud()

func update_hud() -> void:
	$Remaining.text = "EYES  %02d" % arena.remaining_eyes
	$Elapsed.text = "%05.1f s" % arena.elapsed
	$Message.text = "CLEAR!  R TO RETRY" if arena.cleared else ("PAUSED  /  P TO RESUME" if arena.suspended else ("DRAG BACK / RELEASE / R RETRY" if not arena.started else ""))
	update_marker()

func update_marker() -> void:
	marker_visible = false
	marker_target = null
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var camera: Camera2D = arena.get_node("CameraRig/Camera2D")
	var transform := arena.get_canvas_transform()
	var player: CharacterBody2D = arena.get_node("Slime")
	var closest := INF
	for eye in arena.eyes:
		if not eye.active:
			continue
		var center: Vector2 = eye.get_node("Visual").global_position
		if viewport_rect.grow(-8).has_point(transform * center):
			continue
		var distance := player.global_position.distance_squared_to(center)
		if distance < closest:
			closest = distance
			marker_target = eye
	if marker_target != null and not arena.cleared:
		var safe := Rect2(Vector2(12, 36), size - Vector2(24, 48))
		var from: Vector2 = (transform * player.global_position).clamp(safe.position, safe.end)
		var target: Vector2 = transform * marker_target.get_node("Visual").global_position
		marker_direction = (target - from).normalized()
		var distance := INF
		if marker_direction.x > 0.001:
			distance = minf(distance, (safe.end.x - from.x) / marker_direction.x)
		elif marker_direction.x < -0.001:
			distance = minf(distance, (safe.position.x - from.x) / marker_direction.x)
		if marker_direction.y > 0.001:
			distance = minf(distance, (safe.end.y - from.y) / marker_direction.y)
		elif marker_direction.y < -0.001:
			distance = minf(distance, (safe.position.y - from.y) / marker_direction.y)
		marker_position = (from + marker_direction * maxf(0, distance)).round().clamp(safe.position, safe.end)
		marker_visible = true
	queue_redraw()

func _draw() -> void:
	if not marker_visible:
		return
	var direction := marker_direction
	var points := PackedVector2Array([marker_position + direction * 4, marker_position - direction * 4 + direction.orthogonal() * 3, marker_position - direction * 4 - direction.orthogonal() * 3])
	draw_colored_polygon(points, Color("fff1cf"))
