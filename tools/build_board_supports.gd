extends SceneTree

func _initialize() -> void:
	var block := SurfaceTool.new()
	block.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inset := 0.42
	# Six broad faces.
	for axis in range(3):
		for sign_value in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = sign_value * 0.5
				point[(axis+1)%3] = pair.x * inset
				point[(axis+2)%3] = pair.y * inset
				points.append(point)
			quad(block,points)
	# Twelve beveled edges.
	for axis in range(3):
		for a in [-1.0,1.0]:
			for b in [-1.0,1.0]:
				var points: Array[Vector3] = []
				for pair in [Vector2(-inset,0),Vector2(inset,0),Vector2(inset,1),Vector2(-inset,1)]:
					var point := Vector3.ZERO
					point[axis] = pair.x
					point[(axis+1)%3] = a * (0.5 if pair.y == 0 else inset)
					point[(axis+2)%3] = b * (inset if pair.y == 0 else 0.5)
					points.append(point)
				quad(block,points)
	# Eight clipped corners.
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				triangle(block,Vector3(x*0.5,y*inset,z*inset),Vector3(x*inset,y*0.5,z*inset),Vector3(x*inset,y*inset,z*0.5))
	var block_mesh := block.commit()
	print('block save: ',ResourceSaver.save(block_mesh,'res://assets/environment/support/beveled_block.tres'))
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := [Vector2(1.02,-0.26),Vector2(1.02,-0.09),Vector2(0.95,0),Vector2(0.81,0),Vector2(0.76,-0.07),Vector2(0.76,-0.26)]
	for side in range(24):
		var a := TAU*side/24.0
		var b := TAU*(side+1)/24.0
		for band in range(sections.size()):
			var next := (band+1)%sections.size()
			var points: Array[Vector3] = [polar(sections[band],a),polar(sections[band],b),polar(sections[next],b),polar(sections[next],a)]
			# Ring normals follow its cross-section rather than the hollow center.
			for index in [0,2,1,0,3,2]:
				ring.add_vertex(points[index])
	ring.generate_normals()
	print('ring save: ',ResourceSaver.save(ring.commit(),'res://assets/environment/support/eye_stone_collar.tres'))
	quit()

func polar(section: Vector2,angle: float) -> Vector3:
	return Vector3(cos(angle)*section.x,sin(angle)*section.x,section.y)

func quad(surface: SurfaceTool,points: Array[Vector3]) -> void:
	triangle(surface,points[0],points[1],points[2])
	triangle(surface,points[0],points[2],points[3])

func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	# Godot front faces use clockwise winding; choose the outward face.
	var normal := (b-a).cross(c-a).normalized()
	var center := (a+b+c)/3.0
	if normal.dot(center) < 0:
		normal = -normal
	else:
		var swap := b
		b = c
		c = swap
	for point in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(point)
