extends Node2D
## A quiet red gaze fan, clipped by the room's existing solid collision bodies.
const RAY_COUNT := 25
const REFRESH_INTERVAL := 1.0 / 30.0
const BANDS := [0.0, 0.35, 0.7, 1.0]
var direction := Vector2.ZERO
var ray_lengths := PackedFloat32Array()
var ray_directions := PackedVector2Array()
var apex := Vector2.ZERO
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _refresh_age := REFRESH_INTERVAL
@onready var eye: Node2D = get_parent()

func _ready() -> void:
	# Draw over the floor and wall shading, behind the eye, props and slime.
	z_as_relative = false
	z_index = 2
	eye.closed.connect(_state_changed)
	eye.reopened.connect(_state_changed)
	update_gaze(0.0, true)

func _state_changed(_eye: Node2D) -> void:
	update_gaze(0.0, true)

func update_gaze(real_seconds: float, force := false) -> void:
	if not eye.active or not eye.gaze_enabled or eye.arena.cleared:
		hide()
		return
	_refresh_age += real_seconds
	if not force and _refresh_age < REFRESH_INTERVAL:
		return
	_refresh_age = 0.0
	# Follow the same continuous offset as the pupil, rather than snapping
	# direction between the pupil sprite's few rendered pixel positions.
	apex = eye.pupil.global_position
	direction = eye._pupil_offset.normalized()
	if direction.is_zero_approx():
		direction = (eye.arena.get_node("Slime").global_position - apex).normalized()
	_points.clear()
	_colors.clear()
	_indices.clear()
	ray_lengths.clear()
	ray_directions.clear()
	# An eye embedded in a wall projects through its exposed side. Looking
	# behind its supporting surface cannot shine through the back of the wall.
	if direction.dot(eye.facing_normal) <= 0.08:
		hide()
		return
	var space := eye.get_world_2d().direct_space_state
	var half_angle := deg_to_rad(eye.gaze_half_angle_degrees)
	for index in range(RAY_COUNT):
		var angle := lerpf(-half_angle, half_angle, float(index) / (RAY_COUNT - 1))
		var ray := direction.rotated(angle)
		ray_directions.append(ray)
		var length: float = eye.gaze_length
		var forward := ray.dot(eye.facing_normal)
		if forward <= 0.08:
			length = 0.0
		else:
			# The pupil sits inside its supporting wall. Begin occlusion at the
			# exposed surface; only that supporting body is excluded from rays.
			var exit_distance := maxf(0.0, (eye.global_position - apex).dot(eye.facing_normal) / forward) + 0.5
			if exit_distance >= length:
				length = 0.0
			else:
				var query := PhysicsRayQueryParameters2D.create(apex + ray * exit_distance, apex + ray * length, 1, [eye.wall.get_rid()])
				query.hit_from_inside = true
				var hit := space.intersect_ray(query)
				if not hit.is_empty():
					length = maxf(0.0, apex.distance_to(hit.position) - 0.5)
		ray_lengths.append(length)
	for index in range(RAY_COUNT - 1):
		for band in range(BANDS.size() - 1):
			var a := _point(index, BANDS[band])
			var b := _point(index + 1, BANDS[band])
			var c := _point(index + 1, BANDS[band + 1])
			var d := _point(index, BANDS[band + 1])
			var ca := _color(index, BANDS[band])
			var cb := _color(index + 1, BANDS[band])
			var cc := _color(index + 1, BANDS[band + 1])
			var cd := _color(index, BANDS[band + 1])
			_triangle(a, b, c, ca, cb, cc)
			_triangle(a, c, d, ca, cc, cd)
	visible = not _indices.is_empty()
	queue_redraw()

func _point(index: int, fraction: float) -> Vector2:
	return to_local(apex + ray_directions[index] * ray_lengths[index] * fraction).round()

func _color(index: int, fraction: float) -> Color:
	var across := absf(2.0 * index / (RAY_COUNT - 1) - 1.0)
	var feather := pow(maxf(0.0, 1.0 - across * across), 0.7)
	var distance: float = ray_lengths[index] * fraction
	var fade := pow(maxf(0.0, 1.0 - distance / eye.gaze_length), 1.3)
	return Color(1.0, 0.08, 0.16, eye.gaze_opacity * feather * fade)

func _triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	if absf((b - a).cross(c - a)) < 0.1:
		return
	var start := _points.size()
	_points.append_array(PackedVector2Array([a, b, c]))
	_colors.append_array(PackedColorArray([ca, cb, cc]))
	_indices.append_array(PackedInt32Array([start, start + 1, start + 2]))

func _draw() -> void:
	# One cached draw command per eye, rather than one for every small triangle.
	if not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)
