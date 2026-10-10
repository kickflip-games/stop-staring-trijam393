extends Node3D
## Only this visual pivot deforms. The body and its sphere stay untouched.
## Local X is the deformation axis; XY travel rotates it around Z.

@export_group("Speed stretch")
@export_range(0.0, 30.0, 0.5) var stretch_start_speed: float = 3.0
@export_range(1.0, 40.0, 0.5) var stretch_full_speed: float = 18.0
@export_range(0.0, 0.5, 0.01) var max_stretch_amount: float = 0.22
@export_range(0.0, 0.3, 0.01) var perpendicular_squash_amount: float = 0.10
@export_range(1.0, 40.0, 0.5) var smoothing_speed: float = 18.0

@export_group("Wall impact")
@export_range(0.0, 0.7, 0.01) var impact_squash_amount: float = 0.55
@export_range(0.0, 0.6, 0.01) var impact_expansion_amount: float = 0.42
@export_range(0.05, 0.12, 0.005) var impact_duration: float = 0.10

@export_group("Eye impact")
@export_range(1.0, 1.7, 0.05) var eye_impact_multiplier: float = 1.45

@export_group("Aim and launch")
@export_range(0.0, 0.8, 0.01) var aim_stretch_amount: float = 0.58
@export_range(0.0, 0.2, 0.01) var aim_pullback_distance: float = 0.16
@export_range(0.0, 0.3, 0.01) var launch_squash_amount: float = 0.14
@export_range(0.02, 0.1, 0.005) var launch_duration: float = 0.04

@export_group("Idle breathing")
@export_range(0.0, 0.05, 0.001) var idle_wobble_amount: float = 0.018
@export_range(0.1, 2.0, 0.05) var idle_wobble_frequency: float = 0.65

@export_group("Motion trail")
@export_range(0.0, 30.0, 0.5) var trail_start_speed: float = 6.0
@export_range(1.0, 40.0, 0.5) var trail_full_speed: float = 18.0
@export_range(0.0, 0.5, 0.01) var trail_max_opacity: float = 0.25

var _impact_strength: float = 1.0
var _eye_impact: bool = false
var _impact_remaining: float = 0.0
var _impact_angle: float = 0.0
var _impact_offset: Vector3 = Vector3.ZERO
var _launch_remaining: float = 0.0
var _launch_angle: float = 0.0
var _idle_phase: float = 0.0

enum MouthState { HAPPY, EXCITED, IMPACT }
const MOUTHS: Array[Texture2D] = [
	preload("res://art/blob/mouth_happy.svg"),
	preload("res://art/blob/mouth_excited.svg"),
	preload("res://art/blob/mouth_impact.svg"),
]
var mouth_state: MouthState = MouthState.HAPPY

@onready var _player: CharacterBody3D = get_parent()
@onready var _trail: CPUParticles3D = get_node("../MotionTrail")
@onready var _radius: float = (get_node("../Collision").shape as SphereShape3D).radius
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _face: Node3D = $FacePivot
@onready var _mouth: Sprite3D = $FacePivot/Mouth
@onready var _shadow: MeshInstance3D = get_node("../ContactShadow")


func _ready() -> void:
	# wall_contact includes every incoming contact, even several in one step.
	_player.wall_contact.connect(_on_wall_contact)
	_player.launched.connect(_on_launched)
	_update_face()


func _process(delta: float) -> void:
	# Input-driven anticipation and recovery use real time, including during hit-stop.
	if Engine.time_scale > 0.0:
		delta /= Engine.time_scale
	else:
		delta = get_node("../../TimeEffects").real_delta
	var planar_velocity := Vector2(_player.velocity.x, _player.velocity.y)
	var speed := planar_velocity.length()
	var weight := smoothstep(stretch_start_speed, maxf(stretch_full_speed, stretch_start_speed + 0.01), speed)
	var target_scale := Vector3(1.0 + max_stretch_amount * weight,
		1.0 - perpendicular_squash_amount * weight, 1.0 - perpendicular_squash_amount * weight)
	var target_angle := rotation.z if speed < 0.01 else planar_velocity.angle()
	var target_position := Vector3.ZERO
	var launch_velocity: Vector3 = _player.get_launch_velocity() if _player.aiming else Vector3.ZERO
	if not launch_velocity.is_zero_approx():
		var strength := clampf(_player.drag_vector.length() / maxf(_player.max_drag_distance, 0.01), 0.0, 1.0)
		var anticipation := aim_stretch_amount * lerpf(0.35, 1.0, strength)
		target_angle = atan2(launch_velocity.y, launch_velocity.x)
		target_scale = Vector3(1.0 + anticipation, 1.0 - anticipation * 0.5, 1.0 - anticipation * 0.5)
		target_position = -launch_velocity.normalized() * aim_pullback_distance * strength
	var blend := 1.0 - exp(-smoothing_speed * delta)
	if _impact_remaining > 0.0:
		_impact_remaining = maxf(0.0, _impact_remaining - delta)
		# Keep the peak for the first 20 ms, then recover over the pulse.
		var pulse := pow(minf(1.0, _impact_remaining / maxf(impact_duration - 0.02, 0.001)), 2.0)
		target_scale = target_scale.lerp(_impact_scale(), pulse)
		target_angle = _impact_angle
		# The contact sets the peak immediately; recover without a lagging tween.
		scale = target_scale
		position = target_position.lerp(_impact_offset, pulse)
	elif _launch_remaining > 0.0:
		_launch_remaining = maxf(0.0, _launch_remaining - delta)
		var pulse := pow(_launch_remaining / launch_duration, 2.0)
		target_scale = target_scale.lerp(_launch_scale(), pulse)
		target_angle = _launch_angle
		scale = target_scale
		position = position.lerp(target_position, blend)
	else:
		scale = scale.lerp(target_scale, blend)
		position = position.lerp(target_position, blend)
	# An ellipsoid's axis is identical after 180 degrees. Pick its nearest
	# equivalent orientation so a ricochet never spins it needlessly around.
	rotation.z += wrapf(target_angle - rotation.z, -PI / 2.0, PI / 2.0) * blend
	_update_idle(delta, speed)
	_update_face()
	_update_shadow()
	_update_trail(planar_velocity, speed)


func _on_wall_contact(_wall: Node3D, _contact: Vector3, normal: Vector3, _speed: float) -> void:
	if _eye_impact and _impact_remaining > 0.0:
		return
	_eye_impact = false
	_impact_strength = 1.0
	_impact_angle = atan2(normal.y, normal.x)
	_impact_remaining = impact_duration
	_launch_remaining = 0.0
	# Keep the compressed mesh touching the wall while the sphere stays put.
	_impact_offset = -normal * _radius * impact_squash_amount
	rotation.z = _impact_angle
	scale = _impact_scale()
	position = _impact_offset
	_update_face()


func _on_launched(launch_velocity: Vector3) -> void:
	_launch_angle = atan2(launch_velocity.y, launch_velocity.x)
	_launch_remaining = launch_duration
	_impact_remaining = 0.0
	_eye_impact = false
	rotation.z = _launch_angle
	scale = _launch_scale()
	position = Vector3.ZERO
	_update_face()


func _update_idle(delta: float, speed: float) -> void:
	_idle_phase = fmod(_idle_phase + TAU * idle_wobble_frequency * delta, TAU)
	var resting: bool = not _player.aiming and _impact_remaining <= 0.0 and _launch_remaining <= 0.0
	var weight := 1.0 - smoothstep(0.15, stretch_start_speed, speed) if resting else 0.0
	var breath := sin(_idle_phase) * idle_wobble_amount * weight
	# Breathing belongs to the mesh, so the deformation pivot recovers to ONE.
	_mesh.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5)


func _update_face() -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.y).length()
	mouth_state = MouthState.IMPACT if _impact_remaining > 0.0 else (
		MouthState.EXCITED if _player.aiming or _launch_remaining > 0.0 or speed >= stretch_start_speed else MouthState.HAPPY)
	_mouth.texture = MOUTHS[mouth_state]
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_basis := camera.global_basis.orthonormalized()
	var body_basis := _mesh.global_basis
	var width := (body_basis.transposed() * camera_basis.x).length()
	var height := (body_basis.transposed() * camera_basis.y).length()
	var depth := _radius * (body_basis.transposed() * camera_basis.z).length()
	# Cancel inherited rotation/nonuniform scale. The expression stays upright
	# at the front of the jelly, with just a little squash for its silhouette.
	var face_scale := Vector3(clampf(width, 0.78, 1.23), clampf(height, 0.72, 1.12), 1.0)
	var face_position := global_position + camera_basis.z * (depth + 0.018)
	face_position -= camera_basis.y * (0.045 * face_scale.y)
	_face.global_transform = Transform3D(camera_basis.scaled_local(face_scale), face_position)


func _update_shadow() -> void:
	# A soft projected contact patch follows the visual footprint on the board.
	var footprint := Vector2(
		(_mesh.global_basis.transposed() * Vector3.RIGHT).length(),
		(_mesh.global_basis.transposed() * Vector3.UP).length())
	_shadow.scale = Vector3(clampf(footprint.x, 0.7, 1.5), clampf(footprint.y, 0.7, 1.5), 1.0)
	_shadow.position.x = position.x + 0.10
	_shadow.position.y = position.y - 0.10


func _impact_scale() -> Vector3:
	return Vector3(1.0 - minf(0.7, impact_squash_amount * _impact_strength), 1.0 + minf(0.55, impact_expansion_amount * _impact_strength), 1.0 + minf(0.55, impact_expansion_amount * _impact_strength))


func _launch_scale() -> Vector3:
	return Vector3(1.0 - launch_squash_amount, 1.0 + launch_squash_amount * 0.5, 1.0 + launch_squash_amount * 0.5)


func _update_trail(planar_velocity: Vector2, speed: float) -> void:
	var strength := smoothstep(trail_start_speed, maxf(trail_full_speed, trail_start_speed + 0.01), speed)
	_trail.emitting = strength > 0.01
	_trail.color.a = trail_max_opacity * strength
	if speed > 0.01:
		# World-space particles remain behind after the player moves/bounces.
		_trail.position = -Vector3(planar_velocity.x, planar_velocity.y, 0.0).normalized() * 0.28


func eye_impact(normal: Vector3, speed: float) -> void:
	_eye_impact = true
	_impact_strength = lerpf(1.1, eye_impact_multiplier, clampf((speed - 3.0) / 15.0, 0.0, 1.0))
	_impact_angle = atan2(normal.y, normal.x)
	_impact_remaining = impact_duration
	_launch_remaining = 0.0
	_impact_offset = -normal * _radius * minf(0.7, impact_squash_amount * _impact_strength)
	rotation.z = _impact_angle
	scale = _impact_scale()
	position = _impact_offset
	_update_face()
