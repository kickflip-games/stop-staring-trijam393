extends Node3D
## Small built-in 3D fragments and an additive camera offset. No camera drift.

@export_range(8, 20, 1) var eye_particle_count: int = 14
@export_range(0.1, 0.4, 0.01) var particle_lifetime: float = 0.24
@export_range(0.0, 0.15, 0.005) var eye_camera_kick: float = 0.075
@export_range(0.0, 0.03, 0.001) var wall_camera_kick: float = 0.008
@export_range(0.05, 0.25, 0.01) var camera_duration: float = 0.14
@export_range(1, 12, 1) var max_active_bursts: int = 6
var _bursts: Array[Dictionary] = []
var _kick := Vector2.ZERO
var _kick_remaining := 0.0
var _clock_usec: int
@onready var _camera: Camera3D = get_node("../Camera")
@onready var _player: Node3D = get_node("../Player")
var _base_offset := Vector2.ZERO

func _ready() -> void:
	_clock_usec = Time.get_ticks_usec()
	_base_offset = Vector2(_camera.h_offset, _camera.v_offset)

func eye_hit(contact: Vector3, normal: Vector3, speed: float) -> void:
	var strength := lerpf(0.55, 1.0, clampf((speed - 3.0) / 15.0, 0.0, 1.0))
	_kick_camera(normal, eye_camera_kick * strength)
	if _bursts.size() >= max_active_bursts:
		return
	var cloud := MultiMeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("fff1cf")
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = eye_particle_count
	cloud.multimesh = multi
	add_child(cloud)
	cloud.global_position = contact + normal * 0.15
	cloud.global_position.z = 1.3
	var velocities: Array[Vector3] = []
	for index in range(eye_particle_count):
		var angle := TAU * index / eye_particle_count + randf_range(-0.12, 0.12)
		velocities.append(Vector3(cos(angle), sin(angle), randf_range(-0.2, 0.2)) * randf_range(2.0, 4.2) * strength)
		multi.set_instance_transform(index, Transform3D.IDENTITY)
	_bursts.append({"node": cloud, "age": 0.0, "velocities": velocities})

func wall_hit(_contact: Vector3, normal: Vector3, speed: float) -> void:
	# An eye kick from this same wall contact must remain the stronger response.
	if _kick_remaining > 0.0:
		return
	_kick_camera(normal, wall_camera_kick * clampf(speed / 18.0, 0.0, 1.0))

func _kick_camera(normal: Vector3, amount: float) -> void:
	if _player.aiming:
		return
	_kick = (Vector2(normal.x, normal.y) * amount).limit_length(eye_camera_kick)
	_kick_remaining = camera_duration

func clear_kick() -> void:
	_kick_remaining = 0.0
	_camera.h_offset = _base_offset.x
	_camera.v_offset = _base_offset.y

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := minf(float(now - _clock_usec) / 1000000.0, 0.1)
	_clock_usec = now
	if _player.aiming:
		clear_kick()
	else:
		_kick_remaining = maxf(0.0, _kick_remaining - real_delta)
		var life := _kick_remaining / maxf(camera_duration, 0.001)
		var offset := _kick * life * life * cos((1.0 - life) * PI * 2.0)
		_camera.h_offset = _base_offset.x + offset.x
		_camera.v_offset = _base_offset.y + offset.y
	for index in range(_bursts.size() - 1, -1, -1):
		var burst := _bursts[index]
		burst.age += real_delta
		var cloud: MultiMeshInstance3D = burst.node
		if burst.age >= particle_lifetime:
			cloud.queue_free()
			_bursts.remove_at(index)
			continue
		var size: float = 1.0 - burst.age / particle_lifetime
		for particle in range(cloud.multimesh.instance_count):
			cloud.multimesh.set_instance_transform(particle, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), burst.velocities[particle] * burst.age))

func _exit_tree() -> void:
	if is_instance_valid(_camera):
		clear_kick()
