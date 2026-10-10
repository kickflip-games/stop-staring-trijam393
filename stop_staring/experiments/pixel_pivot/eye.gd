extends Node2D
## The origin is the contacted surface. The face stays upright on every side.
signal popped(eye: Node2D)

@export var wall_path: NodePath
@export var facing_normal := Vector2.DOWN
@export var hit_radius := 14.0
@export var min_impact_speed := 48.0
@export var tracking_limit := 3.0
var active := true
var _pop_age := -1.0
var _pupil_offset := Vector2.ZERO
@onready var wall: StaticBody2D = get_node(wall_path)
@onready var arena := get_parent().get_parent()
@onready var visual: Node2D = $Visual
@onready var eyeball: Node2D = $Visual/Eyeball
@onready var pupil: Sprite2D = $Visual/Eyeball/Pupil

func _ready() -> void:
	visual.position = -facing_normal * 16.0

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	if active:
		var target: Vector2 = (arena.get_node("Slime").global_position - visual.global_position).normalized() * tracking_limit
		_pupil_offset = _pupil_offset.lerp(target, 1.0 - exp(-14.0 * dt)).limit_length(tracking_limit)
		pupil.position = _pupil_offset.round()
	elif _pop_age >= 0.0:
		_pop_age += dt
		if _pop_age < 0.04:
			eyeball.scale = Vector2.ONE * 1.2
		elif _pop_age < 0.14:
			var t := (_pop_age - 0.04) / 0.1
			eyeball.scale = Vector2(1.2 - t * 0.3, maxf(0.02, 1.2 * (1.0 - t)))
		else:
			eyeball.hide()
			_pop_age = -1.0

func try_hit(contact_wall: Node2D, point: Vector2, normal: Vector2, speed: float) -> bool:
	if not active or contact_wall != wall or speed < min_impact_speed or normal.dot(facing_normal) < 0.95:
		return false
	var offset := point - global_position
	var tangent := facing_normal.orthogonal()
	if absf(offset.dot(tangent)) > hit_radius or absf(offset.dot(facing_normal)) > 0.15:
		return false
	active = false
	_pop_age = 0.0
	popped.emit(self)
	return true

func reset_eye() -> void:
	active = true
	_pop_age = -1.0
	_pupil_offset = Vector2.ZERO
	pupil.position = Vector2.ZERO
	eyeball.scale = Vector2.ONE
	eyeball.show()
