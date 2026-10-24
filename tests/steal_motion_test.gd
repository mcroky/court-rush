extends SceneTree

var failures = 0
var contacts = 0
var misses = 0
var frames = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 12: push_error(message)
func key(down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = KEY_S
	e.physical_keycode = KEY_S
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for seed_value in [1,2,3,4]:
				game.start_mode("practice")
				game.set_drill("steal")
				var p = game.players[0]
				var attacker = game.players[1]
				attacker.dribble_hand = side
				attacker.ball_side = side
				attacker.dribble_phase = 0
				p.position.x = -.25*side
				p.feet_world.clear()
				p.animate(1.0/fps,game.time)
				for f in range(int(fps*.05)): game._physics_process(1.0/fps)
				game.rng.seed = seed_value
				var start = p.position
				key(true)
				game._physics_process(1.0/fps)
				check(p.stealing() and not p.has_ball and game.ball_owner == 1,"S immediately teleported possession")
				var contact_seen = false
				var pose_seen = false
				var max_travel = 0.0
				var last_height = p.body.position.y
				for f in range(int(fps*.90)):
					var old_owner = game.ball_owner
					game._physics_process(1.0/fps)
					max_travel = maxf(max_travel,p.position.distance_to(start))
					if p.stealing():
						pose_seen = pose_seen or p.body.rotation.x > .04
						if p.action_time < .12: check(game.ball_owner == 1,"Steal won before the reach window")
						if p.steal_success:
							check(game.ball.position.distance_to(p.hand_world) < .27,"Won ball separated from the receiving hand")
							check(not p.dribble_ended,"Fresh steal ended dribble eligibility")
					if old_owner == 1 and game.ball_owner == 0:
						contact_seen = true
						contacts += 1
						check(p.action_time >= .12 and p.action_time <= .32,"Steal occurred outside contact window")
						check(game.ball.position.distance_to(p.hand_world) < .25,"Steal won without actual hand contact")
					check(not (p.swinging[0] and p.swinging[1]),"Steal lunged with both legs together")
					check(absf(p.body.position.y-last_height) < .09,"Steal crouch/recovery snapped vertically")
					last_height = p.body.position.y
					check(p.position.distance_to(attacker.position) >= .69,"Steal lunged through the opponent")
					for i in range(2):
						check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Steal thigh stretched")
						check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Steal shin stretched")
						check(absf(p.arms[i][0].basis.y.length()-p.UPPER_ARM_LENGTH) < .0002,"Steal upper arm stretched")
						check(absf(p.arms[i][1].basis.y.length()-p.FOREARM_LENGTH) < .0002,"Steal forearm stretched")
					frames += 1
				if not contact_seen: misses += 1
				check(max_travel > .12 and max_travel <= .40,"Steal lacked a controlled forward step")
				check(pose_seen and p.action == "idle","Steal failed to lean and recover")
				check(game.steal_cooldown > 0,"Held S retriggered or lost cooldown")
				key(false)
				game._physics_process(1.0/fps)
	# Facing away and distant attempts can animate, but cannot take the ball.
	for far in [false,true]:
		game.start_mode("practice")
		game.set_drill("steal")
		var p = game.players[0]
		if far: p.position.z -= 2
		else: p.facing = PI
		game._physics_process(.016)
		game.attempt_steal()
		for f in range(45): game._physics_process(1.0/60)
		check(game.ball_owner == 1,"Far/back-facing attempt stole without contact")
	# Pause preserves the reach, contact target and possession until explicit resume.
	game.start_mode("practice")
	game.set_drill("steal")
	game.attempt_steal()
	for f in range(7): game._physics_process(1.0/60)
	var p = game.players[0]
	game.set_paused(true,"steal test")
	var frozen = [p.position,p.action_time,p.hand_world,game.ball.position,game.ball_owner]
	for f in range(20): game._physics_process(1.0/60)
	check(frozen == [p.position,p.action_time,p.hand_world,game.ball.position,game.ball_owner],"Pause advanced a steal or possession")
	game.set_paused(false)
	for f in range(45): game._physics_process(1.0/60)
	check(p.action == "idle","Paused steal failed to recover after resume")
	# Actual duel still requires clearing after a successful defensive steal.
	game.start_mode("practice")
	game.set_drill("steal")
	game.mode = "duel"
	for player in game.players:
		player.position.z += 4.5
		player.feet_world.clear()
		player.animate(.016,game.time)
	game.players[1].dribble_phase = 0
	game.ball.position = game.players[1].ball_anchor(game.time)
	game.previous_ball_position = game.ball.position
	game.rng.seed = 1
	game.attempt_steal()
	for f in range(36): game._physics_process(1.0/60)
	check(game.ball_owner == 0 and game.needs_clear,"Duel steal failed to preserve the clearing rule")
	check(contacts >= 6 and misses >= 2,"Did not exercise both successful and missed contacts")
	print("STEAL_MOTION frames=",frames," successes=",contacts," misses=",misses," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
