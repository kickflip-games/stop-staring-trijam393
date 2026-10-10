extends Node2D
## Feedback appears only on player actions. All ages share the real clock.
const SCREEN_SHADER := preload("res://experiments/pixel_pivot/juice_screen.gdshader")
const WHOOSH := preload("res://audio/juice/launch.wav")
const SNAP := preload("res://audio/juice/snap.wav")
@export var launch_trail_duration := 0.22
@export var win_silence_delay := 0.12
var trails: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var launch_age := -1.0
var win_age := -1.0
var aim_amount := 0.0
var _trail_accumulator := 0.0
var _screen_flash := 0.0
var _wall_cooldown := 0.0
var _silenced := false
var _screen_material: ShaderMaterial
var _cue_players: Array[AudioStreamPlayer] = []
@onready var arena := get_parent()

func _ready() -> void:
	z_index = 6
	_make_cue("Launch", WHOOSH, -13.0)
	_make_cue("Snap", SNAP, -14.0)
	_cue_players.append_array([$Aim, $Wall, $Pop])
	$Wall.volume_db = -21.0
	$Pop.volume_db = -6.0
	# Room-only screen treatment; the pixel HUD remains sharp and unchanged.
	var layer := CanvasLayer.new()
	layer.name = "RoomFeedback"
	layer.layer = 5
	add_child(layer)
	var screen := ColorRect.new()
	screen.name = "Screen"
	screen.position = Vector2(0, 32)
	screen.size = get_viewport_rect().size - Vector2(0, 32)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = SCREEN_SHADER
	screen.material = _screen_material
	layer.add_child(screen)

func _make_cue(cue_name: String, stream: AudioStream, volume: float) -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = cue_name
	audio.stream = stream
	audio.volume_db = volume
	add_child(audio)
	_cue_players.append(audio)

func _process(_delta: float) -> void:
	var dt: float = arena.get_node("Clock").real_delta
	var player: CharacterBody2D = arena.get_node("Slime")
	_wall_cooldown = maxf(0.0, _wall_cooldown - dt)
	_screen_flash = move_toward(_screen_flash, 0.0, dt * 2.4)
	aim_amount = move_toward(aim_amount, 1.0 if player.aiming else 0.0, dt * 9.0)
	_screen_material.set_shader_parameter("aim_amount", aim_amount)
	_screen_material.set_shader_parameter("impact_flash", _screen_flash)
	_screen_material.set_shader_parameter("slime_pixel", arena.get_canvas_transform() * player.position)
	_screen_material.set_shader_parameter("aim_direction", player.drag_vector.normalized())
	if launch_age >= 0.0:
		launch_age += dt
		if launch_age >= launch_trail_duration:
			launch_age = -1.0
	_trail_accumulator += dt
	if player.velocity.length() > 24.0 and _trail_accumulator >= 0.012 and not arena.cleared and not arena.suspended and not arena.get_node("Clock").is_hit_stopping():
		trails.append({"position": player.position.round(), "direction": player.velocity.normalized(), "age": 0.0, "bright": launch_age >= 0.0, "life": 0.14})
		_trail_accumulator = 0.0
	for trail in trails:
		trail.age += dt
	trails = trails.filter(func(t): return t.age < t.life)
	for particle in particles:
		particle.age += dt
		particle.position += particle.velocity * dt
		particle.velocity *= exp(-5.0 * dt)
	particles = particles.filter(func(p): return p.age < p.life)
	for ring in rings:
		ring.age += dt
	rings = rings.filter(func(r): return r.age < r.life)
	for flash in flashes:
		flash.age += dt
	flashes = flashes.filter(func(f): return f.age < f.life)
	if win_age >= 0.0:
		win_age += dt
		if win_age >= win_silence_delay and not _silenced:
			stop_sounds()
			_silenced = true
	queue_redraw()

func _draw() -> void:
	for trail in trails:
		var fade: float = 1.0 - trail.age / trail.life
		var color := Color("cffff0") if trail.bright else Color("77c86a")
		color.a = fade * (0.7 if trail.bright else 0.18)
		draw_line(trail.position, (trail.position - trail.direction * 6.0).round(), color, 3.0 if trail.bright else 2.0)
	for particle in particles:
		var color: Color = particle.color
		color.a = 1.0 - particle.age / particle.life
		draw_rect(Rect2(particle.position.round(), Vector2.ONE * particle.size), color)
	for ring in rings:
		var t: float = ring.age / ring.life
		var color: Color = ring.color
		color.a = (1.0 - t) * 0.8
		var points := PackedVector2Array()
		for index in range(17):
			points.append((ring.position + Vector2.from_angle(TAU * index / 16.0) * lerpf(3.0, ring.radius, t)).round())
		draw_polyline(points, color, 1.0)
	for flash in flashes:
		var t: float = flash.age / flash.life
		var radius: float = lerpf(7.0, 2.0, t)
		var color := Color(1, 1, 1, 1.0 - t)
		draw_rect(Rect2(flash.position - Vector2(radius, 1), Vector2(radius * 2, 2)), color)
		draw_rect(Rect2(flash.position - Vector2(1, radius), Vector2(2, radius * 2)), color)

func launch_at(point: Vector2, velocity: Vector2) -> void:
	launch_age = 0.0
	aim_amount = 0.0
	_screen_material.set_shader_parameter("aim_amount", 0.0)
	var direction := velocity.normalized()
	trails.append({"position": point.round(), "direction": direction, "age": 0.0, "bright": true, "life": 0.14})
	$Launch.pitch_scale = lerpf(0.94, 1.08, velocity.length() / 288.0)
	$Launch.play()
	arena.get_node("CameraRig/Camera2D").kick(-direction, 1.0, 0.12)
	queue_redraw()

func pop_at(point: Vector2, normal: Vector2, final_hit := false) -> void:
	for index in range(20 if final_hit else 16):
		var direction := Vector2.from_angle(TAU * index / (20.0 if final_hit else 16.0))
		particles.append({"position": point, "velocity": direction * (60.0 + (index % 3) * 25.0) + normal * 24.0, "age": 0.0, "life": 0.32, "size": 2.0, "color": Color("fff1cf") if index % 3 == 0 else Color("ee586b")})
	rings.append({"position": point.round(), "age": 0.0, "life": 0.2, "radius": 36.0 if final_hit else 28.0, "color": Color("fff1cf")})
	flashes.append({"position": point.round(), "age": 0.0, "life": 0.055})
	_screen_flash = 0.14 if final_hit else 0.07
	$Pop.pitch_scale = randf_range(0.96, 1.04)
	$Pop.play()
	$Snap.pitch_scale = 0.75 if final_hit else 1.15
	$Snap.volume_db = -13.0 if final_hit else -19.0
	$Snap.play()
	arena.get_node("CameraRig/Camera2D").kick(normal, 3.0 if final_hit else 2.0, 0.22)
	queue_redraw()

func wall_at(point: Vector2, normal: Vector2, speed: float) -> void:
	if speed < 35.0 or _wall_cooldown > 0.0:
		return
	_wall_cooldown = 0.05
	for index in range(4):
		particles.append({"position": point, "velocity": normal * (12.0 + index * 4.0) + normal.orthogonal() * (index - 1.5) * 10.0, "age": 0.0, "life": 0.16, "size": 1.0, "color": Color("afa7a1")})
	wall_sound()
	arena.get_node("CameraRig/Camera2D").kick(normal, 1.0, 0.1)
	queue_redraw()

func aim_sound(value: bool, tension := 0.0) -> void:
	$Aim.volume_db = lerpf(-27.0, -20.0, clampf(tension, 0.0, 1.0))
	$Aim.pitch_scale = lerpf(0.85, 1.12, clampf(tension, 0.0, 1.0))
	if value and not $Aim.playing:
		$Aim.play()
	elif not value:
		$Aim.stop()

func wall_sound() -> void:
	$Wall.pitch_scale = randf_range(0.94, 1.06)
	$Wall.play()

func finish() -> void:
	win_age = 0.0
	_silenced = false

func set_suspended(value: bool) -> void:
	for audio in _cue_players:
		audio.stream_paused = value

func stop_sounds() -> void:
	for audio in _cue_players:
		audio.stop()

func reset() -> void:
	trails.clear()
	particles.clear()
	rings.clear()
	flashes.clear()
	_trail_accumulator = 0.0
	_wall_cooldown = 0.0
	launch_age = -1.0
	win_age = -1.0
	_silenced = false
	aim_amount = 0.0
	_screen_flash = 0.0
	_screen_material.set_shader_parameter("aim_amount", 0.0)
	_screen_material.set_shader_parameter("impact_flash", 0.0)
	stop_sounds()
	set_suspended(arena.suspended)
	queue_redraw()
