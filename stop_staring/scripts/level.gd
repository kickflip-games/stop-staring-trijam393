extends Node3D

signal remaining_eyes_changed(remaining: int)
signal all_eyes_popped

var remaining_eyes: int = 0
var _eyes: Array[Node] = []


func _ready() -> void:
	_eyes = find_children("*", "", true, false).filter(func(node: Node) -> bool: return node.has_signal("popped") and node.has_method("try_hit"))
	for eye in _eyes:
		if eye.active:
			remaining_eyes += 1
		eye.popped.connect(_on_eye_popped)
		eye.hit_confirmed.connect(_on_eye_hit)
		$Player.wall_bounced.connect(eye.react_to_bounce)
	$Player.wall_contact.connect(_on_wall_contact)
	$Player.wall_bounced.connect($ImpactFeedback.wall_hit)
	_update_counter()


func _on_wall_contact(wall: Node3D, contact: Vector3, normal: Vector3, speed: float) -> void:
	for eye in _eyes:
		eye.try_hit(wall, contact, normal, speed)


func _on_eye_popped(_eye: Node3D) -> void:
	remaining_eyes -= 1
	_update_counter()
	remaining_eyes_changed.emit(remaining_eyes)
	if remaining_eyes == 0:
		all_eyes_popped.emit()


func _update_counter() -> void:
	$HUD/EyeCounter.text = "EYES LEFT: %d" % remaining_eyes if remaining_eyes > 0 else "EYE POPPED!"


func _on_eye_hit(contact: Vector3, normal: Vector3, speed: float) -> void:
	$TimeEffects.hit_stop()
	$Player/VisualPivot.eye_impact(normal, speed)
	$ImpactFeedback.eye_hit(contact, normal, speed)
