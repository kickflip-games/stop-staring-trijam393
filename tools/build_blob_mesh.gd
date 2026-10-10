extends SceneTree
## Rebuild the small, smooth jelly body; this mesh is visual only.
## Run: godot --headless --path stop_staring --script ../tools/build_blob_mesh.gd

func _initialize() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 32
	sphere.rings = 20
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		var point := vertices[index]
		var height := point.y / sphere.radius
		# Broad lower cheeks, a soft crown and a very slight lean. No rig.
		point.x *= 1.06 - 0.09 * height - 0.035 * height * height
		point.x += 0.022 * (1.0 - height * height) * (height + 0.4)
		point.y *= 0.97
		point.z *= 0.97 - 0.025 * height
		vertices[index] = point
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var reshaped := ArrayMesh.new()
	reshaped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(reshaped, 0)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.resource_name = "Jelly body (visual only)"
	print("Jelly mesh: ", ResourceSaver.save(mesh, "res://art/blob/jelly_body.tres"),
		"; triangles: ", arrays[Mesh.ARRAY_INDEX].size() / 3)
	quit()
