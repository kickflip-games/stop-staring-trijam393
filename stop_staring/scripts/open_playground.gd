extends "res://scripts/level.gd"
## A separate experiment built before child ready, reusing the small-room actors.

@export var playable_bounds := Rect2(-22.5, -12.5, 45.0, 25.0)
@export var camera_bounds := Rect2(-23.3, -13.3, 46.6, 26.6)

const EYE := preload("res://scenes/eye.tscn")
const ISLANDS := [
	["NorthWest", Vector2(-11, 7), Vector2(5, 3)],
	["NorthEast", Vector2(10, 7), Vector2(4, 4)],
	["CenterBank", Vector2(5, -0.5), Vector2(6, 4)],
	["SouthWest", Vector2(-11, -7), Vector2(5, 3)],
	["SouthEast", Vector2(10, -7), Vector2(5, 3)],
]
const TARGETS := [
	["TopWall", Vector2(-19, 12.5), 0.0],
	["NorthWest", Vector2(-13.5, 7), -PI / 2.0],
	["TopWall", Vector2(19, 12.5), 0.0],
	["RightWall", Vector2(22.5, 8), -PI / 2.0],
	["NorthEast", Vector2(12, 7), PI / 2.0],
	["BottomWall", Vector2(-19, -12.5), PI],
	["CenterBank", Vector2(5, 1.5), PI],
	["BottomWall", Vector2(17, -12.5), PI],
	["LeftWall", Vector2(-22.5, 5), PI / 2.0],
	["CenterBank", Vector2(5, -2.5), 0.0],
	["NorthWest", Vector2(-11, 5.5), 0.0],
	["NorthEast", Vector2(10, 5), 0.0],
	["CenterBank", Vector2(2, -0.5), -PI / 2.0],
	["SouthWest", Vector2(-11, -5.5), PI],
	["SouthEast", Vector2(10, -5.5), PI],
]


func _enter_tree() -> void:
	# Remove only this instance's small-room visual and default eye.
	for path in ["Eye", "Arena/KayKitVisuals"]:
		var obsolete := get_node(path)
		obsolete.get_parent().remove_child(obsolete)
		obsolete.free()
	var width := playable_bounds.size.x
	var height := playable_bounds.size.y
	_resize_wall("TopWall", Vector2(0, height / 2.0 + 0.5), Vector2(width + 2, 1))
	_resize_wall("BottomWall", Vector2(0, -height / 2.0 - 0.5), Vector2(width + 2, 1))
	_resize_wall("LeftWall", Vector2(-width / 2.0 - 0.5, 0), Vector2(1, height))
	_resize_wall("RightWall", Vector2(width / 2.0 + 0.5, 0), Vector2(1, height))
	for island in ISLANDS:
		var wall := StaticBody3D.new()
		wall.name = island[0]
		wall.add_to_group("walls")
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		wall.add_child(collision)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		wall.add_child(mesh)
		$Arena.add_child(wall)
		_resize_wall(island[0], island[1], island[2])
	_build_floor()
	for index in range(TARGETS.size()):
		var target: Array = TARGETS[index]
		var eye := EYE.instantiate()
		eye.name = "Eye%02d" % (index + 1)
		eye.position = Vector3(target[1].x, target[1].y, 1.06)
		eye.rotation.z = target[2]
		eye.player_path = NodePath("../Player")
		eye.wall_path = NodePath("../Arena/" + target[0])
		add_child(eye)
	$Player.position = Vector3(-1, 0, 0)


func _resize_wall(wall_name: String, center: Vector2, extent: Vector2) -> void:
	var wall: StaticBody3D = $Arena.get_node(wall_name)
	wall.position = Vector3(center.x, center.y, 0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(extent.x, extent.y, 2.0)
	wall.get_node("Collision").shape = shape
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh.material = _material(Color("617780"))
	wall.get_node("Mesh").mesh = mesh
	# A quiet inset face gives the existing eye collars a compatible stone backing.
	var face := MeshInstance3D.new()
	face.name = "StoneFace"
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(maxf(extent.x - 0.18, 0.1), maxf(extent.y - 0.18, 0.1), 0.03)
	face_mesh.material = _material(Color("485d63"))
	face.mesh = face_mesh
	face.position.z = 1.02
	wall.add_child(face)


func _build_floor() -> void:
	$Arena/Backdrop.visible = false
	var floor_root := Node3D.new()
	floor_root.name = "PlaygroundFloor"
	$Arena.add_child(floor_root)
	var tile_size := Vector2(playable_bounds.size.x / 10.0, playable_bounds.size.y / 6.0)
	for row in range(6):
		for column in range(10):
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(tile_size.x - 0.025, tile_size.y - 0.025, 0.2)
			var tint := Color("293d40") * (1.0 + float((column + row * 3) % 4) * 0.012)
			tint.a = 1.0
			mesh.material = _material(tint)
			tile.mesh = mesh
			tile.position = Vector3(playable_bounds.position.x + (column + 0.5) * tile_size.x,
				playable_bounds.position.y + (row + 0.5) * tile_size.y, -1.1)
			floor_root.add_child(tile)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("102126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a1c7cc")
	environment.ambient_light_energy = 0.35
	environment_node.environment = environment
	add_child(environment_node)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.metallic_specular = 0.2
	return material
