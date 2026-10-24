extends SceneTree

var failures = 0
var contacts = 0
var windups = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 14: push_error(message)
func key(down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = KEY_D
	e.physical_keycode = KEY_D
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
			game.start_mode("practice")
			game.set_drill("block")
			game.players[1].position.x = side*.14
			for f in range(int(fps*.34)): game._physics_process(1.0/fps)
			key(true)
			var p = game.players[0]
			var low_yaw = INF
			var high_yaw = -INF
			var low_pitch = INF
			var high_pitch = -INF
			var previous_chest = p.upper.rotation
			var had_contact = false
			for f in range(int(fps*.9)):
				var before = p.block_contact
				game._physics_process(1.0/fps)
				if p.action != "block": continue
				var hand = p.hands[1 if p.dribble_hand>0 else 0]
				if not before:
					low_yaw = minf(low_yaw,p.upper.rotation.y)
					high_yaw = maxf(high_yaw,p.upper.rotation.y)
					low_pitch = minf(low_pitch,p.upper.rotation.x)
					high_pitch = maxf(high_pitch,p.upper.rotation.x)
					if p.action_time >= .125 and p.action_time <= .15:
						var local = p.upper.to_local(hand.global_position)
						check(local.y>2.25 and local.z<.16,"Block did not cock its arm above/behind the head before swinging")
						windups += 1
				if p.block_contact and not before:
					contacts += 1
					had_contact = true
					check(high_yaw-low_yaw>.20,"Chest stayed fixed until after the ball had already deflected")
					check(high_pitch-low_pitch>.14,"Block lacked a chest load and forward whip")
					check(hand.global_basis.z.normalized().dot(Vector3.DOWN)>.65,"Palm hit the ball edge-on instead of facing down")
				check(p.upper.rotation.distance_to(previous_chest)<8.0/fps,"Block chest snapped at contact or recovery")
				previous_chest = p.upper.rotation
			check(had_contact,"Authored swing failed to contact the real shot")
			key(false)
	check(contacts==6 and windups>0,"Incomplete body/palm swing coverage")
	print("BLOCK_BODY_SWING contacts=",contacts," windup_samples=",windups," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
