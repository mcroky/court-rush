extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("duel")
	game.players[0].position = Vector3(0,0,-4)
	game.players[1].position = Vector3(0,0,-2.8)
	game.ai_freeze = 0
	game.ai_reaction = .18
	game.ai_reaction_cooldown = .7
	check(not game.ai_can_attempt_block(),"Wrong-footed defender skipped its recovery to block")
	game.ai_reaction = 0
	check(not game.ai_can_attempt_block(),"Beaten defender auto-blocked from behind at full reach")
	game.players[1].position.z = -4.8
	check(game.ai_can_attempt_block(),"Defender with inside position lost its legal block")
	game.players[1].position.z = -3.5
	game.ai_reaction_cooldown = 0
	check(game.ai_can_attempt_block(),"Nearby recovered defender cannot attempt a legitimate chase block")
	var p = game.players[1]
	p.position = Vector3.ZERO
	p.defense_yaw = 0
	p.hand_world = Vector3(0,2.6,.45)
	game.ball.position = Vector3(0,2.6,-.4)
	check(not game.block_lane_open(p),"Block reached behind a locked jump direction")
	game.ball.position = Vector3(0,2.6,1.3)
	check(not game.block_lane_open(p),"Block exceeded actual horizontal reach")
	game.players[0].position = Vector3(0,0,2)
	game.ball.position = Vector3(0,2.6,.6)
	game.shooter = 0
	check(game.block_lane_open(p),"Frontal palm contact was rejected")
	game.players[0].position = Vector3(0,0,.35)
	game.players[0].body.position = Vector3.ZERO
	p.hand_world = Vector3(0,1.45,0)
	game.ball.position = Vector3(0,1.5,.7)
	check(not game.block_lane_open(p),"Blocking arm passed through the shooter's torso")
	# Exercise the actual AI decision branch across random seeds and tick rates.
	var decision_cases = 0
	var legal_attempts = 0
	for fps in [30,60,120]:
		for seed_value in range(1,33):
			for recovering in [true,false]:
				game.start_mode("duel")
				game.rng.seed = seed_value
				game.players[0].position = Vector3(0,0,-4)
				game.players[1].position = Vector3(0,0,-2.8)
				game.phase = "takeoff"
				game.shooter = 0
				game.ball_owner = -1
				game.ai_decision = 0
				game.ai_freeze = 0
				game.ai_reaction = .18 if recovering else 0.0
				game.ai_reaction_cooldown = .7
				game.update_ai(1.0/fps)
				decision_cases += 1
				check(game.players[1].action != "block","AI jumped straight through a beaten/recovering state")
			game.players[1].position = Vector3(0,0,-4.8)
			game.ai_reaction = 0
			game.ai_reaction_cooldown = 0
			game.ai_decision = 0
			game.update_ai(1.0/fps)
			if game.players[1].action == "block": legal_attempts += 1
	check(legal_attempts>0,"Actual AI branch never attempted a legal inside block")
	print("CHASE_BLOCK recovery, inside position, reach, front arc, body shield decision_cases=",decision_cases," legal_attempts=",legal_attempts," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
