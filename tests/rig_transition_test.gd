extends SceneTree
var failures = 0
var cases = 0
var supports = 0
var worst_slide = 0.0
var worst_hand_speed = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures<18: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for ball in [false,true]:
			for angle in [-PI*.5,PI*.5,PI]:
				game.start_mode("practice")
				var p = game.players[0]
				p.position = Vector3.ZERO
				p.rotation.y = 0
				p.facing = 0
				p.has_ball = ball
				p.reset_stance()
				p.feet_world.clear()
				p.animate(1.0/fps,0)
				for f in range(int(fps*.6)):
					p.steer_motion(Vector2(0,4.7),24,1.0/fps)
					p.position += p.movement_step(1.0/fps)
					p.animate(1.0/fps,f/float(fps))
				var desired = Vector2(sin(angle),cos(angle))*4.7
				var old_toes = p.skinned.toe_world.duplicate()
				var old_locked = p.skinned.locked.duplicate()
				var old_palms = p.skinned.palm_world.duplicate()
				for f in range(int(fps*1.1)):
					var dt = 1.0/fps
					p.steer_motion(desired,24,dt)
					p.position += p.movement_step(dt)
					p.facing = angle
					p.animate(dt,.6+f*dt)
					for i in range(2):
						if old_locked[i] and p.skinned.locked[i] and not p.swinging[i]:
							var slide = p.skinned.toe_world[i].distance_to(old_toes[i])
							worst_slide = maxf(worst_slide,slide)
							check(slide<.012,"Skinned cut support slid %.3fm (f=%d foot=%d %dfps angle=%.2f ball=%s %s) old=%s now=%s anchor=%s height=%.3f" % [slide,f,i,fps,angle,ball,p.brake_state,str(old_toes[i]),str(p.skinned.toe_world[i]),str(p.skinned.anchors[i]),p.skinned.model.position.y])
							supports += 1
						var hand_speed = p.skinned.palm_world[i].distance_to(old_palms[i])/dt
						worst_hand_speed = maxf(worst_hand_speed,hand_speed)
						check(hand_speed<15,"Skinned arm snapped %.2fm/s f=%d fps=%d ball=%s hand=%d state=%s height=%.3f ik_error=%.3f weight=%.3f" % [hand_speed,f,fps,ball,i,p.brake_state,p.skinned.model.position.y,p.skinned.arm_errors[i],p.skinned.arm_weight[i]])
					old_toes = p.skinned.toe_world.duplicate()
					old_locked = p.skinned.locked.duplicate()
					old_palms = p.skinned.palm_world.duplicate()
				check(p.motion.dot(desired.normalized())>4,"Skinned cut stalled the actual player")
				cases += 1
	# Real AI recovery uses the same visible skeleton, then returns to run clips.
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			game.start_mode("duel")
			game.players[0].position = Vector3(0,0,1)
			var rival = game.players[1]
			rival.position = Vector3(0,0,-.3)
			rival.rotation.y = 0
			rival.facing = 0
			rival.defending = true
			rival.feet_world.clear()
			for f in range(int(fps*.3)): rival.animate(1.0/fps,f/float(fps))
			game.crossover(Vector2(side,0))
			check(rival.chase_recovery,"Visible AI never entered recovery")
			var previous_toes = rival.skinned.toe_world.duplicate()
			var previous_locks = rival.skinned.locked.duplicate()
			var ran = false
			for f in range(int(fps*1.7)):
				var dt = 1.0/fps
				game.players[0].position += Vector3(side*.8,0,-3.8)*dt
				game.ai_reaction = maxf(0,game.ai_reaction-dt)
				game.ai_reaction_cooldown = maxf(0,game.ai_reaction_cooldown-dt)
				game.ai_freeze = 0
				game.update_ai(dt)
				rival.animate(dt,.3+f*dt)
				if not rival.chase_recovery and rival.skinned.clip=="run": ran = true
				check(rival.skinned.model.position.y>=-.325,"Recovery collapsed the skinned pelvis")
				for i in range(2):
					if previous_locks[i] and rival.skinned.locked[i]:
						var slide = rival.skinned.toe_world[i].distance_to(previous_toes[i])
						worst_slide = maxf(worst_slide,slide)
						check(slide<.012,"Actual chasing skin foot slid %.3fm f=%d foot=%d fps=%d state=%s height=%.3f anchor=%s now=%s old=%s" % [slide,f,i,fps,rival.brake_state,rival.skinned.model.position.y,str(rival.skinned.anchors[i]),str(rival.skinned.toe_world[i]),str(previous_toes[i])])
					previous_toes[i] = rival.skinned.toe_world[i]
					previous_locks[i] = rival.skinned.locked[i]
			check(ran,"Recovered AI never resumed its authored running clip")
	print("RIG_TRANSITION cases=",cases," supports=",supports," worst_slide=",worst_slide," max_hand_speed=",worst_hand_speed," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
