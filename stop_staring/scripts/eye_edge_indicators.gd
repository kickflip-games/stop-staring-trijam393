extends Control
## One quiet eye/arrow per off-screen active target. Sorted edge spacing, no map.

@export_range(12.0, 64.0, 1.0) var edge_padding: float = 28.0
@export_range(24.0, 64.0, 1.0) var minimum_spacing: float = 36.0
@export_range(4.0, 16.0, 1.0) var icon_radius: float = 9.0
@export_range(0.0, 180.0, 1.0) var hud_top_clearance: float = 72.0
@export var counter_reserved_rect := Rect2(16, 92, 315, 55)

var markers: Array[Dictionary] = []
@onready var _level: Node3D = get_node("../..")
@onready var _camera: Camera3D = _level.get_node("Camera")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100


func _process(_delta: float) -> void:
	update_markers()
	queue_redraw()


func update_markers() -> void:
	markers.clear()
	var viewport := get_viewport().get_visible_rect()
	var frame := Rect2(Vector2(edge_padding, hud_top_clearance + edge_padding),
		viewport.size - Vector2(edge_padding * 2.0, hud_top_clearance + edge_padding * 2.0))
	if frame.size.x <= 0.0 or frame.size.y <= 0.0:
		return
	var center := viewport.size * 0.5
	var groups: Array = [[], [], [], []] # left, right, top, bottom
	for eye in _level._eyes:
		if not is_instance_valid(eye) or not eye.active:
			continue
		var projected := _camera.unproject_position(eye.global_position)
		if not _camera.is_position_behind(eye.global_position) and viewport.has_point(projected):
			continue
		var direction := (projected - center).normalized()
		if _camera.is_position_behind(eye.global_position):
			direction = -direction
		var tx := INF if absf(direction.x) < 0.0001 else ((frame.end.x if direction.x > 0.0 else frame.position.x) - center.x) / direction.x
		var ty := INF if absf(direction.y) < 0.0001 else ((frame.end.y if direction.y > 0.0 else frame.position.y) - center.y) / direction.y
		var point := center + direction * minf(tx, ty)
		var edge := (1 if direction.x > 0.0 else 0) if tx < ty else (3 if direction.y > 0.0 else 2)
		groups[edge].append({"eye": eye, "position": point, "direction": direction, "edge": edge})
	for edge in range(4):
		var vertical := edge < 2
		var group: Array = groups[edge]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.position.y < b.position.y if vertical else a.position.x < b.position.x)
		var low := frame.position.y if vertical else frame.position.x + minimum_spacing
		var high := frame.end.y if vertical else frame.end.x - minimum_spacing
		# The left edge avoids the existing EYES LEFT counter as well as the header.
		if edge == 0:
			low = maxf(low, counter_reserved_rect.end.y + icon_radius + 4.0)
		if edge == 2:
			low = maxf(low, counter_reserved_rect.end.x + icon_radius + 4.0)
		var spacing := minf(minimum_spacing, (high - low) / maxf(group.size() - 1, 1))
		var previous := low - spacing
		for marker in group:
			var value: float = marker.position.y if vertical else marker.position.x
			value = maxf(value, previous + spacing)
			if vertical:
				marker.position.y = value
			else:
				marker.position.x = value
			previous = value
		# Backward packing prevents the forward pass from pushing markers off-screen.
		var next := high + spacing
		for index in range(group.size() - 1, -1, -1):
			var marker: Dictionary = group[index]
			var value: float = marker.position.y if vertical else marker.position.x
			value = minf(value, next - spacing)
			if vertical:
				marker.position.y = value
			else:
				marker.position.x = value
			next = value
		markers.append_array(group)


func _draw() -> void:
	for marker in markers:
		var point: Vector2 = marker.position
		var direction: Vector2 = marker.direction
		draw_circle(point, icon_radius + 4.0, Color(0.025, 0.06, 0.065, 0.90))
		var outline := PackedVector2Array()
		for step in range(25):
			var angle := TAU * step / 24.0
			outline.append(point + Vector2(cos(angle) * icon_radius, sin(angle) * icon_radius * 0.6))
		draw_colored_polygon(outline, Color("fff1cf"))
		draw_circle(point + direction * 2.0, icon_radius * 0.32, Color("18302d"))
		var tip := point + direction * (icon_radius + 9.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 5.0 + direction.orthogonal() * 3.0,
			tip - direction * 5.0 - direction.orthogonal() * 3.0]), Color("76f2c2"))
