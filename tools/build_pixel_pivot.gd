extends SceneTree
## Rebuild the game's editable scenes from layout.json.
const BASE := "res://experiments/pixel_pivot/"
const TILES := "res://assets/2d/dungeon_crawler/dungeon_tileset.tres"
const FRAMES := "res://assets/2d/dungeon_crawler/dungeon_sprites.tres"
const VIEW_SIZE := Vector2i(448, 336)
var tileset: TileSet
var frames: SpriteFrames

func _initialize() -> void:
	tileset = load(TILES)
	frames = load(FRAMES)
	if OS.get_cmdline_user_args().has("--arena-only"):
		build_arena()
		build_presentation()
		print("Arena scenes saved.")
		quit()
		return
	build_slime()
	build_eye()
	build_arena()
	build_presentation()
	print("Pixel pivot scenes saved.")
	quit()

func attach(root_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root_node

func save_scene(scene: Node, filename: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, BASE + filename) == OK)
	scene.free()

func make_layer(scene: Node, parent: Node, node_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.tile_set = tileset
	layer.collision_enabled = false
	layer.navigation_enabled = false
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attach(scene, parent, layer)
	return layer

func fill_floor(layer: TileMapLayer, dimensions: Vector2i) -> void:
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(3, 1))

func paint_wall_cells(walls: TileMapLayer, edges: TileMapLayer, tops: TileMapLayer, cells: Dictionary) -> void:
	# Paint the union, so adjacent alcove rectangles have no internal art seam.
	for point: Vector2i in cells:
		var north := not cells.has(point + Vector2i.UP)
		var south := not cells.has(point + Vector2i.DOWN)
		var west := not cells.has(point + Vector2i.LEFT)
		var east := not cells.has(point + Vector2i.RIGHT)
		walls.set_cell(point, 0, Vector2i(7, 4))
		if tops != null and not south:
			tops.set_cell(point, 0, Vector2i(3, 1))
		var edge := Vector2i(-1, -1)
		if north: edge = Vector2i(2, 7)
		elif south: edge = Vector2i(2, 6)
		elif west: edge = Vector2i(4, 5)
		elif east: edge = Vector2i(3, 5)
		if north and west: edge = Vector2i(1, 7)
		elif north and east: edge = Vector2i(5, 7)
		elif south and west: edge = Vector2i(1, 6)
		elif south and east: edge = Vector2i(5, 6)
		elif not north and not west and not cells.has(point + Vector2i(-1, -1)):
			edge = Vector2i(3, 4)
		elif not north and not east and not cells.has(point + Vector2i(1, -1)):
			edge = Vector2i(4, 4)
		elif not south and not west and not cells.has(point + Vector2i(-1, 1)):
			edge = Vector2i(3, 6)
		elif not south and not east and not cells.has(point + Vector2i(1, 1)):
			edge = Vector2i(4, 6)
		if edge.x >= 0:
			edges.set_cell(point, 0, edge)

func build_slime() -> void:
	var body := CharacterBody2D.new()
	body.name = "Slime"
	body.set_script(load(BASE + "slime.gd"))
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	body.z_index = 5
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	collision.shape = circle
	attach(body, body, collision)
	var visual := Node2D.new()
	visual.name = "Visual"
	attach(body, body, visual)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.animation = "slime_idle"
	sprite.autoplay = "slime_idle"
	sprite.position = Vector2(0, -4)
	sprite.scale = Vector2(1.5, 1.5)
	sprite.self_modulate = Color(1.12, 1.35, 1.12)
	attach(body, visual, sprite)
	save_scene(body, "slime.tscn")

func build_eye() -> void:
	var eye := Node2D.new()
	eye.name = "WallEye"
	eye.set_script(load(BASE + "eye.gd"))
	eye.z_index = 4
	eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visual := Node2D.new()
	visual.name = "Visual"
	visual.scale = Vector2(0.75, 0.75)
	attach(eye, eye, visual)
	var socket := Sprite2D.new()
	socket.name = "Socket"
	socket.texture = load("res://assets/2d/eyes/empty_socket.tres")
	socket.scale = Vector2(32.0 / 300.0, 32.0 / 304.0)
	socket.self_modulate = Color(0.8, 0.9, 1.0)
	attach(eye, visual, socket)
	var orb := Node2D.new()
	orb.name = "Eyeball"
	attach(eye, visual, orb)
	var white := Sprite2D.new()
	white.name = "White"
	white.texture = load(BASE + "art/eyeball.svg")
	attach(eye, orb, white)
	var pupil := Sprite2D.new()
	pupil.name = "Pupil"
	pupil.texture = load(BASE + "art/pupil.svg")
	attach(eye, orb, pupil)
	var closed_visual := Sprite2D.new()
	closed_visual.name = "Closed"
	var eye_frames: SpriteFrames = load("res://assets/2d/eyes/eye_sprites.tres")
	closed_visual.texture = eye_frames.get_frame_texture("closed", 0)
	closed_visual.scale = socket.scale
	closed_visual.visible = false
	attach(eye, visual, closed_visual)
	save_scene(eye, "wall_eye.tscn")

func build_arena() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "layout.json"))
	var dimensions := Vector2i(layout.size[0], layout.size[1])
	var border := int(layout.border)
	var room_top := int(layout.room_top)
	var arena := Node2D.new()
	arena.name = "PixelArena"
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.set_script(load(BASE + "arena.gd"))
	arena.spawn_position = Vector2(layout.spawn[0], layout.spawn[1]) * 16
	arena.arena_bounds = Rect2(Vector2.ZERO, Vector2(dimensions * 16))
	var floor_layer := make_layer(arena, arena, "Floor")
	# Tint the supplied brown floor to the reference's dark slate palette.
	floor_layer.modulate = Color(0.38, 0.66, 1.0)
	var walls := make_layer(arena, arena, "WallArt")
	walls.z_index = 1
	var tops := make_layer(arena, arena, "WallTops")
	tops.z_index = 2
	tops.modulate = Color(0.65, 1.05, 1.35)
	var edges := make_layer(arena, arena, "WallEdges")
	edges.z_index = 3
	fill_floor(floor_layer, dimensions)
	for y in range(room_top):
		for x in range(dimensions.x):
			floor_layer.erase_cell(Vector2i(x, y))
	var physics := Node2D.new()
	physics.name = "WallPhysics"
	attach(arena, arena, physics)
	var rectangles := [
		{"name": "TopWall", "rect": [0, room_top, dimensions.x, border]},
		{"name": "BottomWall", "rect": [0, dimensions.y - border, dimensions.x, border]},
		{"name": "LeftWall", "rect": [0, room_top + border, border, dimensions.y - room_top - border * 2]},
		{"name": "RightWall", "rect": [dimensions.x - border, room_top + border, border, dimensions.y - room_top - border * 2]}
	]
	rectangles.append_array(layout.islands)
	rectangles.append_array(layout.get("wall_lips", []))
	var wall_cells := {}
	var shadows := Node2D.new()
	shadows.name = "WallShadows"
	attach(arena, arena, shadows)
	for entry: Dictionary in rectangles:
		var values: Array = entry.rect
		var rect := Rect2i(values[0], values[1], values[2], values[3])
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				wall_cells[Vector2i(x, y)] = true
		var shadow := Polygon2D.new()
		shadow.name = entry.name + "Shadow"
		var origin := Vector2(rect.position * 16) + Vector2(2, 4)
		var end := origin + Vector2(rect.size * 16)
		shadow.polygon = PackedVector2Array([origin, Vector2(end.x, origin.y), end, Vector2(origin.x, end.y)])
		shadow.color = Color(0.012, 0.018, 0.03, 0.65)
		attach(arena, shadows, shadow)
		var body := StaticBody2D.new()
		body.name = entry.name
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = Vector2(rect.position * 16) + Vector2(rect.size * 16) * 0.5
		attach(arena, physics, body)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(rect.size * 16)
		collision.shape = shape
		attach(arena, body, collision)
	paint_wall_cells(walls, edges, tops, wall_cells)
	# Visible floor exists only in the play area; there is no floor outside the walls.
	for point in floor_layer.get_used_cells():
		if wall_cells.has(point) or point.y < room_top + border:
			floor_layer.erase_cell(point)
	var variants := [Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 3), Vector2i(2, 2)]
	var variant_index := 0
	for values: Array in layout.floor_variation:
		var point := Vector2i(values[0], values[1])
		if floor_layer.get_cell_source_id(point) >= 0:
			floor_layer.set_cell(point, 0, variants[variant_index % variants.size()])
			variant_index += 1
	# A few deliberate cracked faces, away from the socket mounts.
	for point in [Vector2i(3, 3), Vector2i(24, 3), Vector2i(12, 19), Vector2i(21, 18)]:
		if wall_cells.has(point):
			walls.set_cell(point, 0, Vector2i(8, 5))
	var insets := make_layer(arena, arena, "WallInsets")
	insets.modulate = Color(0.1, 0.17, 0.28)
	insets.z_index = 2
	for values: Array in layout.insets:
		for y in range(values[1], values[1] + values[3]):
			for x in range(values[0], values[0] + values[2]):
				walls.erase_cell(Vector2i(x, y))
				edges.erase_cell(Vector2i(x, y))
				insets.set_cell(Vector2i(x, y), 0, Vector2i(2, 1))
	build_props(arena, layout)
	var clock := Node.new()
	clock.name = "Clock"
	clock.set_script(load(BASE + "clock.gd"))
	attach(arena, arena, clock)
	var eyes := Node2D.new()
	eyes.name = "Eyes"
	attach(arena, arena, eyes)
	for index in range(layout.eyes.size()):
		var data: Dictionary = layout.eyes[index]
		var eye: Node2D = load(BASE + "wall_eye.tscn").instantiate()
		eye.name = "Eye%02d" % (index + 1)
		eye.position = Vector2(data.position[0], data.position[1]) * 16
		eye.facing_normal = Vector2(data.normal[0], data.normal[1])
		eye.wall_path = NodePath("../../WallPhysics/" + data.wall)
		attach(arena, eyes, eye)
	var slime: Node2D = load(BASE + "slime.tscn").instantiate()
	slime.position = arena.spawn_position
	attach(arena, arena, slime)
	var rig := Node2D.new()
	rig.name = "CameraRig"
	attach(arena, arena, rig)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.set_script(load(BASE + "camera.gd"))
	camera.position = arena.spawn_position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = dimensions.x * 16
	camera.limit_bottom = dimensions.y * 16
	attach(arena, rig, camera)
	var effects := Node2D.new()
	effects.name = "Effects"
	effects.z_index = 3
	effects.set_script(load(BASE + "effects.gd"))
	attach(arena, arena, effects)
	for spec in [["Aim", "res://audio/aim/stretch.wav", -18.0], ["Wall", "res://audio/wall_hits/impactSoft_heavy_002.ogg", -18.0], ["Pop", "res://audio/eye/squish_sfx.mp3", -10.0]]:
		var audio := AudioStreamPlayer.new()
		audio.name = spec[0]
		audio.stream = load(spec[1])
		audio.volume_db = spec[2]
		attach(arena, effects, audio)
	build_hud(arena)
	save_scene(arena, "pixel_arena.tscn")

func atlas_sprite(arena: Node, parent: Node, name_string: String, coord: Vector2i, point: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = name_string
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/2d/dungeon_crawler/full_tilemap.png")
	texture.region = Rect2(Vector2(coord * 16), Vector2(16, 16))
	texture.filter_clip = true
	sprite.texture = texture
	sprite.position = point
	attach(arena, parent, sprite)

func build_props(arena: Node, layout: Dictionary) -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 3
	attach(arena, arena, props)
	for index in range(layout.barrels.size()):
		var point: Array = layout.barrels[index]
		var barrel := StaticBody2D.new()
		barrel.name = "Barrel%02d" % index
		barrel.position = Vector2(point[0], point[1]) * 16
		barrel.collision_layer = 1
		barrel.collision_mask = 2
		attach(arena, props, barrel)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 5.0
		collision.shape = circle
		attach(arena, barrel, collision)
		atlas_sprite(arena, barrel, "Sprite", Vector2i(1, 0), Vector2.ZERO)
	for index in range(layout.get("crates", []).size()):
		var point: Array = layout.crates[index]
		var crate := StaticBody2D.new()
		crate.name = "Crate%02d" % index
		crate.position = Vector2(point[0], point[1]) * 16
		crate.collision_layer = 1
		crate.collision_mask = 2
		attach(arena, props, crate)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12, 12)
		collision.shape = shape
		attach(arena, crate, collision)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(BASE + "art/crate.svg")
		attach(arena, crate, sprite)
	for index in range(layout.chests.size()):
		var point: Array = layout.chests[index]
		var sprite := Sprite2D.new()
		sprite.name = "Chest%02d" % index
		sprite.texture = frames.get_frame_texture("chest_idle", 0)
		sprite.position = Vector2(point[0], point[1]) * 16
		attach(arena, props, sprite)
	for index in range(layout.gates.size()):
		var point: Array = layout.gates[index]
		atlas_sprite(arena, props, "Gate%d" % index, Vector2i(7, 5), Vector2(point[0], point[1]) * 16)
	for index in range(layout.banners.size()):
		var point: Array = layout.banners[index]
		atlas_sprite(arena, props, "Banner%d" % index, Vector2i(4, 0), Vector2(point[0], point[1]) * 16)
	for index in range(layout.torches.size()):
		var point: Array = layout.torches[index]
		var torch := AnimatedSprite2D.new()
		torch.name = "Torch%d" % index
		torch.sprite_frames = frames
		torch.animation = "torch"
		torch.autoplay = "torch"
		torch.position = Vector2(point[0], point[1]) * 16
		attach(arena, props, torch)

func build_hud(arena: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	attach(arena, arena, layer)
	# Keep the editable UI scene authoritative when the arena is regenerated.
	var control: Control = load("res://ui/retro_hud.tscn").instantiate()
	attach(arena, layer, control)

func build_presentation() -> void:
	var presentation := Control.new()
	presentation.name = "PixelPivot"
	presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.set_script(load(BASE + "presentation.gd"))
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("090d17")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach(presentation, presentation, backdrop)
	var container := SubViewportContainer.new()
	container.name = "View"
	container.size = Vector2(VIEW_SIZE)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attach(presentation, presentation, container)
	var viewport := SubViewport.new()
	viewport.name = "World"
	viewport.size = VIEW_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	attach(presentation, container, viewport)
	var arena: Node = load(BASE + "pixel_arena.tscn").instantiate()
	attach(presentation, viewport, arena)
	save_scene(presentation, "pixel_pivot.tscn")
