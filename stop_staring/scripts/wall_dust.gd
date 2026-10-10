extends Node3D
## Short, non-looping bursts made from the supplied 64px dust sheets.

@export_range(0.01, 0.1, 0.005) var dust_pixel_size: float = 0.04
@export_range(8.0, 30.0, 1.0) var animation_fps: float = 18.0
@export_range(1, 24, 1) var max_active_bursts: int = 12

var _frames := SpriteFrames.new()
var _last_variant: int = -1


func _ready() -> void:
	_frames.remove_animation("default")
	for index in range(8):
		var name := str(index)
		var sheet := load("res://art/dust/dust_%02d.png" % (index + 1)) as Texture2D
		_frames.add_animation(name)
		_frames.set_animation_loop(name, false)
		_frames.set_animation_speed(name, animation_fps)
		for frame in range(6):
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(frame * 64, 0, 64, 64)
			_frames.add_frame(name, texture)


func burst(contact: Vector3, normal: Vector3, impact_speed: float) -> void:
	if get_child_count() >= max_active_bursts:
		return
	var variant := randi_range(0, 7)
	if variant == _last_variant:
		variant = (variant + randi_range(1, 7)) % 8
	_last_variant = variant
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _frames
	sprite.pixel_size = dust_pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = contact + normal * 0.3
	sprite.position.z = 1.05
	sprite.rotation.z = atan2(normal.y, normal.x) - PI / 2 + randf_range(-0.2, 0.2)
	var size := randf_range(0.85, 1.15) * lerpf(0.7, 1.25, clampf(impact_speed / 18.0, 0, 1))
	sprite.scale = Vector3.ONE * size
	sprite.speed_scale = randf_range(0.85, 1.15)
	sprite.flip_h = randf() < 0.5
	add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play(str(variant))
	# Move the cloud away from the wall as it disperses.
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", sprite.position + normal * 0.45,
		6.0 / (animation_fps * sprite.speed_scale))
