extends SceneTree

var failures = 0
var cases = 0
var contacts = 0
var largest_ball_entry = 0.0
var cuts = 0
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
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for phase in [.08,.40,.74]:
				for turn in [KEY_LEFT,KEY_DOWN]:
					game.start_mode("practice")
					var p = game.players[0]
					p.position = Vector3(0,0,2)
					p.dribble_hand = side
					p.ball_side = side
					key(KEY_UP,true)
					for f in range(int(fps*.55)): game._physics_process(1.0/fps)
					p.dribble_phase = phase*TAU
					p.animate(.001,game.time)
					game.ball.position = p.ball_anchor(game.time)
					var ball_before = game.ball.position
					game.crossover(Vector2(-1,0))
					var after_request = p.ball_anchor(game.time)
					largest_ball_entry = maxf(largest_ball_entry,after_request.distance_to(ball_before))
					check(after_request.distance_to(ball_before)<.015,"Cross input reset the current bounce position")
					check(p.dribble_hand == side,"Cross input changed hands before the receiver touched ball")
					key(KEY_UP,false)
					key(turn,true)
					var received = false
					var old_owner_hand = side
					var last_hands = [p.palm_position(0),p.palm_position(1)]
					var last_palms = [p.palm_frame(0).get_rotation_quaternion(),p.palm_frame(1).get_rotation_quaternion()]
					for f in range(int(fps*1.35)):
						game._physics_process(1.0/fps)
						if p.dribble_hand != old_owner_hand:
							received = true
							contacts += 1
							var receiver = p.palm_position(1 if p.dribble_hand > 0 else 0)
							check(receiver.distance_to(game.ball.position+Vector3.UP*p.DRIBBLE_PALM)<.045,"Visible receiver changed before touching the rising ball")
						old_owner_hand = p.dribble_hand
						if p.action == "cross":
							# Rendered radius125mm, palm clearance15mm; test actual skin.
							var both = p.palm_position(0).distance_to(game.ball.position)<.17 and p.palm_position(1).distance_to(game.ball.position)<.17
							check(not both,"Crossover gripped the ball with both hands")
						for i in range(2):
							var palm = p.palm_frame(i).get_rotation_quaternion()
							check(palm.angle_to(last_palms[i])<24.0/fps,"Cross palm orientation snapped: fps=%d side=%.0f hand=%d t=%.3f angle=%.3f action=%s" % [fps,side,i,p.action_time,palm.angle_to(last_palms[i]),p.action])
							last_palms[i] = palm
							check(p.palm_position(i).distance_to(last_hands[i])<12.0/fps,"Visible cross/run palm snapped: fps=%d side=%.0f hand=%d phase=%.3f speed=%.2f action=%s" % [fps,side,i,p.action_time,p.palm_position(i).distance_to(last_hands[i])*fps,p.action])
							check(absf(p.arms[i][0].basis.y.length()-p.UPPER_ARM_LENGTH)<.0002,"Cross shoulder/arm stretched")
							check(absf(p.arms[i][1].basis.y.length()-p.FOREARM_LENGTH)<.0002,"Cross forearm stretched")
							last_hands[i] = p.palm_position(i)
						check(not p.dribble_ended and game.ball_owner==0,"Crossover ended a legal dribble")
					check(received and p.action=="idle" and p.dribble_hand==-side,"Cross did not receive and resume running")
					key(turn,false)
					cases += 1
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for turn in [KEY_LEFT,KEY_DOWN]:
				game.start_mode("practice")
				var p = game.players[0]
				p.position = Vector3(0,0,2)
				p.dribble_hand = side
				p.ball_side = side
				key(KEY_UP,true)
				for f in range(int(fps*.6)): game._physics_process(1.0/fps)
				key(KEY_UP,false)
				key(turn,true)
				# The hidden procedural targets are no longer the rendered wrists.
				var previous = [p.palm_position(0),p.palm_position(1)]
				for f in range(int(fps*1.0)):
					game._physics_process(1.0/fps)
					for i in range(2):
						check(p.palm_position(i).distance_to(previous[i])<12.0/fps,"Direction cut snapped visible shoulder/wrist chain")
						previous[i] = p.palm_position(i)
					var phase = fposmod(p.dribble_phase,TAU)/TAU
					if phase < .12 or phase > .94:
						check(p.palm_position(1 if side>0 else 0).distance_to(game.ball.position+Vector3.UP*p.DRIBBLE_PALM)<.11,"Direction cut lost visible dribble palm contact")
				key(turn,false)
				cuts += 1
	for delay in [6,20,35]:
		game.start_mode("practice")
		var p = game.players[0]
		p.dribble_phase = TAU*.40
		p.animate(.016,game.time)
		game.ball.position = p.ball_anchor(game.time)
		game.crossover(Vector2.LEFT)
		for f in range(delay): game._physics_process(1.0/60)
		game.set_paused(true)
		var held = [game.ball.position,p.action,p.action_time,p.dribble_hand,p.cross_received,p.cross_exit_left,p.hands[0].global_position,p.hands[1].global_position]
		for f in range(30): game._physics_process(1.0/60)
		check(held == [game.ball.position,p.action,p.action_time,p.dribble_hand,p.cross_received,p.cross_exit_left,p.hands[0].global_position,p.hands[1].global_position],"Paused cross advanced ball, catch or pose")
		game.set_paused(false)
		for f in range(90): game._physics_process(1.0/60)
		check(p.action == "idle" and not p.dribble_ended,"Interrupted cross failed to receive and recover")
	print("CROSS_HANDOFF cases=",cases," receives=",contacts," ordinary_cuts=",cuts," paused_stages=3 max_entry_ball_move_m=",largest_ball_entry," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
