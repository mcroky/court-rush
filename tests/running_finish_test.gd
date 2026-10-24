extends SceneTree

var game
var failures = 0

func _init() -> void: call_deferred("run")

func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	var rules = load("res://scripts/rules.gd")
	check(rules.finish_type(Vector3(0,0,-2.75), Vector2(0,-4)) == "layup", "Running layup should engage at 2.9m")
	check(rules.finish_type(Vector3(0,0,-3.9), Vector2(0,-1)) == "dunk", "Inner zone should dunk at modest approach speed")
	check(rules.finish_type(Vector3(0,0,-4.8), Vector2.ZERO) == "dunk", "Standing rim finish should dunk")
	check(rules.finish_type(Vector3(0,0,-6), Vector2(0,4)) == "shot", "No automatic finish through the backboard")
	for fps in [30, 60, 120]:
		for finish in ["layup", "dunk"]:
			game.start_mode("practice")
			var p = game.players[0]
			p.position = Vector3(0, 0, -2.55 if finish == "layup" else -3.8)
			p.feet_world.clear()
			game._physics_process(1.0 / fps)
			key(KEY_UP, true)
			for f in range(int(fps * .15)): game._physics_process(1.0 / fps)
			key(KEY_D, true)
			game._physics_process(1.0 / fps)
			check(p.finish_kind == finish and p.finish_running, "Running input selected wrong finish: " + finish)
			var gather_origin = p.position
			var steps_before = p.gather_step_start
			key(KEY_D, false) # A tap while running near the rim commits the finish.
			for f in range(int(fps * .24)): game._physics_process(1.0 / fps)
			check(game.phase == "takeoff" and game.finish_kind == finish, "Running D tap became a fake or delayed shot")
			check(p.position.distance_to(gather_origin) > .15, "Gather killed forward motion")
			check(p.step_serial - steps_before <= 2, "More than two contact steps after gather")
			check(p.dribble_ended, "Gather must end dribble")
			for f in range(int(fps * .6)):
				game._physics_process(1.0 / fps)
				if game.phase == "flight": break
			check(game.phase == "flight" and game.attempts == 1, "Finish did not release exactly once")
			# A finger roll can release below the rim; it must leave above the head.
			var minimum = 2.65 if finish == "layup" else game.HOOP.y + .125
			check(game.flight_start.y > minimum and game.flight_start.y > p.head.global_position.y + .10, "Finish released below expected hand height")
			key(KEY_UP, false)
	# A dribble move can flow straight into the finish during its recovery.
	game.start_mode("practice")
	game.players[0].position = Vector3(0,0,-2.4)
	game.start_dribble_skill("hesi", Vector3.FORWARD)
	for f in range(24): game._physics_process(1.0 / 60)
	key(KEY_D, true)
	game._physics_process(1.0 / 60)
	check(game.players[0].action == "gather" and game.players[0].finish_running, "Skill recovery did not connect to running finish")
	key(KEY_D, false)
	print("RUNNING_FINISH fps=30/60/120 tap_layup+dunk, two-step gather, skill linkage; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
