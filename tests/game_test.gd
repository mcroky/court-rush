extends SceneTree

var game
var failures = 0

func _init() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in range(count):
		game._physics_process(1.0 / 60.0)

func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check(value: bool, message: String) -> void:
	if not value:
		push_error("FAIL: " + message)
		failures += 1
		return
	print("PASS: " + message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("practice")
	ticks(2)
	key(KEY_D, true)
	ticks(5)
	key(KEY_D, false)
	ticks(1)
	check(game.players[0].action == "fake" and game.attempts == 0, "short tap is a fake, not a shot")
	ticks(30)
	var held_position = game.players[0].position
	var held_phase = game.players[0].dribble_phase
	var pivot_foot = game.players[0].feet_world[0]
	key(KEY_RIGHT, true)
	key(KEY_A, true)
	ticks(40)
	key(KEY_RIGHT, false)
	key(KEY_A, false)
	check(game.players[0].dribble_ended and game.players[0].action == "idle" and game.players[0].position == held_position, "pump fake ends dribble and prevents movement or crossover")
	check(game.players[0].dribble_phase == held_phase and game.players[0].feet_world[0] == pivot_foot, "held ball stops bounce cycle and preserves pivot foot")
	check(game.ball.position.distance_to((game.players[0].palm_position(0)+game.players[0].palm_position(1))*.5) < .001, "held ball stays between actual skinned palms")
	key(KEY_D, true)
	ticks(56)
	key(KEY_D, false)
	check(game.phase == "flight" and game.attempts == 1, "held D releases exactly one shot")
	game.flight_made = true
	ticks(100)
	check(game.makes == 1 and game.scores[0] == 3, "made three-point shot scores once")
	game.register_score()
	check(game.makes == 1 and game.scores[0] == 3, "duplicate score event is ignored")
	game.start_mode("practice")
	check(not game.players[0].dribble_ended, "new possession restores dribble eligibility")
	game.set_drill("layup")
	ticks(2)
	key(KEY_D, true)
	ticks(38)
	check(game.phase == "takeoff" and game.finish_kind == "layup" and game.ball_owner == 0, "near basket uses layup and keeps ball through takeoff")
	ticks(21)
	key(KEY_D, false)
	check(game.phase == "flight" and game.flight_points == 2 and game.flight_start.y > 2.65 and game.flight_start.y > game.players[0].head.global_position.y + .10, "layup releases above head after one-foot jump")
	game.flight_made = true
	ticks(32)
	check(game.scores[0] == 2 and game.makes == 1, "layup scores exactly two")
	game.start_mode("practice")
	game.players[0].position = Vector3(0, 0, -4.0)
	game.players[0].motion = Vector2(0, -4)
	game.begin_gather(0)
	check(game.players[0].finish_kind == "dunk", "approach velocity selects dunk before gather slows player")
	game.launch_shot(0)
	ticks(22)
	check(game.phase == "takeoff" and game.players[0].has_ball, "dunk carries ball to the rim before release")
	ticks(2)
	check(game.phase == "flight" and game.flight_start.y > game.HOOP.y + .125, "dunk releases with bottom of resized ball above rim")
	game.flight_made = true
	ticks(12)
	check(game.scores[0] == 2 and game.feedback == "BOOM! +2", "dunk scores two with distinct impact feedback")
	game.register_score()
	check(game.scores[0] == 2, "dunk score event cannot duplicate")
	game.start_mode("practice")
	game.set_drill("dunk")
	ticks(2)
	key(KEY_UP, true)
	ticks(29)
	key(KEY_D, true)
	ticks(1)
	check(game.players[0].finish_kind == "dunk", "camera-relative Up then D selects dunk from finish lab")
	ticks(58)
	key(KEY_UP, false)
	key(KEY_D, false)
	check(game.finish_kind == "dunk" and game.attempts == 1, "held direction and D complete a dunk without retriggering")
	game.start_mode("duel")
	game.players[0].position = Vector3(0, 0, -4)
	game.players[0].motion = Vector2(0, -4)
	game.begin_gather(0)
	game.launch_shot(0)
	game.players[1].action = "block"
	game.players[1].action_time = 0.2
	game.players[1].hand_world = game.ball.position
	check(game.try_block() and game.phase == "loose" and game.ball_owner == -1 and not game.players[0].has_ball, "dunk can be blocked before release and becomes a live loose ball")
	check(game.scores == [0, 0], "blocked dunk does not score")
	game.start_mode("duel")
	game.begin_gather(0)
	game.launch_shot(0)
	game.shot_clock = 0.01
	ticks(1)
	check(game.phase == "live" and game.ball_owner == 1, "shot clock still applies before ball leaves hand")
	game.start_mode("duel")
	game.scores = [7, 5]
	game.begin_gather(0)
	game.launch_shot(0)
	game.clock_left = 0.01
	ticks(1)
	check(game.phase == "ended", "buzzer cancels an unreleased takeoff")
	game.start_mode("practice")
	ticks(2)
	key(KEY_D, true)
	ticks(25)
	key(KEY_D, false)
	ticks(16)
	check(game.phase == "flight" and game.timing_bonus > 0 and game.feedback == "SWEET RELEASE", "release in green window gives bonus through real input")
	game.start_mode("duel")
	game.reset_positions(1)
	game.players[1].position = Vector3(0, 0, -4)
	game.players[1].motion = Vector2(0, -3.35)
	game.players[0].position = Vector3(4, 0, 2)
	game.begin_gather(1)
	game.launch_shot(1)
	ticks(24)
	check(game.phase == "flight" and game.finish_kind == "dunk" and game.shooter == 1, "AI shares dunk takeoff and release path")
	game.flight_made = true
	ticks(12)
	check(game.scores[1] == 2 and game.makes == 0, "AI dunk scores for rival only")
	game.start_mode("duel")
	game.reset_positions(1)
	game.shot_clock = 0.01
	ticks(1)
	check(game.ball_owner == 0 and game.shot_clock == 15, "shot clock violation changes possession")
	game.shooter = 1
	game.players[0].position = Vector3(0, 0, -2)
	game.claim_ball(0)
	check(game.needs_clear and game.ball_owner == 0, "defensive rebound requires clearing")
	ticks(2)
	key(KEY_D, true)
	ticks(40)
	key(KEY_D, false)
	check(game.phase == "live" and game.attempts == 0, "uncleared ball cannot be shot")
	game.players[0].position = Vector3(0, 0, 2)
	ticks(1)
	check(not game.needs_clear, "moving outside arc clears the ball")
	game.reset_positions(1)
	ticks(360)
	check(game.event_id > 1, "AI offense creates an actual shot")
	game.start_mode("duel")
	game.scores = [7, 5]
	game.clock_left = 0.01
	ticks(2)
	check(game.phase == "ended", "non-tied game ends when time expires")
	game.start_mode("duel")
	game.scores = [5, 5]
	game.clock_left = 0.01
	ticks(2)
	check(game.phase != "ended", "tied game enters sudden death")
	game.paused = true
	var before = game.time
	ticks(60)
	check(game.time == before, "pause freezes simulation")
	game.start_mode("duel")
	ticks(2)
	var court_position = game.players[0].position
	var court_time = game.clock_left
	game.toggle_showroom()
	key(KEY_D, true)
	ticks(90)
	key(KEY_D, false)
	check(game.inspecting and game.clock_left == court_time and game.players[0].position == court_position and game.attempts == 0, "character inspection freezes match and ignores gameplay input")
	game.toggle_showroom()
	check(not game.inspecting and game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and game.players[0].position == court_position, "returning from inspection restores perspective camera and court position")
	game.toggle_showroom()
	game.start_mode("practice")
	check(not game.inspecting and not game.showroom.visible, "starting a new mode exits character inspection")
	game.players[0].position = Vector3(6.5, 0, 5.5)
	game.players[0].motion = Vector2(4.7, 0)
	game.move_player(0, .2)
	check(game.players[0].position.x > 6.5 and game.players[0].position.z == 5.5, "half-court wing and front court are playable")
	game.move_player(0, 2)
	check(is_equal_approx(game.players[0].position.x, 7.2), "movement stops at half-court sideline margin")
	game.queue_free()
	await process_frame
	print("GAME_TESTS_COMPLETE")
	quit(1 if failures else 0)
