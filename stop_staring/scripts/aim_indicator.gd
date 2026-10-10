extends Node2D

@export_range(0.1, 2.0, 0.1) var preview_duration: float = 0.8

@onready var player: CharacterBody3D = get_node("../../Player")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not player.aiming:
		return
	var camera := get_viewport().get_camera_3d()
	var origin := camera.unproject_position(player.global_position)
	var endpoint := camera.unproject_position(player.global_position + player.drag_vector)
	var direction := (endpoint - origin).normalized()
	draw_arc(origin, 35.0, 0.0, TAU, 48, Color(0.46, 0.95, 0.76, 0.7), 2.0, true)
	if player.drag_vector.length() < player.drag_deadzone:
		return
	endpoint += direction * 45.0
	var color := Color(1.0, 0.83, 0.4)
	var preview_end := camera.unproject_position(player.get_preview_endpoint(preview_duration))
	var preview_length := origin.distance_to(preview_end)
	for distance in range(40, int(preview_length), 14):
		draw_circle(origin + direction * distance, 2.0, Color(1.0, 0.83, 0.4, 0.5))
	draw_circle(preview_end, 5.0, color, false, 2.0, true)
	# Keep the direction arrow short; dots show the collision-limited first segment.
	var arrow_length := minf(minf(origin.distance_to(endpoint), 100.0), preview_length)
	if arrow_length <= 35.0:
		return
	endpoint = origin + direction * arrow_length
	draw_line(origin + direction * 35.0, endpoint, color, 4.0, true)
	var perpendicular := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		endpoint, endpoint - direction * 16.0 + perpendicular * 8.0,
		endpoint - direction * 16.0 - perpendicular * 8.0]), color)
