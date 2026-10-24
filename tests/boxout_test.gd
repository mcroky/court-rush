extends SceneTree

var failures = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("duel")
	var holder = game.players[0]
	var attacker = game.players[1]
	game.phase = "flight"
	game.ball_owner = -1
	game.shooter = 1
	game.flight_start = Vector3(0,4,-2)
	game.flight_target = game.HOOP
	game.flight_duration = 10
	holder.position = Vector3(0,0,-3)
	attacker.position = Vector3(0,0,-2.2)
	for p in game.players:
		p.has_ball = false
		p.action = "idle"
		p.motion = Vector2.ZERO
		p.jump = 0
	key(KEY_W,true)
	game._physics_process(1.0/60)
	check(holder.boxing_out and not attacker.boxing_out, "W must establish inside box-out after a shot")
	check(absf(angle_difference(holder.facing,PI)) < .1, "Boxer must face the rim with back toward opponent")
	check(game.rebound_blocked(1), "Rear opponent should be blocked from reaching through holder")
	for frame in range(24): game._physics_process(1.0/60)
	check(holder.position.z < attacker.position.z and holder.position.distance_to(attacker.position) >= .85, "Opponent ran through box-out")
	key(KEY_W,false)
	game._physics_process(1.0/60)
	check(not holder.boxing_out and not game.rebound_blocked(1), "Releasing W must release box-out")
	key(KEY_W,true)
	attacker.position = holder.position + Vector3(.9,0,0)
	game.update_boxouts(true)
	check(not holder.boxing_out, "Side escape should beat box-out")
	attacker.position = holder.position + Vector3(0,0,.9)
	game.update_boxouts(true)
	key(KEY_D,true)
	game._physics_process(1.0/60)
	game._physics_process(1.0/60)
	check(holder.action == "rebound" and not holder.boxing_out, "D must release stance and use the dedicated rebound jump")
	key(KEY_D,false)
	key(KEY_W,false)
	# AI uses the same stance when it wins the inside lane.
	game.shooter = 0
	game.ball.position = Vector3(0,3,-4)
	attacker.action = "idle"
	attacker.jump = 0
	holder.action = "idle"
	holder.jump = 0
	holder.position = Vector3(0,0,-2.2)
	attacker.position = Vector3(0,0,-3)
	game.update_boxouts(false)
	check(attacker.boxing_out and game.rebound_blocked(0), "AI should box out with inside position")
	game.phase = "live"
	game.update_boxouts(true)
	check(not holder.boxing_out and not attacker.boxing_out, "No rebound box-out before a shot")
	game.claim_ball(0)
	check(not holder.boxing_out and not attacker.boxing_out, "New possession must clear box-out")
	game.start_mode("practice")
	game.set_drill("boxout")
	check(game.phase == "flight" and attacker.visible and not holder.has_ball, "Box-out practice must provide an opponent and incoming shot")
	key(KEY_W,true)
	game._physics_process(1.0/60)
	check(holder.boxing_out, "W must box out in the repeatable rebound drill")
	key(KEY_W,false)
	game.set_drill("layup")
	check(not attacker.visible and not holder.boxing_out and game.phase == "live", "Leaving rebound drill must restore solo practice")
	print("BOXOUT W input, inside position, contact, side escape, release, rebound jump, AI; failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
