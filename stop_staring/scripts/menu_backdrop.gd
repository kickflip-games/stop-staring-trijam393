extends Control

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b171c"))
	var center := size * Vector2(0.75, 0.5)
	var radius := minf(size.x * 0.18, size.y * 0.29)
	draw_circle(center, radius * 1.26, Color("11272b"), true, -1, true)
	draw_arc(center, radius * 1.26, 0.0, TAU, 96, Color("234047"), 2, true)
	draw_circle(center, radius, Color("fff1cf"), true, -1, true)
	var tracking := (get_local_mouse_position() - center).limit_length(radius * 0.26)
	draw_circle(center + tracking, radius * 0.48, Color("76f2c2"), true, -1, true)
	draw_circle(center + tracking, radius * 0.23, Color("0b171c"), true, -1, true)
	draw_circle(center + tracking + Vector2(-radius * 0.11, -radius * 0.15), radius * 0.08, Color.WHITE, true, -1, true)
	for offset in [-1.0, 1.0]:
		draw_line(center + Vector2(offset * radius * 0.75, -radius * 1.16), center + Vector2(offset * radius * 0.9, -radius * 1.37), Color("76f2c2"), 5, true)
