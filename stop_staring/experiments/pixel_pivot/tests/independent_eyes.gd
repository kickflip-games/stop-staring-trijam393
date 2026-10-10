extends SceneTree
## Independent real-time eye deadlines and the production swept-contact path.
const BASE := "res://experiments/pixel_pivot/"
const ContactFixture = preload(BASE + "tests/eye_contact_fixture.gd")
const CAPTURES := "res://../docs/independent_eyes/"
var checks := 0
var failures: Array[String] = []
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var clock: Node
var hud: Control
var reopened: Array[Node] = []
var watch_live_eye: Node2D
var live_reopen_position := Vector2.ZERO

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
	await process_frame

func hit(eye: Node2D) -> void:
	check(ContactFixture.sweep(player, eye), "Valid physical wall sweep closes " + str(eye.name))

func advance_real(seconds: float) -> void:
	arena._last_tick -= int(seconds * 1000000.0)
	arena.advance_time()

func on_reopened(eye: Node2D) -> void:
	reopened.append(eye)
	if eye == watch_live_eye:
		live_reopen_position = player.position
		check(player.position.distance_to(arena.spawn_position) > 2.0 and player.velocity.length() > 80.0, "Automatic reopen leaves the flying player away from spawn and moving")
		check(player.aiming and Engine.time_scale == 0.25 and player.input_enabled and not hud.get_node("Modal").visible, "Automatic reopen preserves live aiming, scale and control")

func all_open_and_reset(centered_pupils := true) -> bool:
	for eye in arena.eyes:
		if not eye.active or eye.closed_remaining != 0.0 or eye.closed_timer_active or eye._pop_age != -1.0 or eye._snap_age != -1.0 or eye.eyeball.scale != Vector2.ONE or not eye.eyeball.visible or not eye.pupil.visible or eye.closed_visual.visible or eye.closed_visual.rotation != 0.0 or eye.visual.position != -eye.facing_normal * 16.0 or (centered_pupils and eye.pupil.position != Vector2.ZERO):
			return false
	return true

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	presentation = load(BASE + "pixel_pivot.tscn").instantiate()
	root.add_child(presentation)
	current_scene = presentation
	await process_frame
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	clock = arena.get_node("Clock")
	hud = arena.get_node("HUD/Control")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await wait_real(0.15)
	arena.set_focused(true)
	player.set_physics_process(false)
	for eye in arena.eyes:
		eye.reopened.connect(on_reopened)
		check(eye.closed_duration == 60.0 and eye.reopen_warning_duration == 3.0, "Every eye defaults to 60s closed and a final 3s warning")
		check(eye.hit_radius == 15.0 and eye.visual.scale == Vector2(0.75, 0.75), "Hit radius is 25 percent larger than the unchanged visible socket radius")
	check(arena.closed_eyes == 0 and arena.remaining_eyes == 16 and not arena.started, "Initial arena has sixteen OPEN eyes and no run underway")
	check(hud.get_node("Remaining").text == "CLOSED 0 / 16" and not hud.get_node("Elapsed").visible, "HUD shows closed count; run time is hidden until launch")
	arena.set_process(false)
	test_staggered_deadlines()
	await test_real_time_and_pause()
	await test_live_reopen()
	test_generous_hits_and_normal_closed_bounce()
	test_boundary_and_rapid_reactions()
	await test_win_and_retry()
	if DisplayServer.get_name() != "headless":
		await capture_states()
	arena.retry()
	player.begin_aim(Vector2(180, 120))
	clock.hit_stop()
	presentation.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Scene exit restores normal scale without pending reopen callbacks")
	print("Independent eyes: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)

func test_staggered_deadlines() -> void:
	var first: Node2D = arena.eyes[0]
	var second: Node2D = arena.eyes[1]
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(132, 120))
	hit(first)
	check(first.closed_remaining == 60.0 and arena.closed_eyes == 1, "First hit starts only its own full timer")
	for eye in arena.eyes.slice(1):
		check(eye.active and eye.closed_remaining == 0.0, "Unhit eye has no countdown")
	advance_real(5.0)
	hit(second)
	var first_remaining: float = first.closed_remaining
	var second_remaining: float = second.closed_remaining
	check(first_remaining > 54.9 and first_remaining < 55.01 and second_remaining == 60.0, "Staggered hits have independent deadlines")
	check(not first.try_hit(first.wall, first.position, first.facing_normal, 288.0), "Closed hit cannot refresh its timer")
	check(first.closed_remaining <= first_remaining and second.closed_remaining <= second_remaining and arena.closed_eyes == 2, "Rejected hit neither refreshes nor scores a closed eye")
	clock.real_delta = 0.22
	first._process(0.0)
	second._process(0.0)
	advance_real(52.2)
	check(not first.active and first.closed_remaining > 2.7 and first.closed_remaining < 2.9, "Eye remains CLOSED after 57.2 real seconds, before its full-minute deadline")
	clock.real_delta = 0.01
	first._process(0.0)
	second._process(0.0)
	check(absf(first.closed_visual.rotation) > 0.01 and second.closed_visual.rotation == 0.0, "Only the eye in its final three seconds twitches")
	reopened.clear()
	player.velocity = Vector2(175, -90)
	player.begin_aim(Vector2(180, 120))
	var before_position: Vector2 = player.position
	var before_scale := Engine.time_scale
	var score_time: float = arena.elapsed
	advance_real(3.0)
	check(reopened == [first] and first.active and not second.active, "Only the first expired eye reopens")
	check(second.closed_remaining > 4.7 and second.closed_remaining < 4.9 and arena.closed_eyes == 1, "Other closed eye keeps its own remaining duration and count")
	check(player.position == before_position and player.velocity == Vector2(175, -90) and player.aiming and Engine.time_scale == before_scale, "Reopening mutates no position, velocity, aim or time scale")
	check(arena.elapsed > score_time + 2.99 and hud.get_node("Remaining").text == "CLOSED 1 / 16", "Run timer continues and HUD decrements only the closed count")
	check(first._pop_age == -1.0 and first._snap_age == 0.0 and is_equal_approx(first.eyeball.scale.y, 0.45) and first.closed_visual.rotation == 0.0 and first.visual.position == -first.facing_normal * 16.0, "Reopen cancels squash/twitch and begins a small snap animation")
	clock.real_delta = 0.12
	first._process(0.0)
	check(first._snap_age == -1.0 and first.eyeball.scale == Vector2.ONE and first.pupil.visible, "Snap settles and open tracking resumes")
	arena.retry()

func test_real_time_and_pause() -> void:
	arena.set_process(true)
	var eye: Node2D = arena.eyes[0]
	hit(eye)
	player.begin_aim(Vector2(180, 120))
	var before: float = eye.closed_remaining
	var start := Time.get_ticks_usec()
	await wait_real(0.12)
	var wall_time := (Time.get_ticks_usec() - start) / 1000000.0
	check(absf((before - eye.closed_remaining) - wall_time) < 0.035 and before - eye.closed_remaining >= 0.11, "Independent timer uses real time at 0.25x aim speed")
	clock.hit_stop_duration = 0.12
	clock.hit_stop()
	before = eye.closed_remaining
	await wait_real(0.08)
	check(Engine.time_scale == 0.0 and before - eye.closed_remaining >= 0.07, "Independent timer continues during zero-scale hit-stop")
	clock.hit_stop_duration = 0.04
	await wait_real(0.06)
	check(Engine.time_scale == 0.25, "Hit-stop restores the existing aim state")
	arena.toggle_pause()
	before = eye.closed_remaining
	await wait_real(0.08)
	check(eye.closed_remaining == before and arena.suspended, "Explicit pause freezes closed timers")
	var other: Node2D = arena.eyes[1]
	check(not other.try_hit(other.wall, other.position, other.facing_normal, 288.0), "Paused contact cannot close an eye")
	arena.resume()
	check(absf(before - eye.closed_remaining) < 0.01, "Resume excludes paused wall time")
	arena.set_focused(false)
	before = eye.closed_remaining
	await wait_real(0.08)
	check(eye.closed_remaining == before and Engine.time_scale == 1.0, "Focus loss excludes inactive time and cancels slow motion")
	arena.set_focused(true)
	check(absf(before - eye.closed_remaining) < 0.01, "Focus return excludes the inactive interval")
	before = eye.closed_remaining
	advance_real(0.2)
	check(before - eye.closed_remaining >= 0.2, "Long frames consume the full timer interval")
	arena.retry()
	arena.set_process(false)

func test_live_reopen() -> void:
	var first: Node2D = arena.eyes[0]
	var second: Node2D = arena.eyes[1]
	first.closed_duration = 0.4
	second.closed_duration = 0.8
	arena.set_process(true)
	hit(first)
	player.begin_aim(Vector2(180, 120))
	await wait_real(0.06)
	hit(second)
	player.position = arena.spawn_position
	player.velocity = Vector2(180, 80)
	player.set_physics_process(true)
	watch_live_eye = first
	reopened.clear()
	var deadline := Time.get_ticks_usec() + 2000000
	while not first.active and Time.get_ticks_usec() < deadline:
		await process_frame
	watch_live_eye = null
	check(reopened == [first] and first.active and not second.active and arena.closed_eyes == 1, "Live-physics expiry reopens one eye while the later eye remains closed")
	await wait_real(0.025)
	check(player.position.distance_to(live_reopen_position) > 0.1, "Flight continues immediately after individual reopen")
	player.set_physics_process(false)
	hit(first)
	check(not first.active and first.closed_remaining == 0.4 and not second.active and second.closed_remaining < 0.6, "Immediately rehitting the reopened eye starts only its fresh timer")
	first.closed_duration = 60.0
	second.closed_duration = 60.0
	print("Live loop: hit A -> aim 0.25x -> hit B later -> A alone reopens while flying -> hit A again -> B keeps its deadline")
	arena.retry()
	arena.set_process(false)

func test_generous_hits_and_normal_closed_bounce() -> void:
	var eye: Node2D = arena.eyes[1]
	var tangent: Vector2 = eye.facing_normal.orthogonal()
	check(not eye.try_hit(eye.wall, eye.position + tangent * 15.1, eye.facing_normal, 288.0), "Outside expanded radius still rejects a miss")
	check(not eye.try_hit(eye.wall, eye.position, eye.facing_normal, 47.0), "Weak impact still rejects")
	check(not eye.try_hit(eye.wall, eye.position, -eye.facing_normal, 288.0), "Wrong side still rejects")
	for offset in [-14.75, 14.75]:
		player.position = eye.position + eye.facing_normal * 40.0 + tangent * offset
		player.velocity = -eye.facing_normal * player.max_launch_speed
		for step in range(16):
			player.advance(1.0 / 60.0)
			if not eye.active:
				break
		check(not eye.active and arena.closed_eyes == 1, "Real off-center sweep beyond the old 14px radius now counts reliably")
		arena.retry()
	hit(eye)
	clock.reset()
	var effects: Node2D = arena.get_node("Effects")
	effects.reset()
	player._impact_amount = 0.0
	player.position = eye.position + eye.facing_normal * 12.0
	player.velocity = -eye.facing_normal * player.max_launch_speed
	var remaining: float = eye.closed_remaining
	player.advance(0.05)
	check(not player.eye_hit_this_contact and player.velocity.dot(eye.facing_normal) > 0.0, "Closed eye receives the normal physical bounce")
	check(eye.closed_remaining <= remaining and eye.closed_remaining > remaining - 0.02 and arena.closed_eyes == 1, "Closed bounce neither scores nor refreshes")
	check(effects.get_node("Wall").playing and not effects.get_node("Pop").playing and effects.rings.is_empty() and player._impact_amount < 0.5 and Engine.time_scale == 1.0, "Closed bounce has only ordinary wall feedback, with no eye hit-stop")
	arena.retry()

func test_boundary_and_rapid_reactions() -> void:
	var expired: Node2D = arena.eyes[0]
	hit(expired)
	advance_real(5.0)
	for eye in arena.eyes.slice(1, arena.eyes.size() - 1):
		eye.try_hit(eye.wall, eye.position, eye.facing_normal, 288.0)
	check(arena.remaining_eyes == 1, "Boundary fixture leaves one open eye")
	expired.closed_remaining = 0.000001
	arena._last_tick -= 10000
	var last: Node2D = arena.eyes.back()
	last.try_hit(last.wall, last.position, last.facing_normal, 288.0)
	check(not arena.cleared and expired.active and not last.active and arena.remaining_eyes == 1, "An older expired eye is settled before a final hit; no false simultaneous win")
	var later_remaining: float = last.closed_remaining
	check(expired.try_hit(expired.wall, expired.position, expired.facing_normal, 288.0) and arena.cleared and last.closed_remaining == 0.0, "Closing the reopened eye while all others remain closed wins and stops every timer")
	check(later_remaining > 59.0, "Last eye had its own fresh duration until completion")
	arena.retry()
	for index in range(20):
		expired.try_hit(expired.wall, expired.position, expired.facing_normal, 288.0)
		clock.real_delta = 0.08
		expired._process(0.0)
		check(expired.eyeball.scale != Vector2.ONE, "Fixture enters the existing hit squash")
		advance_real(60.1)
		check(expired.active and expired._pop_age == -1.0 and expired._snap_age == 0.0 and not expired.closed_visual.visible, "Expiry cancels an in-progress squash cleanly")
		expired.try_hit(expired.wall, expired.position, expired.facing_normal, 288.0)
		check(not expired.active and expired._snap_age == -1.0 and expired.closed_remaining == 60.0, "Rehit during snap cancels reopening animation and starts one timer")
		arena.retry()
		check(all_open_and_reset(), "Retry cancels every timer and both visual ages")

func test_win_and_retry() -> void:
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(132, 120))
	for eye in arena.eyes:
		hit(eye)
	check(arena.cleared and arena.closed_eyes == 16 and not player.input_enabled and not hud.get_node("Modal").visible, "All sixteen CLOSED simultaneously win and block launches immediately")
	var score_time: float = arena.elapsed
	for eye in arena.eyes:
		check(not eye.closed_timer_active and eye.closed_remaining == 0.0, "Win stops every independent timer")
		eye.reopen()
	advance_real(60.0)
	await wait_real(0.6)
	check(arena.elapsed == score_time and arena.closed_eyes == 16 and hud.get_node("Modal").visible, "Win freezes score and eyes and reveals the existing clear panel")
	for eye in arena.eyes:
		check(not eye.active and eye.closed_visual.visible, "Completed eye cannot reopen")
	player.begin_aim(Vector2(180, 120))
	check(not player.aiming, "Win prevents new launches")
	# Native focus may change while the clear panel is resolving.
	arena.set_focused(true)
	var retry := InputEventKey.new()
	retry.keycode = KEY_R
	retry.pressed = true
	root.push_input(retry)
	check(all_open_and_reset() and not arena.cleared and arena.elapsed == 0.0 and arena.closed_eyes == 0, "R resets all eyes, individual timers and run time")
	check(player.position == arena.spawn_position and player.velocity == Vector2.ZERO and player.input_enabled and Engine.time_scale == 1.0, "R retains normal player/clock reset behavior")
	hit(arena.eyes[0])
	player.begin_aim(Vector2(180, 120))
	clock.hit_stop()
	root.push_input(retry)
	await wait_real(0.08)
	check(all_open_and_reset(false) and Engine.time_scale == 1.0 and not hud.get_node("Modal").visible, "Retry during aim/hit-stop has no stale reopen or win animation")

func capture(name: String) -> void:
	arena.set_focused(true)
	hud.update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES + name + ".png")) == OK, "Saved native " + name)

func capture_states() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	arena.retry()
	await capture("open")
	arena.set_focused(true)
	player.begin_aim(Vector2(180, 120))
	player.release_aim(Vector2(132, 120))
	for eye in arena.eyes.slice(0, 8):
		hit(eye)
	await wait_real(0.22)
	arena.advance_time()
	player.position = arena.spawn_position
	arena.get_node("CameraRig/Camera2D").snap_to(player.position)
	await capture("eight_closed")
	arena.eyes[0].closed_remaining = 2.75
	clock.real_delta = 0.016
	arena.eyes[0]._process(0.0)
	await capture("one_warning")
	arena.eyes[0].closed_remaining = 0.001
	advance_real(0.01)
	await capture("one_reopens")
	check(arena.closed_eyes == 7, "Capture reopens only one of eight closed eyes")
	arena.retry()
