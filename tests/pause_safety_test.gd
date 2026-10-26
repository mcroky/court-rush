extends SceneTree

var game
var failures = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key,down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func ticks(count: int) -> void:
	for f in range(count): game._physics_process(1.0/60)
func pause_game(value: bool) -> void:
	if game.has_method("set_paused"): game.set_paused(value,"창 전환")
	else: game.paused = value
func snapshot(p) -> Array:
	return [game.time,game.clock_left,game.shot_clock,game.ball.position,p.position,p.action,p.action_time,p.jump,p.feet_world.duplicate()]
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("practice")
	var p = game.players[0]
	p.rotation.y=PI;p.facing=PI;p.reset_stance();p.feet_world.clear()
	ticks(2)
	key(KEY_D,true)
	ticks(8)
	check(p.action == "gather","Setup did not start shot preparation")
	pause_game(true)
	key(KEY_D,false)
	ticks(10)
	check(p.action == "idle" and p.has_ball and p.dribble_ended,"Pause did not safely keep a charging shot in hand")
	pause_game(false)
	ticks(15)
	check(p.action == "idle" and game.attempts == 0,"Resume released an unintended fake or shot")
	# The added turn-to-shoot also carries a pending release. Cancel it on pause.
	game.start_mode("practice");p.rotation.y=0;p.facing=0;p.reset_stance();p.feet_world.clear();ticks(2)
	key(KEY_D,true);ticks(5)
	check(p.action=="square","Setup did not enter grounded turn-to-shoot")
	pause_game(true);key(KEY_D,false);ticks(10)
	check(p.action=="idle" and p.dribble_ended and not p.held.queued_release,"Pause kept a pending turnaround release")
	pause_game(false);ticks(80)
	check(game.attempts==0 and p.has_ball,"Resuming a turn-to-shoot fired an unrequested shot")
	game.fake_shot(0);ticks(8);pause_game(true);pause_game(false);ticks(60)
	check(p.has_ball and p.action=="idle" and game.attempts==0,"Paused held fake did not return safely to possession")
	# Repeated pause requests are idempotent, including a menu over an existing pause.
	pause_game(true)
	pause_game(true)
	check(game.paused,"Second pause request resumed the game")
	game.start_mode("practice")
	ticks(2)
	pause_game(true)
	key(KEY_RIGHT,true)
	key(KEY_D,true)
	var origin = p.position
	pause_game(false)
	ticks(15)
	check(p.position == origin and game.attempts == 0,"Held inputs restarted movement or shooting on resume")
	key(KEY_RIGHT,false)
	key(KEY_D,false)
	ticks(2)
	key(KEY_RIGHT,true)
	ticks(12)
	check(p.position.distance_to(origin) > .15,"Fresh input stayed locked after key release")
	key(KEY_RIGHT,false)
	# Jump state, contact and ball stay exactly frozen during an interruption.
	for kind in ["rebound","block"]:
		game.start_mode("practice")
		game.set_drill(kind)
		if kind == "block": ticks(20)
		else: ticks(6)
		key(KEY_D,true)
		ticks(16)
		key(KEY_D,false)
		pause_game(true)
		var held = snapshot(p)
		ticks(45)
		check(snapshot(p) == held,kind+" changed ball, time, pose or feet while paused")
		pause_game(false)
		ticks(65)
		check(p.action == "idle" and p.jump == 0,kind+" failed to finish landing after manual resume")
		if kind == "rebound": check(game.ball_owner == 0,"Paused rebound lost its catch")
		else: check(p.block_contact,"Paused block lost its timed contact")
	# Reduced visuals must apply while paused, without advancing the play.
	game.start_mode("practice")
	game.set_drill("boxout")
	game.impact = .2
	game.reduced_motion = false
	game._physics_process(1.0/60)
	check(game.impact_ring.visible,"Normal effect did not start")
	pause_game(true)
	var held = snapshot(p)
	game.reduced_motion = true
	game.update_ball_visual()
	check(not game.impact_ring.visible,"Reduced effects left a paused impact visible")
	check(game.trail.all(func(point): return not point.visible),"Reduced effects left a trail visible")
	check(snapshot(p) == held,"Visual preference changed simulation state")
	print("PAUSE_SAFETY charge, repeat pause, midair rebound/block, reduced visuals; failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
