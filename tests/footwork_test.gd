extends SceneTree

var game
var failures = 0
var samples = 0
var steps = 0
var last_serial = -1
var last_foot = -1
var skill_frames = {"spin": 0, "twostep": 0, "behind": 0, "hesi": 0}

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
		if failures < 8: push_error(message)

func ticks(count: int, dt: float) -> void:
	for frame in range(count):
		game._physics_process(dt)
		var p = game.players[0]
		check(not (p.swinging[0] and p.swinging[1]), "Both feet launched together")
		# A pushing foot rolls onto its forefoot: the shoe origin rises while the
		# actual sole contact stays planted. Test the rendered heel/toe contacts.
		var sole_height = 1.0
		for shoe in p.shoes:
			sole_height = minf(sole_height,minf(shoe.to_global(p.LAYUP_TOE).y,shoe.to_global(Vector3(0,0,-.15)).y))
		check(sole_height <= .115, "Both rendered soles left the ground during dribbling")
		if p.step_serial != last_serial:
			if last_foot >= 0: check(p.last_step != last_foot, "Foot order did not alternate")
			last_foot = p.last_step
			last_serial = p.step_serial
			steps += 1
		if p.action in skill_frames: skill_frames[p.action] += 1
		for i in range(2):
			check(absf(p.joint_hips[i].distance_to(p.joint_knees[i]) - p.THIGH_LENGTH) < .0002, "Thigh stretched")
			check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i]) - p.SHIN_LENGTH) < .0002, "Shin stretched")
			check(p.shoes[i].global_position.y >= .09, "Foot below floor")
		samples += 1

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30, 60, 120]:
		for move in [KEY_A, KEY_Z, KEY_C, KEY_V, KEY_X]:
			for direction in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				game.start_mode("practice")
				game.players[0].feet_world.clear()
				game.players[0].position = Vector3.ZERO
				last_foot = -1
				last_serial = game.players[0].step_serial
				key(direction, true)
				ticks(int(fps * .4), 1.0 / fps)
				key(move, true)
				ticks(int(fps * .8), 1.0 / fps)
				key(move, false)
				key(direction, false)
				key(KEY_RIGHT if direction != KEY_RIGHT else KEY_LEFT, true)
				ticks(int(fps * .3), 1.0 / fps)
				key(KEY_RIGHT, false)
				key(KEY_LEFT, false)
				ticks(int(fps * .3), 1.0 / fps)
				check(game.players[0].action == "idle", "Skill did not complete")
				check(not game.players[0].dribble_ended, "Dribble skill incorrectly gathered ball")
	# Both new skills must respect held-ball and possession guards.
	game.begin_gather(0)
	game.fake_shot(0)
	ticks(30, 1.0 / 60)
	var origin = game.players[0].position
	for move in [KEY_Z, KEY_C, KEY_V, KEY_X]:
		key(move, true)
		ticks(50, 1.0 / 60)
		key(move, false)
		ticks(2, 1.0 / 60)
		check(game.players[0].action == "idle" and game.players[0].position == origin, "Skill restarted held-ball dribble")
	game.players[0].dribble_ended = false
	game.ball_owner = 1
	game.start_dribble_skill("spin", Vector3.FORWARD)
	check(game.players[0].action == "idle", "Skill accepted without possession")
	check(skill_frames.spin > 100 and skill_frames.twostep > 100 and skill_frames.behind > 100 and skill_frames.hesi > 100, "New skills not exercised")
	print("FOOTWORK samples=", samples, " alternating_steps=", steps, " skill_frames=", skill_frames, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
