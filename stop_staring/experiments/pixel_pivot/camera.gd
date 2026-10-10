extends Camera2D
## One fixed zoom; smooth a float anchor and snap only the rendered camera.
@export var dead_zone := Vector2(24, 16)
@export var follow_smoothing := 12.0
@export var look_ahead_enabled := false
@export var look_ahead_distance := 16.0
@export var frame_whole_room := true
var _anchor := Vector2.ZERO
var _center := Vector2.ZERO
var _impulse := Vector2.ZERO
var _impulse_age := -1.0
var _impulse_duration := 0.18
@onready var arena := get_parent().get_parent()

func _ready() -> void:
	process_priority = 40
	snap_to(arena.get_node("Slime").position)

func _process(_delta: float) -> void:
	advance(arena.get_node("Clock").real_delta)

func advance(dt: float) -> void:
	if _impulse_age >= 0.0:
		_impulse_age += dt
		if _impulse_age >= _impulse_duration:
			_impulse_age = -1.0
	var bump := Vector2.ZERO
	if _impulse_age >= 0.0:
		var t := _impulse_age / _impulse_duration
		bump = (_impulse * cos(t * TAU * 1.5) * pow(1.0 - t, 2.0)).round()
	# Camera offset provides recoil without changing framing, zoom or aim mapping.
	offset = bump
	if frame_whole_room:
		position = arena.arena_bounds.get_center()
		force_update_scroll()
		return
	var player: CharacterBody2D = arena.get_node("Slime")
	var displacement := player.position - _anchor
	_anchor += Vector2(displacement.x - clampf(displacement.x, -dead_zone.x, dead_zone.x), displacement.y - clampf(displacement.y, -dead_zone.y, dead_zone.y))
	var look := player.velocity.normalized() * look_ahead_distance if look_ahead_enabled and not player.aiming else Vector2.ZERO
	_center = _center.lerp(clamp_center(_anchor + look), 1.0 - exp(-follow_smoothing * dt))
	position = clamp_center(_center).round()
	force_update_scroll()

func kick(direction: Vector2, pixels: float, duration := 0.18) -> void:
	# A light wall touch must not overwrite a still-resolving eye impulse.
	var remaining := 0.0 if _impulse_age < 0.0 else _impulse.length() * (1.0 - _impulse_age / _impulse_duration)
	if pixels < remaining:
		return
	_impulse = direction.normalized() * clampf(pixels, 0.0, 3.0)
	_impulse_age = 0.0
	_impulse_duration = duration
	offset = _impulse.round()
	force_update_scroll()

func clamp_center(point: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom
	return point.clamp(arena.arena_bounds.position + half, arena.arena_bounds.end - half)

func snap_to(point: Vector2) -> void:
	_impulse_age = -1.0
	_impulse = Vector2.ZERO
	offset = Vector2.ZERO
	if frame_whole_room:
		point = arena.arena_bounds.get_center()
	_anchor = point
	_center = clamp_center(point)
	position = _center.round()
	reset_smoothing()
	force_update_scroll()

func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - size * 0.5, size)
