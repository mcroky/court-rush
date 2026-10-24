extends SceneTree
var failures = 0
var cases = 0
var planted_samples = 0
var worst_slide = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 16: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for moving in [false,true]:
				game.start_mode("duel")
				var p = game.players[1]
				game.players[0].position = Vector3(0,0,1)
				p.position = Vector3(0,0,-.3)
				p.facing = 0
				p.rotation.y = 0
				p.defending = true
				p.feet_world.clear()
				for f in range(int(fps*.22)):
					p.motion = Vector2(side*1.6,0) if moving else Vector2.ZERO
					p.position += p.movement_step(1.0/fps)
					p.animate(1.0/fps, f/float(fps))
				game.crossover(Vector2(side,0))
				check(p.get("chase_recovery") == true,"Crossover recovery has no planted motion state")
				if p.get("chase_recovery") != true: continue
				var loaded = false
				var turned = false
				var pushed = false
				var finished = false
				var load_time = 0.0
				var chest_turn = 0.0
				var brace_height = p.body.position.y
				var toes = [p.shoes[0].to_global(p.LAYUP_TOE),p.shoes[1].to_global(p.LAYUP_TOE)]
				var grounded = [not p.swinging[0],not p.swinging[1]]
				var origin_yaw = p.rotation.y
				for f in range(int(fps*1.7)):
					var dt = 1.0/fps
					game.players[0].position += Vector3(side*.8,0,-3.8)*dt
					game.ai_reaction = maxf(0,game.ai_reaction-dt)
					game.ai_reaction_cooldown = maxf(0,game.ai_reaction_cooldown-dt)
					game.ai_freeze = 0
					game.update_ai(dt)
					p.animate(dt,.22+f*dt)
					if p.brake_state == "load":
						loaded = true
						load_time += dt
						brace_height = minf(brace_height,p.body.position.y)
						check(p.motion.length()<1.1,"Loaded foot immediately accelerated into pursuit")
					if not loaded: check(absf(angle_difference(origin_yaw,p.rotation.y))<.04,"Defender spun before its misstep landed")
					if p.brake_state == "settle":
						turned = true
						chest_turn = maxf(chest_turn,absf(p.upper.rotation.y))
						check(loaded,"Defender turned before accepting its weight")
					if p.brake_state == "push":
						pushed = true
						check(turned,"Pursuit skipped the planted turn")
					if p.chase_recovery: check(not game.ai_can_attempt_block(),"Recovering defender auto-blocked")
					check(not(p.swinging[0] and p.swinging[1]),"Recovery released both feet together")
					for i in range(2):
						var toe = p.shoes[i].to_global(p.LAYUP_TOE)
						if grounded[i] and not p.swinging[i]:
							var drift = toe.distance_to(toes[i])
							worst_slide = maxf(worst_slide,drift)
							check(drift<.008,"Recovery support slid %.4fm (%dfps %s)" % [drift,fps,p.brake_state])
							planted_samples += 1
						toes[i] = toe
						grounded[i] = not p.swinging[i]
						check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH)<.0002,"Recovery thigh stretched")
						check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH)<.0002,"Recovery shin stretched")
					if not p.chase_recovery and pushed:
						finished = true
						break
				check(loaded and turned and pushed and finished,"Missing recovery phase or chase stalled")
				check(load_time>=.065,"Defender did not visibly absorb its false step")
				check(brace_height<-.24,"Recovery did not bend the supporting knee")
				check(chest_turn>.06,"Recovery torso stayed rigid during its turn")
				check(p.motion.length()>1.5,"Defender failed to accelerate back into pursuit")
				cases += 1
	check(cases==12,"Missing recovery scenarios")
	# Pause must preserve a defender already accepting weight, without restarting it.
	game.start_mode("practice")
	game.set_drill("recovery")
	game.crossover(Vector2.RIGHT)
	for f in range(10): game._physics_process(1.0/60)
	var rival = game.players[1]
	check(rival.chase_recovery,"Pause scenario did not enter an actual recovery")
	game.ai_reaction_cooldown = 0
	var recovery_age = rival.chase_recovery_time
	game.defender_feint(Vector3.RIGHT)
	check(rival.chase_recovery_time==recovery_age,"Repeated feint restarted an unfinished recovery")
	var frozen = [rival.chase_recovery_time,rival.position,rival.feet_world.duplicate(),rival.rotation.y]
	game.set_paused(true)
	for f in range(24): game._physics_process(1.0/60)
	check(frozen==[rival.chase_recovery_time,rival.position,rival.feet_world.duplicate(),rival.rotation.y],"Paused recovery kept advancing")
	game.set_paused(false)
	game.reset_positions(0)
	check(not rival.chase_recovery,"Possession reset retained a stale recovery")
	print("CHASE_RECOVERY cases=",cases," planted_samples=",planted_samples," worst_slide_m=",worst_slide," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
