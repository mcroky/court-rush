extends SceneTree

var game
var failures = 0
var samples = 0
var catches = 0
var blocks = 0
var worst_ball_snap = 0.0
var smallest_swat_drop = 100.0
var smallest_air_hold = 100.0
var rim_catches = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 12: push_error(message)
func key(code: Key,down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func sample(p) -> void:
	for i in range(2):
		check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Defensive thigh stretched")
		check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Defensive shin stretched")
		check(p.shoes[i].global_position.y > .094,"Defensive foot sank through court")
		check(absf(p.arms[i][0].basis.y.length()-p.UPPER_ARM_LENGTH) < .0002,"Defensive upper arm stretched")
		check(absf(p.arms[i][1].basis.y.length()-p.FOREARM_LENGTH) < .0002,"Defensive forearm stretched")
	samples += 1

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			game.start_mode("practice")
			game.set_drill("rebound")
			var p = game.players[0]
			game.ball.position.x += side*.14
			game.previous_ball_position = game.ball.position
			for f in range(int(fps*.10)): game._physics_process(1.0/fps)
			key(KEY_D,true)
			game._physics_process(1.0/fps)
			check(p.action == "rebound","Loose-ball D did not select rebound")
			var start_feet = [p.shoes[0].global_position,p.shoes[1].global_position]
			var caught_dribble = -1.0
			var air_hold_height = 0.0
			var tuck_height = 100.0
			for f in range(int(fps*1.10)):
				var before_owner = game.ball_owner
				var old_ball = game.ball.position
				game._physics_process(1.0/fps)
				sample(p)
				if p.action == "rebound" and p.action_time <= p.DEFENSE_PLANT_TIME:
					check(p.jump == 0,"Rebound left ground before plant completed")
					for i in range(2):
						var drift = p.shoes[i].global_position-start_feet[i]
						drift.y = 0
						check(drift.length() < .012,'Rebound plant foot slid sideways')
				if before_owner == -1 and game.ball_owner == 0:
					catches += 1
					caught_dribble = p.dribble_phase
					check(p.action == "rebound" and p.defense_caught,"Air catch failed to retain rebound animation")
					check(p.jump > .18,"Rebound possession was awarded on the ground")
					for h in p.hands: check(h.global_position.distance_to(game.ball.position) < .34,"Rebound awarded before both hands reached ball")
					check(game.ball.position.distance_to(p.rebound_anchor()) < .30,"Caught ball was outside hands")
					worst_ball_snap = maxf(worst_ball_snap,game.ball.position.distance_to(old_ball))
				if p.action == "rebound" and p.defense_caught:
					check(game.ball.position.distance_to(p.rebound_anchor()) < .30,"Caught rebound bounced before landing")
					check(p.dribble_phase == caught_dribble,"Rebound started dribbling before landing")
					var elapsed = p.action_time-p.defense_catch_time
					var held_height = p.body.to_local(game.ball.position).y
					if elapsed >= .10 and elapsed <= .18: air_hold_height = maxf(air_hold_height,held_height)
					if elapsed >= .40: tuck_height = minf(tuck_height,held_height)
			check(air_hold_height > 2.38,"Rebound did not show a high two-handed secure pose")
			check(tuck_height < air_hold_height-.20,"Rebound did not pull secured ball down to chest")
			smallest_air_hold = minf(smallest_air_hold,air_hold_height)
			check(game.ball_owner == 0 and p.action == "idle" and p.jump == 0,"Rebound did not catch and land")
			check(game.attempts == 0,"Holding D after rebound triggered a shot")
			key(KEY_D,false)
			# Real opponent release, not a manually assigned hand position.
			game.start_mode("practice")
			game.set_drill("block")
			game.players[1].position.x = side*.14
			for f in range(int(fps*.34)): game._physics_process(1.0/fps)
			key(KEY_D,true)
			game._physics_process(1.0/fps)
			check(p.action == "block","Defensive D did not select block")
			var asymmetric = false
			var did_block = false
			var contact_height = 0.0
			var follow_height = 100.0
			var wrist_flex = 0.0
			for f in range(int(fps*1.1)):
				game._physics_process(1.0/fps)
				sample(p)
				if p.action == "block" and p.jump > .25:
					asymmetric = asymmetric or absf(p.hands[0].global_position.y-p.hands[1].global_position.y) > .25
				if p.block_contact:
					if not did_block:
						contact_height = p.hand_world.y
						check(game.ball_velocity.y < -3.0,"Palm contact did not drive ball downward")
						did_block = true
					var elapsed = p.action_time-p.block_contact_time
					if elapsed >= .10 and elapsed <= .26:
						follow_height = minf(follow_height,p.hand_world.y)
						wrist_flex = maxf(wrist_flex,p.hands[1 if p.dribble_hand > 0 else 0].rotation.x)
			check(asymmetric,"Block still used a two-handed shot pose")
			if did_block: blocks += 1
			check(did_block,"Timed block drill did not contact actual release at %dfps" % fps)
			check(contact_height-follow_height > .16,"Block arm did not visibly follow downward through contact")
			check(wrist_flex > .95,"Block wrist did not turn palm downward")
			smallest_swat_drop = minf(smallest_swat_drop,contact_height-follow_height)
			check(game.scores == [0,0],"Blocked shot scored")
			check(p.action == "idle" and p.jump == 0,"Block did not land and recover")
			key(KEY_D,false)
	# Exercise the actual missed-shot rim response, not only the falling-ball lab.
	for fps in [30,60,120]:
		game.start_mode("practice")
		game.rng.seed = 102
		game.ball_owner = -1
		game.players[0].has_ball = false
		game.shooter = 0
		game.phase = "flight"
		game.flight_start = game.HOOP+Vector3(0,1,2)
		game.flight_target = game.HOOP
		game.flight_t = game.flight_duration
		game.flight_made = false
		game.update_flight(.001)
		check(game.phase == "loose" and game.ball_velocity.y > 2,"Missed rim did not launch a rebound")
		# Wait for the higher rim bounce to descend into a timed jump window.
		for f in range(int(fps*.85)): game._physics_process(1.0/fps)
		var p = game.players[0]
		p.position = game.ball.position+game.ball_velocity*.45
		p.position.y = 0
		p.reset_stance()
		p.facing = atan2(game.ball.position.x-p.position.x,game.ball.position.z-p.position.z)
		p.rotation.y = p.facing
		p.animate(.016,game.time)
		key(KEY_D,true)
		for f in range(int(fps*1.15)):
			game._physics_process(1.0/fps)
			if p.defense_caught and p.jump > .18 and game.ball_owner == 0:
				rim_catches += 1
				break
		check(p.defense_caught,"Failed to air-catch an actual rim rebound at %dfps" % fps)
		key(KEY_D,false)
	# The old broad pickup radius must not vacuum a high ball into a block pose.
	game.start_mode("practice")
	game.set_drill("rebound")
	game.ball.position = game.players[0].position+Vector3(.65,2.5,0)
	game.ball_velocity = Vector3.ZERO
	game.loose_timer = .3
	game.update_loose(.001)
	check(game.ball_owner == -1,"High ball was picked up without reaching it")
	# A nearby hand must miss; a ball crossing the descending palm must hit once.
	game.start_mode("duel")
	game.shooter = 1
	game.phase = "flight"
	var defender = game.players[0]
	defender.position = Vector3(0,0,-4.6)
	defender.rotation.y = 0
	defender.prepare_defense("block",Vector3(0,2.5,-4))
	defender.action_time = .30
	defender.hand_world = Vector3(0,2.5,-4)
	defender.previous_hand_world = defender.hand_world
	game.ball.position = defender.hand_world+Vector3(.45,0,0)
	game.previous_ball_position = game.ball.position
	check(not game.try_block(),"Block still used a broad body-radius hit")
	defender.previous_hand_world = defender.hand_world+Vector3.UP*.03
	game.previous_ball_position = defender.hand_world+Vector3(-.6,0,0)
	game.ball.position = defender.hand_world+Vector3(.6,0,0)
	check(game.try_block() and game.phase == "loose","Ball tunneled past blocking hand")
	check(not game.try_block(),"Block fired twice for the same contact")
	check(catches == 6,"Missing actual airborne catches")
	check(worst_ball_snap < .20,"Airborne catch teleported the ball")
	print("DEFENSIVE_PLAY frames=",samples," catches=",catches," rim_catches=",rim_catches," blocks=",blocks," min_swat_drop_m=",smallest_swat_drop," min_air_hold_local_y=",smallest_air_hold," max_catch_tick_travel_m=",worst_ball_snap," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
