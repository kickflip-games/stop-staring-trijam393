extends SceneTree
## Explicit regions for the supplied replacement sheet; render each on a 32px canvas.
const BASE := "res://assets/2d/eyes/"
const NAMES := ["look_center", "look_left", "look_right", "look_up", "look_down", "look_up_left", "look_up_right", "look_down_left", "look_down_right", "closed", "empty_socket", "hurt"]

func _initialize() -> void:
	var sheet: Texture2D = load(BASE + "eyes_sheet_v2.png")
	if sheet == null:
		push_error("Import eyes_sheet_v2.png first.")
		quit(1)
		return
	var frames := SpriteFrames.new()
	frames.resource_name = "Wall Eye States"
	frames.remove_animation("default")
	var textures: Array[AtlasTexture] = []
	for index in range(NAMES.size()):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(80 + (index % 4) * 332, 84 + (index / 4) * 304, 300, 304)
		texture.filter_clip = true
		textures.append(texture)
		frames.add_animation(NAMES[index])
		frames.set_animation_loop(NAMES[index], false)
		frames.add_frame(NAMES[index], texture)
	frames.add_animation("blink")
	frames.set_animation_speed("blink", 3.0)
	frames.add_frame("blink", textures[0], 5.0)
	frames.add_frame("blink", textures[9], 0.4)
	frames.add_frame("blink", textures[0], 1.0)
	assert(ResourceSaver.save(frames, BASE + "eye_sprites.tres") == OK)
	frames.take_over_path(BASE + "eye_sprites.tres")
	assert(ResourceSaver.save(textures[10], BASE + "empty_socket.tres") == OK)
	var collection := TileSetScenesCollectionSource.new()
	collection.resource_name = "Wall Eyes 32px"
	for index in range(5):
		var state: String = ["look_center", "blink", "closed", "empty_socket", "hurt"][index]
		var scene := Node2D.new()
		scene.name = "Eye_" + state
		scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.position = Vector2(8, 8)
		sprite.scale = Vector2(32.0 / 300.0, 32.0 / 304.0)
		sprite.sprite_frames = frames
		sprite.animation = state
		sprite.autoplay = state
		scene.add_child(sprite)
		sprite.owner = scene
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK)
		var path := BASE + "eye_" + state + ".tscn"
		assert(ResourceSaver.save(packed, path) == OK)
		packed.take_over_path(path)
		collection.create_scene_tile(packed, index)
		collection.set_scene_tile_display_placeholder(index, false)
		scene.free()
	assert(ResourceSaver.save(collection, BASE + "eye_tile_source.tres") == OK)
	print("Saved 12 eye poses, blink animation, empty socket and five scene tiles.")
	quit()
