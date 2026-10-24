extends SceneTree

var game
var failures = 0
var blocks = 0
var catches = 0
var max_follow_delay = 0.0
var secured_samples=0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 16: push_error(message)
func key(code: Key,down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			game.start_mode("practice")
			game.set_drill("block")
			var p = game.players[0]
			game.players[1].position.x = side*.14
			for f in range(int(fps*.34)): game._physics_process(1.0/fps)
			key(KEY_D,true)
			var contact_time = -1.0
			var contact_height = 0.0
			var first_down = -1.0
			var contact_velocity = 0.0
			for f in range(int(fps*1.12)):
				var old_hand = p.hand_world
				var was_contact = p.block_contact
				game._physics_process(1.0/fps)
				if p.block_contact and not was_contact:
					blocks += 1
					contact_time = p.action_time
					contact_height = p.hand_world.y
					contact_velocity = (p.hand_world.y-old_hand.y)*fps
					check(contact_velocity < -.12,"Block deflected ball while palm was still rising at %dfps" % fps)
				if contact_time >= 0 and p.action == "block" and p.action_time > contact_time:
					if first_down < 0 and p.hand_world.y < contact_height-.0005:
						first_down = p.action_time-contact_time
			check(first_down > 0 and first_down <= 1.0/fps+.001,"Block follow-through paused after impact at %dfps" % fps)
			max_follow_delay = maxf(max_follow_delay,first_down)
			key(KEY_D,false)
			game.start_mode("practice")
			game.set_drill("rebound")
			game.ball.position.x += side*.14
			game.previous_ball_position = game.ball.position
			for f in range(int(fps*.10)): game._physics_process(1.0/fps)
			key(KEY_D,true)
			var had_catch = false
			var checked_touchdown = false
			var max_chest_tick = 0.0
			var last_local = Vector3.ZERO
			for f in range(int(fps*1.12)):
				game._physics_process(1.0/fps)
				if p.action != "rebound" or not p.defense_caught: continue
				var local = p.upper.to_local(game.ball.position)
				if had_catch: max_chest_tick = maxf(max_chest_tick,local.distance_to(last_local))
				had_catch = true
				last_local = local
				if p.action_time-p.defense_catch_time>.18:
					for i in 2:
						var palm=p.palm_position(i)
						check(palm.distance_to(game.ball.position)<.17,"Secured rebound floated outside actual cupped palms")
						check(p.palm_frame(i).z.dot((game.ball.position-palm).normalized())>.65,"Rebound palm did not face into secured ball")
						secured_samples+=1
				if not checked_touchdown and p.action_time >= p.defense_land_time():
					checked_touchdown = true
					check(local.y >= 1.65 and local.y <= 1.85,"Rebound not hugged at chest at first foot contact at %dfps" % fps)
			check(had_catch and checked_touchdown,"Rebound did not complete air-catch and touchdown")
			check(max_chest_tick < .22,"Rebound hands snapped between secure and chest poses")
			if had_catch: catches += 1
			key(KEY_D,false)
	check(blocks == 6,"Missing timed block contacts")
	check(secured_samples>100,"Missing actual secured palm samples")
	print("CONTACT_TIMING blocks=",blocks," catches=",catches," secured_palm_samples=",secured_samples," max_follow_delay_s=",max_follow_delay," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
