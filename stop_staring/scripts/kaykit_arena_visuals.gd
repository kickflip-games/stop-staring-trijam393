extends Node3D
## Removable art skin. The sibling StaticBody3D walls remain the only boundaries.
## Hide this node, disable the skin, or remove it to restore the original graybox.

const FLOOR := preload("res://assets/environment/kaykit/floor_tile_large.gltf")
const WALL := preload("res://assets/environment/kaykit/wall.gltf")
const WALL_NAMES := ["TopWall", "BottomWall", "LeftWall", "RightWall"]

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_visibility()

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _key_light: DirectionalLight3D
var _original_shadows: bool


func _ready() -> void:
	var arena := get_parent()
	_key_light = arena.get_parent().get_node("KeyLight")
	_original_shadows = _key_light.shadow_enabled
	_floor_material = _tinted_material(FLOOR, Color(0.30, 0.37, 0.41))
	_wall_material = _tinted_material(WALL, Color(0.64, 0.70, 0.76))
	var left := _wall_inner_edge("LeftWall", Vector3.RIGHT)
	var right := _wall_inner_edge("RightWall", Vector3.LEFT)
	var bottom := _wall_inner_edge("BottomWall", Vector3.UP)
	var top := _wall_inner_edge("TopWall", Vector3.DOWN)
	var tile_size := Vector2((right.x - left.x) / 5.0, (top.y - bottom.y) / 3.0)
	var floor_root := Node3D.new()
	floor_root.name = "KayKitFloor"
	add_child(floor_root)
	# KayKit ground is XZ with Y up; the game board is XY with Z toward camera.
	# Its highest floor vertex lands at the original backdrop surface, Z=-1.
	for row in range(3):
		for column in range(5):
			_add_piece(FLOOR, floor_root, "Tile_%d_%d" % [column, row],
				Vector3(left.x + (column + 0.5) * tile_size.x, bottom.y + (row + 0.5) * tile_size.y, -1.05),
				Vector3(tile_size.x / 4.0, 1.0, tile_size.y / 4.0), 0.0, _floor_material)
	for wall_name in WALL_NAMES:
		var wall: StaticBody3D = arena.get_node(wall_name)
		var shape: BoxShape3D = wall.get_node("Collision").shape
		var horizontal: bool = wall_name in ["TopWall", "BottomWall"]
		var length := shape.size.x if horizontal else shape.size.y
		var thickness := shape.size.y if horizontal else shape.size.x
		var count := 5 if horizontal else 3
		var segment_length := length / count
		var wall_root := Node3D.new()
		wall_root.name = "KayKit" + wall_name
		add_child(wall_root)
		for index in range(count):
			var offset := -length / 2.0 + (index + 0.5) * segment_length
			var position_on_wall := wall.position + Vector3(offset if horizontal else 0.0, 0.0 if horizontal else offset, -shape.size.z / 2.0)
			_add_piece(WALL, wall_root, "Segment_%d" % index, position_on_wall,
				Vector3(segment_length / 4.0, shape.size.z / 4.0, thickness),
				0.0 if horizontal else PI / 2.0, _wall_material)
	visibility_changed.connect(_apply_visibility)
	_apply_visibility()


func _wall_inner_edge(wall_name: String, inward: Vector3) -> Vector3:
	var wall: StaticBody3D = get_parent().get_node(wall_name)
	var shape: BoxShape3D = wall.get_node("Collision").shape
	return wall.position + inward * shape.size / 2.0


func _tinted_material(source: PackedScene, tint: Color) -> StandardMaterial3D:
	var reference := source.instantiate()
	var mesh: MeshInstance3D = reference.find_children("*", "MeshInstance3D", true, false)[0]
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	reference.free()
	return material


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
		child.visible = active
	_set_prototype_visible(not active)
	_key_light.shadow_enabled = true if active else _original_shadows


func _set_prototype_visible(show_prototype: bool) -> void:
	var arena := get_parent()
	if not is_instance_valid(arena):
		return
	arena.get_node("Backdrop").visible = show_prototype
	for wall_name in WALL_NAMES:
		arena.get_node(wall_name).get_node("Mesh").visible = show_prototype


func _exit_tree() -> void:
	_set_prototype_visible(true)
	if is_instance_valid(_key_light):
		_key_light.shadow_enabled = _original_shadows
