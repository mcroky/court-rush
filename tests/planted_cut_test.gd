extends SceneTree

var failures = 0
var cases = 0
var contacts = 0
var worst_slide = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 13: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for ball in [false,true]:
			for heading in [0.0,.85]:
				for degrees in [-135.0,-90.0,-45.0,-30.0,30.0,45.0,90.0,135.0,180.0]:
					game.start_mode("practice")
					var p = game.players[0]
					p.position = Vector3.ZERO
					p.facing = heading
					p.rotation.y = heading
					p.reset_stance()
					p.has_ball = ball
					p.dribble_hand = -1 if degrees < 0 else 1
					p.ball_side = p.dribble_hand
					p.feet_world.clear()
					p.animate(1.0/fps,0)
					var entry = Vector2(sin(heading),cos(heading))*4.7
					for f in range(int(fps*.44)):
						p.steer_motion(entry,24,1.0/fps)
						p.position += p.movement_step(1.0/fps)
						p.animate(1.0/fps,f/float(fps))
					var cut_yaw = heading+deg_to_rad(degrees)
					var desired = Vector2(sin(cut_yaw),cos(cut_yaw))*4.7
					var loaded = false
					var toes = p.skinned.toe_world.duplicate()
					var grounded = p.skinned.locked.duplicate()
					for f in range(int(fps*.95)):
						var dt = 1.0/fps
						p.steer_motion(desired,24,dt)
						p.position += p.movement_step(dt)
						p.facing = cut_yaw
						p.animate(dt,.44+f*dt)
						# A moving cut loads its existing support without halting
						# input until a separate stationary load state finishes.
						if p.skinned.locked[0] or p.skinned.locked[1]:loaded=true
						for i in range(2):
							var toe = p.skinned.toe_world[i]
							if grounded[i] and p.skinned.locked[i]:
								var drift = toe.distance_to(toes[i])
								worst_slide = maxf(worst_slide,drift)
								check(drift<.008,"Planted cut foot slid: angle=%.0f fps=%d hand=%s foot=%d frame=%d slide=%.4f state=%s" % [degrees,fps,ball,i,f,drift,p.brake_state])
								contacts += 1
							toes[i] = toe
							grounded[i] = p.skinned.locked[i]
						check(not (p.swinging[0] and p.swinging[1]),"Cut released both contacts together")
					check(loaded,"Moving cut omitted actual skinned support contact")
					check(p.motion.dot(desired.normalized())>4.0,"Cut did not drive into the new direction")
					cases += 1
	print("PLANTED_CUT cases=",cases," grounded_pairs=",contacts," worst_slide_m=",worst_slide," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
