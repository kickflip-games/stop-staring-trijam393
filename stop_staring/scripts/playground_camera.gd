extends Camera3D
## Fixed-angle XY framing. Orthographic sizes are visible world-space heights.

@export var player_path: NodePath = NodePath("../Player")
@export var level_path: NodePath = NodePath("..")
@export_range(1.0, 20.0, 0.5) var follow_smoothing: float = 8.0
@export var dead_zone_size := Vector2(1.2, 0.85)
@export_range(0.0, 6.0, 0.1) var velocity_look_ahead_distance: float = 2.4
@export_range(1.0, 20.0, 0.5) var look_ahead_smoothing: float = 4.0
@export_range(8.0, 24.0, 0.1) var normal_zoom: float = 13.8
@export_range(8.0, 24.0, 0.1) var high_speed_zoom: float = 15.0
@export_range(1.0, 30.0, 0.5) var high_speed_threshold: float = 10.0
@export_range(8.0, 24.0, 0.1) var aim_zoom: float = 12.6
@export_range(1.0, 20.0, 0.5) var zoom_smoothing: float = 5.0
@export_range(0.0, 1.0, 0.05) var aim_look_ahead_multiplier: float = 0.1
@export_range(0.0, 0.5, 0.01) var bounds_padding: float = 0.12

var _anchor := Vector2.ZERO
var _look_ahead := Vector2.ZERO
@onready var _player: CharacterBody3D = get_node(player_path)
@onready var _level: Node3D = get_node(level_path)


func _ready() -> void:
	# Follow after impact offsets, before the HUD projects the new camera frame.
	process_priority = 50
	_anchor = Vector2(_player.global_position.x, _player.global_position.y)
	size = _fitting_size(normal_zoom)
	_set_center(_clamp_center(_anchor))


func _process(_delta: float) -> void:
	advance(_level.get_node("TimeEffects").real_delta)


func advance(real_delta: float) -> void:
	var player_xy := Vector2(_player.global_position.x, _player.global_position.y)
	var displacement := player_xy - _anchor
	_anchor += Vector2(
		displacement.x - clampf(displacement.x, -dead_zone_size.x, dead_zone_size.x),
		displacement.y - clampf(displacement.y, -dead_zone_size.y, dead_zone_size.y))
	var speed := _player.velocity.length()
	var speed_blend := clampf(inverse_lerp(high_speed_threshold, maxf(_player.max_launch_speed, high_speed_threshold + 0.1), speed), 0.0, 1.0)
	var desired_zoom := aim_zoom if _player.aiming else lerpf(normal_zoom, high_speed_zoom, speed_blend)
	size = _fitting_size(lerpf(size, desired_zoom, 1.0 - exp(-zoom_smoothing * real_delta)))
	var look := Vector2(_player.velocity.x, _player.velocity.y) / maxf(high_speed_threshold, 0.1)
	look = look.limit_length(1.0) * velocity_look_ahead_distance
	# Never spend more than a fifth of the framing on anticipation.
	look = look.limit_length(size * 0.2)
	if _player.aiming:
		look *= aim_look_ahead_multiplier
	_look_ahead = _look_ahead.lerp(look, 1.0 - exp(-look_ahead_smoothing * real_delta))
	var target := _clamp_center(_anchor + _look_ahead)
	var center := Vector2(global_position.x, global_position.y).lerp(target, 1.0 - exp(-follow_smoothing * real_delta))
	_set_center(_clamp_center(center))


func _fitting_size(requested: float) -> float:
	var viewport := get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	var extent: Vector2 = _level.camera_bounds.size - Vector2.ONE * bounds_padding * 2.0
	# KEEP_HEIGHT, matching the existing camera. Also handle wide window resizing.
	return minf(requested, minf(extent.y, extent.x / aspect))


func _clamp_center(center: Vector2) -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	var half := Vector2(size * viewport.x / maxf(viewport.y, 1.0), size) * 0.5
	var bounds: Rect2 = _level.camera_bounds
	# ImpactFeedback owns h/v_offset. Reserve space for its maximum eye kick.
	var margin := Vector2.ONE * bounds_padding
	var offset := Vector2(h_offset, v_offset)
	var low := bounds.position + half + margin - offset
	var high := bounds.end - half - margin - offset
	return center.clamp(low, high)


func _set_center(center: Vector2) -> void:
	global_position.x = center.x
	global_position.y = center.y
