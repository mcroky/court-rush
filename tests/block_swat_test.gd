extends SceneTree

var failures = 0
var contacts = 0
var fastest_separation = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 12: push_error(message)
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
			var contact_t = -1.0
			var origin = Vector3.ZERO
			var outgoing = Vector3.ZERO
			var checked_departure = false
			for f in range(int(fps*.9)):
				var before = p.block_contact
				game._physics_process(1.0/fps)
				if p.block_contact and not before:
					contacts += 1
					contact_t = p.action_time
					origin = game.ball.position
					outgoing = game.ball_velocity
					check(game.phase == "loose" and game.ball_owner == -1,"Block did not knock the ball free")
					check(outgoing.length()>8.5 and outgoing.y < -5.0,"Block let the ball drop weakly instead of swatting it away")
				if contact_t >= 0 and not checked_departure and p.action_time-contact_t >= .10:
					checked_departure = true
					var travel = game.ball.position-origin
					fastest_separation = maxf(fastest_separation,travel.length())
					check(travel.length()>.65,"Swatted ball remained beside the palm after impact")
					check(travel.normalized().dot(outgoing.normalized())>.9,"Swat flight did not follow its impact direction")
					check(game.ball.position.distance_to(p.hand_world)>.4,"Block looked like a catch instead of a deflection")
			check(checked_departure,"Missing a timed swat contact")
			check(game.scores == [0,0],"Swatted shot scored")
			key(false)
	# Even perfect spatial overlap cannot block outside the timing window.
	for t in [.05,.60]:
		game.start_mode("duel")
		game.shooter = 1
		game.phase = "flight"
		game.ball_owner = -1
		var p = game.players[0]
		p.action = "block"
		p.action_time = t
		game.ball.position = p.hand_world
		game.previous_ball_position = game.ball.position
		check(not game.try_block(),"Mistimed palm overlap still deflected the shot")
	check(contacts == 6,"Timed block lab did not produce six contacts")
	print("BLOCK_SWAT contacts=",contacts," max_departure_100ms_m=",fastest_separation," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
