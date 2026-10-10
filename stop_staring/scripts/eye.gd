extends Node3D
## Local -Y points into the arena; rotate around Z for other walls.
## Uses swept wall contacts so fast launches cannot tunnel through a trigger.
signal popped(eye: Node3D)
signal hit_confirmed(contact: Vector3, normal: Vector3, speed: float)

@export var player_path: NodePath
@export var wall_path: NodePath
@export_range(0.1, 2.0, 0.05) var hit_radius: float = 0.7
@export_range(0.0, 20.0, 0.5) var min_impact_speed: float = 3.0
@export_range(0.0, 0.35, 0.01) var tracking_limit: float = 0.3

@export_range(1.0, 1.6, 0.05) var pop_bulge: float = 1.3
@export_range(0.02, 0.08, 0.005) var pop_bulge_duration: float = 0.035
@export_range(0.04, 0.15, 0.005) var pop_retract_duration: float = 0.075
@export_range(0.0, 0.2, 0.01) var pop_pitch_variation: float = 0.1

var active: bool = true
var _pupil_offset := Vector2.ZERO
var _pupil_velocity := Vector2.ZERO
@onready var _player: Node3D = get_node_or_null(player_path) as Node3D
@onready var _wall: Node3D = get_node_or_null(wall_path) as Node3D
@onready var _pupil: Node3D = $Eyeball/Pupil


func _process(delta: float) -> void:
	if not active or not is_instance_valid(_player):
		return
	var local_player := to_local(_player.global_position)
	var target := (Vector2(local_player.x, local_player.y) * 0.08).limit_length(tracking_limit)
	var remaining := minf(delta, 0.1)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 120.0)
		_pupil_velocity += (target - _pupil_offset) * 100.0 * step
		_pupil_velocity *= exp(-12.0 * step)
		_pupil_offset = (_pupil_offset + _pupil_velocity * step).limit_length(tracking_limit)
		remaining -= step
	_pupil.position = Vector3(_pupil_offset.x, _pupil_offset.y, 0.02)


func react_to_bounce(_contact: Vector3, normal: Vector3, speed: float) -> void:
	var local_normal := global_basis.inverse() * normal
	_pupil_velocity += Vector2(local_normal.x, local_normal.y) * minf(speed * 0.12, 2.0)


func try_hit(wall: Node3D, contact: Vector3, normal: Vector3, speed: float) -> bool:
	if not active or not is_instance_valid(_wall) or wall != _wall or speed < min_impact_speed:
		return false
	var local_normal := global_basis.inverse() * normal
	var local_contact := to_local(contact)
	if local_normal.dot(Vector3.DOWN) < 0.9 or absf(local_contact.x) > hit_radius or absf(local_contact.y) > 0.1:
		return false
	active = false
	$PopAudio.pitch_scale = randf_range(1.0 - pop_pitch_variation, 1.0 + pop_pitch_variation)
	$PopAudio.play()
	hit_confirmed.emit(contact, normal, speed)
	popped.emit(self)
	var tween := create_tween().set_ignore_time_scale(true)
	# Hold the enlarged eye on the impact frame, then retract in real time.
	$Eyeball.scale = Vector3(pop_bulge, pop_bulge, 1.0)
	tween.tween_interval(pop_bulge_duration)
	tween.tween_property($Eyeball, "scale", Vector3(1.5, 0.05, 0.1), pop_retract_duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($Eyeball, "scale", Vector3.ONE * 0.01, pop_retract_duration * 0.45)
	tween.tween_callback($Eyeball.hide)
	return true
