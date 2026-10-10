extends "res://scripts/blob.gd"
## Freeze only the input projection during a gesture; all movement stays inherited.
## A stationary mouse must not become a launch as the camera pans or zooms.

var _projection_frozen := false
var _screen_origin := Vector3.ZERO
var _screen_x := Vector3.ZERO
var _screen_y := Vector3.ZERO


func _begin_aim(screen_position: Vector2) -> void:
	_projection_frozen = false
	super._begin_aim(screen_position)
	_screen_origin = super._on_plane(Vector2.ZERO)
	_screen_x = super._on_plane(Vector2.RIGHT) - _screen_origin
	_screen_y = super._on_plane(Vector2.DOWN) - _screen_origin
	_projection_frozen = true


func _on_plane(screen_position: Vector2) -> Vector3:
	if aiming and _projection_frozen:
		return _screen_origin + _screen_x * screen_position.x + _screen_y * screen_position.y
	return super._on_plane(screen_position)


func _cancel_aim() -> void:
	super._cancel_aim()
	_projection_frozen = false
