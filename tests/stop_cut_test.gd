extends SceneTree

var failures = 0
var cases = 0
var support_samples = 0
var worst_drift = 0.0
var longest_stop = 0.0
var receiving_samples = 0
var relaunches = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 14: push_error(message)

func pelvis_height(p) -> float:
	return p.skinned.bone_world(p.skinned.skeleton.find_bone("pelvis")).origin.y

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for ball in [false,true]:
			for entry in [.33,.40,.47,.54]:
				# Full braking applies to released input. Moving cuts are covered by
				# cut_response and actual skinned contact tests, without a stop gate.
				for cut in [Vector2.ZERO]:
					game.start_mode("practice")
					var p = game.players[0]
					p.position = Vector3.ZERO
					p.rotation.y = 0
					p.facing = 0
					p.has_ball = ball
					p.dribble_ended = false
					p.feet_world.clear()
					p.animate(1.0/fps,0)
					for f in range(int(fps*entry)):
						p.steer_motion(Vector2(0,4.7),24,1.0/fps)
						p.position += p.movement_step(1.0/fps)
						p.animate(1.0/fps,f/float(fps))
					var start = p.position
					var start_height = pelvis_height(p)
					var lowest = start_height
					var had_load = false
					var had_push = false
					var anchor = Vector3.ZERO
					var anchored = false
					var stop_time = -1.0
					var old_height = start_height
					var contact_advances: Array = []
					var checkpoint = Vector3.ZERO
					var received_toe = Vector3.ZERO
					var had_receiver = false
					var stalls = 0
					for f in range(int(fps*.90)):
						var dt = 1.0/fps
						p.steer_motion(cut,24 if cut.length() > 0 else 35,dt)
						if p.brake_state == "push" and not had_push: checkpoint = p.position
						var before_move = p.position
						p.position += p.movement_step(dt)
						if cut.length() > 0: p.facing = atan2(cut.x,cut.y)
						p.animate(dt,entry+f*dt)
						if p.brake_state == "load": had_load = true
						if p.brake_state == "push":
							had_push = true
							check(had_load,"Cut pushed before receiving a braking contact")
						if had_push and contact_advances.size() < 3:
							var completed = p.step_serial-p.restart_serial
							if completed >= 1 and completed <= 3 and not p.swinging[p.last_step] and contact_advances.size() < completed:
								contact_advances.append((p.position-checkpoint).dot(Vector3(cut.x,0,cut.y).normalized()))
								checkpoint = p.position
							if not had_receiver and p.brake_state == "receive":
								had_receiver = true
								received_toe = p.shoes[1-p.brake_foot].to_global(p.LAYUP_TOE)
							if had_receiver and p.brake_state == "receive":
								check(p.shoes[1-p.brake_foot].to_global(p.LAYUP_TOE).distance_to(received_toe) < .008,"Receiving forefoot slid during the second push")
								receiving_samples += 1
							if p.restart_left > 0 and p.restart_phase() > .35 and p.position.distance_to(before_move)*fps < .1:
								print("STALL fps=",fps," ball=",ball," entry=",entry," cut=",cut," f=",f," phase=",p.restart_phase()," state=",p.brake_state," height=",p.body.position.y," pitch=",p.body.rotation.x," swing=",p.swinging," progress=",p.swing_progress)
								stalls += 1
						if p.brake_state in ["load","settle","push"] and not p.swinging[p.brake_foot]:
							var toe = p.shoes[p.brake_foot].to_global(p.LAYUP_TOE)
							if not anchored:
								anchor = toe
								anchored = true
							var drift = toe.distance_to(anchor)
							worst_drift = maxf(worst_drift,drift)
							check(drift < .008,"Braking support toe dragged across court")
							support_samples += 1
						if p.brake_state in ["plant","load"]:
							check(absf(angle_difference(0,p.rotation.y)) < .01,"Body turned before braking contact absorbed the momentum")
						if p.motion.length() < .35 and stop_time < 0: stop_time = f*dt
						lowest = minf(lowest,pelvis_height(p))
						check(absf(pelvis_height(p)-old_height) < .075,"Visible braking pelvis popped fps=%d ball=%s f=%d y=%.3f prev=%.3f" % [fps,ball,f,pelvis_height(p),old_height])
						old_height = pelvis_height(p)
						check(not (p.swinging[0] and p.swinging[1]),"Cut launched both legs")
						for i in range(2):
							check(p.shoes[i].global_position.y > .094,"Braking foot penetrated court")
							check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Cut thigh stretched")
							check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Cut shin stretched")
					check(had_load and anchored,"Missing planted brake")
					check(lowest < start_height-.035,"Visible knees did not absorb stop fps=%d ball=%s entry=%.2f start=%.3f low=%.3f" % [fps,ball,entry,start_height,lowest])
					check(stop_time >= 0 and stop_time < .30,"Stop/cut delayed input excessively")
					if cut == Vector2.ZERO:
						longest_stop = maxf(longest_stop,p.position.distance_to(start))
						check(p.position.distance_to(start) < .70,"Stop drifted too far")
						check(p.motion.length() < .01 and p.brake_state == "","Stop failed to settle")
					else:
						check(had_push and p.motion.dot(cut.normalized()) > 4,"Cut failed to accelerate in the requested direction")
						check(had_receiver and contact_advances.size() == 3,"Cut skipped a receiving contact or three-stride handoff")
						if contact_advances.size() == 3:
							check(contact_advances[1] > contact_advances[0]+.025,"Second stride did not grow from the short receiving step")
							check(contact_advances[2] > contact_advances[1]+.025,"Third stride did not grow into running")
						check(stalls == 0,"Relaunch stopped between support exchanges")
						relaunches += 1
					check(not p.dribble_ended,"Stop/cut gathered the ball or ended a valid dribble")
					cases += 1
	print("STOP_CUT cases=",cases," relaunches=",relaunches," supported_samples=",support_samples," receiving_samples=",receiving_samples," worst_toe_drift=",worst_drift," longest_stop_m=",longest_stop," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
