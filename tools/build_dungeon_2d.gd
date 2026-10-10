extends SceneTree
## Rebuild the editable resources from the bundled sheets and atlas catalog.
## Run: Godot --headless --path stop_staring --script ../tools/build_dungeon_2d.gd

const ASSETS := "res://assets/2d/dungeon_crawler/"


func _initialize() -> void:
	var tileset := TileSet.new()
	tileset.resource_name = "Dungeon Crawler 16x16"
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "tile_name")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, "category")
	tileset.set_custom_data_layer_type(1, TYPE_STRING)
	var sources: Array[TileSetAtlasSource] = []
	for filename in ["full_tilemap.png", "full_spritesheet.png"]:
		var source := TileSetAtlasSource.new()
		source.resource_name = "Environment" if sources.is_empty() else "Sprites and Effects"
		source.texture = load(ASSETS + filename)
		if source.texture == null:
			push_error("Import the bundled PNGs in Godot before rebuilding the 2D resources.")
			quit(1)
			return
		source.texture_region_size = Vector2i(16, 16)
		sources.append(source)
		tileset.add_source(source, sources.size() - 1)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "atlas_catalog.json"))
	for entry: Dictionary in catalog:
		var source := sources[int(entry.source)]
		var coord := Vector2i(entry.coord[0], entry.coord[1])
		var size := Vector2i(entry.size[0], entry.size[1])
		source.create_tile(coord, size)
		var tile := source.get_tile_data(coord, 0)
		# Anchor wide/tall sprites at the top-left grid cell, matching source pixels.
		tile.texture_origin = -(size - Vector2i.ONE) * 8
		tile.set_custom_data("tile_name", entry.name)
		tile.set_custom_data("category", entry.category)
		if not entry.collision.is_empty():
			var polygon := PackedVector2Array()
			for index in range(0, entry.collision.size(), 2):
				polygon.append(Vector2(entry.collision[index], entry.collision[index + 1]))
			tile.add_collision_polygon(0)
			tile.set_collision_polygon_points(0, 0, polygon)
	if ResourceSaver.save(tileset, ASSETS + "dungeon_tileset.tres", ResourceSaver.FLAG_CHANGE_PATH) != OK:
		quit(1)
		return
	tileset.take_over_path(ASSETS + "dungeon_tileset.tres")

	var frames := SpriteFrames.new()
	frames.resource_name = "Dungeon Crawler Animations"
	frames.remove_animation("default")
	var sheet: Texture2D = sources[1].texture
	add_strip(frames, sheet, "fly", Vector2i(0, 0), 4)
	add_strip(frames, sheet, "bomb", Vector2i(4, 0), 10)
	add_strip(frames, sheet, "goblin_idle", Vector2i(0, 1), 6)
	add_strip(frames, sheet, "goblin_run", Vector2i(0, 2), 6)
	add_strip(frames, sheet, "slime_idle", Vector2i(0, 3), 6)
	add_strip(frames, sheet, "slime_run", Vector2i(0, 4), 6)
	add_strip(frames, sheet, "knight_idle", Vector2i(0, 5), 6)
	add_strip(frames, sheet, "knight_run", Vector2i(0, 6), 6)
	add_strip(frames, sheet, "chest_idle", Vector2i(6, 1), 8)
	add_strip(frames, sheet, "chest_open", Vector2i(14, 1), 1)
	add_strip(frames, sheet, "torch", Vector2i(6, 3), 6)
	add_strip(frames, sheet, "spikes", Vector2i(6, 4), 10)
	add_strip(frames, sheet, "enemy_death", Vector2i(6, 2), 4, Vector2i(16, 16), false, 12.0)
	add_strip(frames, sheet, "slash", Vector2i(12, 3), 3, Vector2i(16, 16), false, 12.0)
	add_strip(frames, sheet, "explosion", Vector2i(10, 5), 7, Vector2i(32, 32), false, 12.0)
	add_strip(frames, sheet, "door_open", Vector2i(0, 7), 10, Vector2i(32, 32), false)
	add_region(frames, sheet, "door_open", Rect2(128, 80, 32, 32))
	frames.add_animation("hit")
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 12.0)
	for x in [176, 184, 192]:
		add_region(frames, sheet, "hit", Rect2(x, 40, 8, 8))
	if ResourceSaver.save(frames, ASSETS + "dungeon_sprites.tres", ResourceSaver.FLAG_CHANGE_PATH) != OK:
		quit(1)
		return
	frames.take_over_path(ASSETS + "dungeon_sprites.tres")
	build_preview(tileset, frames)
	print("Saved 2D assets: ", catalog.size(), " tiles, ", frames.get_animation_names().size(), " animations.")
	quit()


func add_strip(frames: SpriteFrames, sheet: Texture2D, animation: StringName, start: Vector2i, count: int, size := Vector2i(16, 16), loops := true, fps := 8.0) -> void:
	frames.add_animation(animation)
	frames.set_animation_loop(animation, loops)
	frames.set_animation_speed(animation, fps)
	for index in range(count):
		add_region(frames, sheet, animation, Rect2(Vector2(start * 16 + Vector2i(index * size.x, 0)), Vector2(size)))


func add_region(frames: SpriteFrames, sheet: Texture2D, animation: StringName, region: Rect2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	texture.filter_clip = true
	frames.add_frame(animation, texture)


func build_preview(tileset: TileSet, frames: SpriteFrames) -> void:
	var scene := Node2D.new()
	scene.name = "DungeonTilesPreview"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("17171f")
	backdrop.size = Vector2(1280, 800)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach(scene, scene, backdrop)
	label(scene, "Title", "DUNGEON CRAWLER / 2D TILESET", Vector2(64, 28), 28)
	label(scene, "Subtitle", "16 x 16 grid  /  4x nearest filtering  /  editable floor, walls and props", Vector2(64, 70), 17)
	var room := Node2D.new()
	room.name = "Room"
	room.position = Vector2(64, 128)
	room.scale = Vector2(4, 4)
	attach(scene, scene, room)
	var floor_layer := layer(scene, room, "Floor", tileset)
	var wall_layer := layer(scene, room, "Walls", tileset)
	var props := layer(scene, room, "Props", tileset)
	for y in range(9):
		for x in range(14):
			var coord := Vector2i(2, 1)
			if (x * 7 + y * 13) % 11 == 0:
				coord = Vector2i(2 + (x + y) % 4, 2)
			floor_layer.set_cell(Vector2i(x, y), 0, coord)
	for x in range(1, 13):
		wall_layer.set_cell(Vector2i(x, 0), 0, Vector2i(8, 5) if x % 7 == 0 else Vector2i(7, 4))
		wall_layer.set_cell(Vector2i(x, 8), 0, Vector2i(2, 6))
	for y in range(1, 8):
		wall_layer.set_cell(Vector2i(0, y), 0, Vector2i(4, 5))
		wall_layer.set_cell(Vector2i(13, y), 0, Vector2i(3, 5))
	wall_layer.set_cell(Vector2i(0, 0), 0, Vector2i(6, 4))
	wall_layer.set_cell(Vector2i(13, 0), 0, Vector2i(8, 4))
	wall_layer.set_cell(Vector2i(0, 8), 0, Vector2i(1, 6))
	wall_layer.set_cell(Vector2i(13, 8), 0, Vector2i(5, 6))
	props.set_cell(Vector2i(2, 2), 0, Vector2i(2, 0))
	props.set_cell(Vector2i(3, 2), 0, Vector2i(1, 0))
	props.set_cell(Vector2i(9, 5), 0, Vector2i(0, 1))
	props.set_cell(Vector2i(11, 6), 0, Vector2i(0, 0))
	for spec in [["LeftTorch", "torch", Vector2(72, 8)], ["RightTorch", "torch", Vector2(168, 8)], ["Slime", "slime_idle", Vector2(120, 88)], ["Goblin", "goblin_idle", Vector2(152, 56)], ["Knight", "knight_idle", Vector2(72, 88)], ["Chest", "chest_idle", Vector2(184, 40)]]:
		animated_sprite(scene, room, frames, spec[0], spec[1], spec[2])
	label(scene, "PreviewCaption", "ROOM PREVIEW  /  walls have 2D collision on physics layer 1", Vector2(64, 718), 16)
	# A separate shelf shows reusable animations without adding gameplay.
	for index in range(8):
		var animation: String = ["slime_run", "goblin_run", "knight_run", "fly", "torch", "spikes", "bomb", "chest_idle"][index]
		var column := index % 2
		var row := index / 2
		var position := Vector2(1060 + column * 120, 176 + row * 150)
		var sprite := animated_sprite(scene, scene, frames, "Sample_" + animation, animation, position)
		sprite.scale = Vector2(4, 4)
		label(scene, "Label_" + animation, animation.replace("_", " "), position + Vector2(-52, 42), 15)
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed, "res://scenes/2d/dungeon_tiles_preview.tscn")
	assert(result == OK, "Could not save preview scene")
	scene.free()


func attach(scene: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene


func layer(scene: Node, parent: Node, node_name: String, tileset: TileSet) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = node_name
	node.tile_set = tileset
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attach(scene, parent, node)
	return node


func animated_sprite(scene: Node, parent: Node, frames: SpriteFrames, node_name: String, animation: StringName, position: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = node_name
	sprite.sprite_frames = frames
	sprite.position = position
	sprite.animation = animation
	sprite.autoplay = animation
	attach(scene, parent, sprite)
	return sprite


func label(scene: Node, node_name: String, text: String, position: Vector2, size: int) -> void:
	var node := Label.new()
	node.name = node_name
	node.text = text
	node.position = position
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color("e4dfcb"))
	attach(scene, scene, node)
