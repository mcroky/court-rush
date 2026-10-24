extends SceneTree

var game
var failures = 0
var samples = 0
var worst_error = 0.0
var crossover_frames = 0

func _init() -> void:
	call_deferred("run")

func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func sample(player) -> void:
	for i in range(2):
		var thigh = player.joint_hips[i].distance_to(player.joint_knees[i])
		var shin = player.joint_knees[i].distance_to(player.joint_ankles[i])
		var error = maxf(absf(thigh - player.THIGH_LENGTH), absf(shin - player.SHIN_LENGTH))
		# Also inspect the rendered mesh, not just the solver's return values.
		error = maxf(error, absf(player.legs[i][1].basis.y.length() - player.SHIN_LENGTH))
		error = maxf(error, absf(player.shorts[i].basis.y.length() - player.THIGH_LENGTH * .92))
		error = maxf(error, absf(player.arms[i][0].basis.y.length() - player.UPPER_ARM_LENGTH))
		error = maxf(error, absf(player.arms[i][1].basis.y.length() - player.FOREARM_LENGTH))
		worst_error = maxf(worst_error, error)
		if error > .0002:
			failures += 1
		if player.jump <= .05 and player.shoes[i].global_position.y < .09:
			failures += 1
		samples += 1
	if player.action == "cross": crossover_frames += 1

func ticks(count: int, delta: float) -> void:
	for frame in range(count):
		game._physics_process(delta)
		sample(game.players[0])

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	var directions = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
	for fps in [30, 60, 120]:
		for direction in directions:
			for turn in directions:
				game.start_mode("practice")
				game.players[0].position = Vector3(0, 0, 1)
				key(direction, true)
				ticks(int(fps * .6), 1.0 / fps)
				key(direction, false)
				key(turn, true)
				key(KEY_A, true)
				ticks(int(fps * .42), 1.0 / fps)
				key(KEY_A, false)
				ticks(int(fps * .6), 1.0 / fps)
				key(turn, false)
				ticks(int(fps * .25), 1.0 / fps)
	# Airborne finishing poses must use the same fixed bones.
	var player = game.players[0]
	for action in ["shot", "layup", "dunk", "block"]:
		for frame in range(60):
			player.action = action
			player.action_time = frame / 60.0
			player.jump = maxf(0, sin(minf(player.action_time / .82, 1) * PI))
			player.animate(1.0 / 60, frame / 60.0)
			sample(player)
	print("CROSSOVER_REGRESSION samples=", samples, " crossover_frames=", crossover_frames, " worst_bone_error=", worst_error, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures or crossover_frames < 100 else 0)
