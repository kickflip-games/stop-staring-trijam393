extends Control
@export var clear_reveal_delay := 0.52
var _win_age := -1.0
var marker_visible := false
var marker_position := Vector2.ZERO
var marker_direction := Vector2.RIGHT
var marker_target: Node2D
@onready var arena := get_parent().get_parent()

func _ready() -> void:
	process_priority = 80
	$Retry.pressed.connect(arena.retry)
	$Pause.pressed.connect(arena.toggle_pause)
	$Modal/Panel/Resume.pressed.connect(arena.resume)
	$Modal/Panel/Retry.pressed.connect(arena.retry)
	$Modal/Panel/Home.pressed.connect(_go_home)
	$Progress.draw.connect(_draw_progress)
	$Modal/Panel.pivot_offset = $Modal/Panel.size * 0.5
	update_hud()

func _go_home() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/home_screen.tscn")

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	if _win_age >= 0.0:
		_win_age += dt
	update_hud()

func finish() -> void:
	_win_age = 0.0

func reset_feedback() -> void:
	_win_age = -1.0
	$Modal/Panel.scale = Vector2.ONE
	queue_redraw()

func update_hud() -> void:
	$Remaining.text = "CLOSED %d / %d" % [arena.closed_eyes, arena.eyes.size()]
	# The overall run clock is score information, never a gameplay deadline.
	$TimeCaption.visible = arena.started
	$Elapsed.visible = arena.started
	$Elapsed.text = "%.1f" % arena.elapsed if arena.started else ""
	$Message.text = "PEACE AND QUIET" if arena.cleared else ("PAUSED" if arena.suspended else "CLOSE ALL EYES")
	var was_visible: bool = $Modal.visible
	$Modal.visible = arena.suspended or (arena.cleared and _win_age >= clear_reveal_delay)
	$Pause.disabled = arena.cleared
	if $Modal.visible:
		$Modal/Panel/Title.text = "FINALLY." if arena.cleared else "PAUSED"
		$Modal/Panel/Title.add_theme_color_override("font_color", Color("9eedb0") if arena.cleared else Color("ffebbf"))
		$Modal/Panel/Detail.text = ("PEACE AND QUIET.\nCLEAR TIME  %.1fs" % arena.elapsed) if arena.cleared else ("DRAG BACK, THEN RELEASE\nCLOSE ALL AT ONCE" if arena._focused else "WINDOW INACTIVE\nRETURN TO KEEP PLAYING")
		var reveal := maxf(0.0, _win_age - clear_reveal_delay)
		$Modal/Panel.scale = Vector2.ONE * (1.0 + 0.035 * sin(minf(1.0, reveal / 0.2) * PI)) if arena.cleared else Vector2.ONE
		$Modal/Panel/Resume.visible = not arena.cleared
		$Modal/Panel/Resume.disabled = not arena._focused
		$Modal/Panel/Retry.text = "PLAY AGAIN [R]" if arena.cleared else "RETRY [R]"
		if not was_visible and arena._focused:
			if arena.cleared:
				$Modal/Panel/Retry.grab_focus()
			else:
				$Modal/Panel/Resume.grab_focus()
	update_marker()
	$Progress.queue_redraw()

func blocks_pointer(point: Vector2) -> bool:
	return arena.cleared or $Modal.visible or $Header.get_rect().has_point(point)

func update_marker() -> void:
	marker_visible = false
	marker_target = null
	var viewport_rect := Rect2(Vector2.ZERO, size)
	var transform: Transform2D = arena.get_canvas_transform()
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
		# Include the triangle's four-pixel extent and the bottom message strip.
		var safe := Rect2(Vector2(16, 40), size - Vector2(32, 64))
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

func _draw_progress() -> void:
	# Pips fill as eyes close and empty individually as they reopen.
	for index in range(arena.eyes.size()):
		$Progress.draw_rect(Rect2(index * 4, 0, 3, 2), Color("9eedb0") if index < arena.closed_eyes else Color("303d52"))

func _draw() -> void:
	if not marker_visible:
		return
	var direction := marker_direction
	var points := PackedVector2Array([marker_position + direction * 4, marker_position - direction * 4 + direction.orthogonal() * 3, marker_position - direction * 4 - direction.orthogonal() * 3])
	draw_colored_polygon(points, Color("fff1cf"))
