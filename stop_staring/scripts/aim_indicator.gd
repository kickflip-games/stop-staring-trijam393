extends Node2D

@onready var player: RigidBody3D = get_node("../../Player")


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
	draw_line(origin + direction * 35.0, endpoint, color, 4.0, true)
	var perpendicular := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		endpoint, endpoint - direction * 16.0 + perpendicular * 8.0,
		endpoint - direction * 16.0 - perpendicular * 8.0]), color)
