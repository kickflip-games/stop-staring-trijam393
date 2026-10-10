extends Node3D
## Visual-only toy-board skin. Original StaticBody3D boundaries remain authoritative.
## Hide, disable or remove this node to restore the prototype environment.

const FLOOR := preload("res://assets/environment/kaykit/floor_foundation_allsides.gltf")
const WALL := preload("res://assets/environment/kaykit/wall.gltf")
const BLOCK := preload("res://assets/environment/support/beveled_block.tres")
const WALL_NAMES := ["TopWall", "BottomWall", "LeftWall", "RightWall"]

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_visibility()

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _original_light: Dictionary
var _original_fill: Dictionary
var _world_environment: WorldEnvironment
var _environment: Environment


func _ready() -> void:
	var arena := get_parent()
	_key_light = arena.get_parent().get_node("KeyLight")
	_fill_light = arena.get_parent().get_node("FillLight")
	for property_name in ["light_energy", "light_color", "shadow_enabled", "shadow_opacity", "shadow_blur", "directional_shadow_max_distance", "directional_shadow_mode", "shadow_bias", "shadow_normal_bias"]:
		_original_light[property_name] = _key_light.get(property_name)
	for property_name in ["light_energy", "light_color"]:
		_original_fill[property_name] = _fill_light.get(property_name)
	_floor_material = _tinted_material(FLOOR, Color(0.36, 0.40, 0.40))
	_wall_material = _tinted_material(WALL, Color(0.58, 0.65, 0.67))
	var left := _wall_inner_edge("LeftWall", Vector3.RIGHT)
	var right := _wall_inner_edge("RightWall", Vector3.LEFT)
	var bottom := _wall_inner_edge("BottomWall", Vector3.UP)
	var top := _wall_inner_edge("TopWall", Vector3.DOWN)
	_build_floor(left, right, bottom, top)
	_build_frame()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.045, 0.075, 0.085)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.63, 0.78, 0.80)
	_environment.ambient_light_energy = 0.30
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "BoardEnvironment"
	add_child(_world_environment)
	visibility_changed.connect(_apply_visibility)
	_apply_visibility()


func _build_floor(left: Vector3, right: Vector3, bottom: Vector3, top: Vector3) -> void:
	var floor_root := Node3D.new()
	floor_root.name = "KayKitFloor"
	add_child(floor_root)
	var tile_size := Vector2((right.x - left.x) / 4.0, (top.y - bottom.y) / 3.0)
	var variations := [1.0, 0.97, 1.02, 0.99, 1.01, 0.98, 1.0, 1.02, 0.99, 1.0, 0.98, 1.01]
	# Foundation tops form quiet rectangular slabs; retain their subtle stone palette.
	# Narrow seams and only 3% variation give scale without visual clutter.
	for row in range(3):
		for column in range(4):
			var material := _floor_material.duplicate() as StandardMaterial3D
			material.albedo_color *= variations[row * 4 + column]
			material.albedo_color.a = 1.0
			_add_piece(FLOOR, floor_root, "Slab_%d_%d" % [column, row],
				Vector3(left.x + (column + 0.5) * tile_size.x, bottom.y + (row + 0.5) * tile_size.y, -1.24),
				Vector3((tile_size.x - 0.035) / 2.2, 0.12, (tile_size.y - 0.035) / 2.2), 0.0, material)


func _build_frame() -> void:
	var arena := get_parent()
	var frame := Node3D.new()
	frame.name = "StoneFrame"
	add_child(frame)
	var foundation := _stone_material(Color(0.10, 0.17, 0.19))
	var lip := _stone_material(Color(0.23, 0.32, 0.35))
	var corners := _stone_material(Color(0.31, 0.40, 0.42))
	var inner_edge := _stone_material(Color(0.29, 0.38, 0.40))
	_make_block(frame, "BoardPlinth", Vector3(0, 0, -1.50), Vector3(20.8, 12.8, 0.60), foundation)
	for wall_name in WALL_NAMES:
		var wall: StaticBody3D = arena.get_node(wall_name)
		var shape: BoxShape3D = wall.get_node("Collision").shape
		var horizontal: bool = wall_name in ["TopWall", "BottomWall"]
		var length := shape.size.x if horizontal else shape.size.y
		var thickness := (shape.size.y if horizontal else shape.size.x) + 0.20
		var outward := wall.position.normalized()
		var count := 5 if horizontal else 3
		var segment_length := length / count
		var wall_root := Node3D.new()
		wall_root.name = "KayKit" + wall_name
		add_child(wall_root)
		for index in range(count):
			var offset := -length / 2.0 + (index + 0.5) * segment_length
			var origin := wall.position + outward * 0.10 + Vector3(offset if horizontal else 0.0, 0.0 if horizontal else offset, -1.10)
			_add_piece(WALL, wall_root, "Segment_%d" % index, origin,
				Vector3(segment_length / 4.0, 0.525, thickness),
				0.0 if horizontal else PI / 2.0, _wall_material)
		var outer_origin := wall.position + outward * 0.75
		outer_origin.z = 0.38
		_make_block(frame, wall_name + "OuterStep", outer_origin,
			Vector3(length + 0.30, 0.20, 0.48) if horizontal else Vector3(0.20, length + 1.20, 0.48), lip)
		var inner_origin := _wall_inner_edge(wall_name, -outward) + outward * 0.045
		inner_origin.z = 0.89
		_make_block(frame, wall_name + "InnerLip", inner_origin,
			Vector3(length, 0.09, 0.16) if horizontal else Vector3(0.09, length, 0.16), inner_edge)
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			_make_block(frame, "Corner_%s_%s" % [x_sign, y_sign],
				Vector3(x_sign * 9.70, y_sign * 5.70, 0.78), Vector3(1.40, 1.40, 0.60), corners)


func _wall_inner_edge(wall_name: String, inward: Vector3) -> Vector3:
	var wall: StaticBody3D = get_parent().get_node(wall_name)
	var shape: BoxShape3D = wall.get_node("Collision").shape
	return wall.position + inward * shape.size / 2.0


func _tinted_material(source: PackedScene, tint: Color) -> StandardMaterial3D:
	var reference := source.instantiate()
	var mesh: MeshInstance3D = reference.find_children("*", "MeshInstance3D", true, false)[0]
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	material.roughness = 0.94
	material.metallic_specular = 0.20
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	reference.free()
	return material


func _stone_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.90
	material.metallic_specular = 0.20
	return material


func _make_block(parent: Node3D, block_name: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	block.name = block_name
	block.mesh = BLOCK
	block.material_override = material
	parent.add_child(block)
	block.position = origin
	block.scale = size


func _add_piece(source: PackedScene, parent: Node3D, piece_name: String, origin: Vector3, piece_scale: Vector3, turn: float, material: Material) -> void:
	var piece := source.instantiate() as Node3D
	piece.name = piece_name
	parent.add_child(piece)
	piece.transform = Transform3D(Basis(Vector3.BACK, turn) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(piece_scale), origin)
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material


func _apply_visibility() -> void:
	var active := enabled and is_visible_in_tree()
	for child in get_children():
		if child is Node3D:
			child.visible = active
	_set_prototype_visible(not active)
	_world_environment.environment = _environment if active else null
	if active:
		_key_light.light_energy = 1.05
		_key_light.light_color = Color(1.0, 0.97, 0.89)
		_key_light.shadow_enabled = true
		_key_light.shadow_opacity = 0.35
		_key_light.shadow_blur = 1.8
		_key_light.directional_shadow_max_distance = 32.0
		_key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		_key_light.shadow_bias = 0.04
		_key_light.shadow_normal_bias = 0.15
		_fill_light.light_energy = 0.24
		_fill_light.light_color = Color(0.65, 0.83, 1.0)
	else:
		_restore_light()


func _set_prototype_visible(show_prototype: bool) -> void:
	var arena := get_parent()
	if not is_instance_valid(arena):
		return
	arena.get_node("Backdrop").visible = show_prototype
	for wall_name in WALL_NAMES:
		arena.get_node(wall_name).get_node("Mesh").visible = show_prototype


func _exit_tree() -> void:
	_set_prototype_visible(true)
	_restore_light()


func _restore_light() -> void:
	if is_instance_valid(_key_light):
		for property_name in _original_light:
			_key_light.set(property_name, _original_light[property_name])
	if is_instance_valid(_fill_light):
		for property_name in _original_fill:
			_fill_light.set(property_name, _original_fill[property_name])
