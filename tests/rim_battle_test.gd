extends SceneTree
var failures = 0
var misses = 0
var ai_catches = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures<15: push_error(message)
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
	# Actual ordinary shot outcomes, without forcing a miss or using the lab.
	for seed_value in range(1,33):
		game.start_mode("practice")
		game.practice_drill = "free"
		game.rng.seed = seed_value
		game.players[0].position = Vector3(0,0,0)
		game.players[0].motion = Vector2.ZERO
		game.begin_gather(0)
		game.players[0].finish_kind = "shot"
		game.launch_shot(0)
		for f in range(50):
			game._physics_process(1.0/60)
			if game.phase == "flight": break
		if not game.flight_made:
			misses += 1
			var offset = game.flight_target-game.HOOP
			check(absf(Vector2(offset.x,offset.z).length()-.23)<.001,"Miss bypassed the rim and bounced in empty space")
			for f in range(100):
				game._physics_process(1.0/60)
				if game.phase == "loose": break
			check(game.phase=="loose" and game.ball_velocity.y>3.8,"Rim contact did not create a rising rebound")
			var peak = game.ball.position.y
			for f in range(30):
				game._physics_process(1.0/60)
				peak = maxf(peak,game.ball.position.y)
			check(peak>game.HOOP.y+.6,"Rim rebound left no airtime for box-out positioning")
	check(misses>=3 and misses<32,"Ordinary shots did not produce both makes and rebound opportunities")
	for fps in [30,60,120]:
		game.start_mode("practice")
		# Reproduce the same rim bounce and AI decision schedule at each tick
		# rate; start_mode deliberately seeds real matches from wall-clock time.
		game.rng.seed=7137
		game.set_drill("rim")
		game.players[0].position = Vector3(6,0,4)
		var caught = false
		var closest=INF
		var approach=""
		for f in range(int(fps*6)):
			game._physics_process(1.0/fps)
			var rival=game.players[1]
			if rival.action=="rebound" and rival.jump>.18:
				var distance=game.ball.position.distance_to(rival.rebound_anchor())
				if distance<closest:
					closest=distance
					approach="t=%.3f ball=%s root=%s hands=%s" % [rival.action_time,game.ball.position,rival.position,rival.skinned.palm_world]
			if game.players[1].defense_caught and game.players[1].jump>.18 and game.ball_owner==1:
				caught = true
				break
		check(caught,"AI airborne rebound missed at %dfps closest=%.3f %s" % [fps,closest,approach])
		if caught: ai_catches += 1
	var peaks: Array = []
	var drift: Array = []
	for role in ["guard","forward","center"]:
		game.start_mode("practice")
		game.set_court_role(role)
		game.set_drill("rebound")
		for f in range(6): game._physics_process(1.0/60)
		key(true)
		var caught_air = false
		for f in range(100):
			game._physics_process(1.0/60)
			caught_air = caught_air or (game.players[0].defense_caught and game.players[0].jump>.18)
		check(caught_air and game.ball_owner==0 and game.players[0].action=="idle","Role failed its actual air catch and landing: "+role)
		key(false)
		game.start_mode("practice")
		game.set_court_role(role)
		var p = game.players[0]
		p.prepare_defense("rebound",p.position+Vector3(0,3,.5))
		p.action_time = (p.DEFENSE_PLANT_TIME+p.defense_land_time())*.5
		peaks.append(p.defense_height())
		p.jump = 0
		p.position = Vector3(0,0,-4)
		p.boxing_out = true
		p.boxout_weight = 1
		p.has_ball = false
		game.players[1].position = Vector3(0,0,-3.3)
		game.players[1].has_ball = false
		game.ball_owner = -1
		game.separate_players()
		drift.append(p.position.distance_to(Vector3(0,0,-4)))
	check(peaks[2]>peaks[1] and peaks[1]>peaks[0],"Position rebound height advantages were not applied")
	check(drift[2]<drift[1] and drift[1]<drift[0],"Center and forward gained no box-out stability")
	game.start_mode("practice")
	game.set_court_role("center")
	game.players[0].prepare_defense("rebound",game.ball.position)
	game.set_court_role("guard")
	check(game.players[0].court_role=="center","Position changed jump height while airborne")
	game.start_mode("duel")
	game.set_court_role("guard")
	check(game.players[0].court_role=="center","Position switched during a live duel")
	print("RIM_BATTLE ordinary_misses=",misses," ai_air_catches=",ai_catches," role_peaks=",peaks," boxout_displacement=",drift," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
