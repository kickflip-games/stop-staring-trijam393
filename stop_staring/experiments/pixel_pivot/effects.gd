extends Node2D
## Lightweight native-pixel trails and bursts; age using the shared real clock.
var trails: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var _trail_accumulator := 0.0
@onready var arena := get_parent()

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	var player: CharacterBody2D = arena.get_node("Slime")
	_trail_accumulator += dt
	if player.velocity.length() > 24.0 and _trail_accumulator >= 0.03 and not arena.cleared:
		trails.append({"position": player.position.round(), "age": 0.0})
		_trail_accumulator = 0.0
	for trail in trails:
		trail.age += dt
	trails = trails.filter(func(t): return t.age < 0.25)
	for particle in particles:
		particle.age += dt
		particle.position += particle.velocity * dt
		particle.velocity *= exp(-5.0 * dt)
	particles = particles.filter(func(p): return p.age < 0.35)
	queue_redraw()

func _draw() -> void:
	for trail in trails:
		draw_rect(Rect2(trail.position - Vector2(4, 2), Vector2(8, 4)), Color(0.3, 0.7, 0.25, (1.0 - trail.age / 0.25) * 0.3))
	for particle in particles:
		var color: Color = particle.color
		color.a = 1.0 - particle.age / 0.35
		draw_rect(Rect2(particle.position.round(), Vector2(2, 2)), color)

func pop_at(point: Vector2, normal: Vector2) -> void:
	for index in range(14):
		var angle := TAU * index / 14.0
		var direction := Vector2.from_angle(angle)
		particles.append({"position": point, "velocity": direction * (35.0 + (index % 3) * 15.0) + normal * 30.0, "age": 0.0, "color": Color("fff1cf") if index % 3 == 0 else Color("bd3036")})
	$Pop.pitch_scale = randf_range(0.94, 1.06)
	$Pop.play()

func aim_sound(value: bool) -> void:
	if value and not $Aim.playing:
		$Aim.play()
	elif not value:
		$Aim.stop()

func wall_sound() -> void:
	$Wall.pitch_scale = randf_range(0.94, 1.06)
	$Wall.play()

func reset() -> void:
	trails.clear()
	particles.clear()
	_trail_accumulator = 0.0
	$Aim.stop()
	$Wall.stop()
	$Pop.stop()
	queue_redraw()
