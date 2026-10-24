extends SceneTree

var failures = 0
var samples = 0
var opposition_samples = 0
var shoulder_samples = 0
var settled_cycles = 0
var peak_clearance_jump = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 12: push_error(message)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	# Use the actual actor/contact scheduler with straight running on open court;
	# no camera, opponent contact or loose-ball collection can mask limb timing.
	for fps in [30,60,120]:
		for ball in [false,true]:
			for foot in [0,1]:
				game.start_mode("practice")
				var p = game.players[0]
				p.position = Vector3.ZERO
				p.facing = 0
				p.rotation.y = 0
				p.has_ball = ball
				p.dribble_ended = false
				p.motion = Vector2(0,.75)
				p.feet_world.clear()
				p.animate(1.0/fps,0)
				p.prepare_defense("rebound" if ball else "block",Vector3(0,2.6,.2))
				p.defense_land_first = foot
				for f in range(int(fps*(p.defense_land_time()+.12))):
					p.action_time = f/float(fps)
					p.jump = p.defense_height()
					p.position = p.defense_position()
					p.animate(1.0/fps,p.action_time)
				if ball: p.capture_rebound(p.rebound_anchor(),Vector3.ZERO)
				p.finish_defense()
				var previous_serial = p.step_serial
				var peak_height = 0.0
				var peaks: Array = []
				var previous_upper = p.upper.rotation
				var previous_stride = p.stride
				var previous_hand_z = p.hands[0].position.z
				var mismatch = 0
				var observations = 0
				for f in range(int(fps*1.6)):
					var dt = 1.0/fps
					p.motion = p.motion.move_toward(Vector2(0,4.7*p.landing_speed_scale()),24*dt)
					p.position += p.movement_step(dt)
					p.animate(dt,f*dt)
					if p.step_serial != previous_serial:
						if previous_serial > p.run_entry_serial:
							if peaks.size() > 0:
								peak_clearance_jump = maxf(peak_clearance_jump,absf(peak_height-peaks[-1]))
								check(absf(peak_height-peaks[-1]) < .050,"Foot lift changed abruptly between entry strides")
							peaks.append(peak_height)
						peak_height = 0
						previous_serial = p.step_serial
					for i in range(2):
						peak_height = maxf(peak_height,p.shoes[i].global_position.y-.105)
						check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Run thigh stretched")
						check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Run shin stretched")
					check(absf(angle_difference(previous_stride,p.stride)) <= PI*dt/.12+.02,"Contact phase reset at a stride boundary")
					check(p.upper.rotation.distance_to(previous_upper) < .13,"Torso snapped between entry and running")
					check(not (p.swinging[0] and p.swinging[1]),"Running launched both feet together")
					if f*dt > .50 and p.run_swing_weight > .5:
						# Compare rendered limb placement, not the oscillator formula.
						var separation = (p.body.to_local(p.shoes[0].global_position)-p.body.to_local(p.shoes[1].global_position)).z
						var left_hand = p.hands[0].position.z
						if not ball and absf(separation) > .24:
							var arms = left_hand-p.hands[1].position.z
							if separation*arms > 0: mismatch += 1
							observations += 1
							opposition_samples += 1
							if absf(arms) > .15:
								check(p.upper.rotation.y*arms > 0,"Shoulders twist against the forward arm fps=%d f=%d torso=%.3f arms=%.3f" % [fps,f,p.upper.rotation.y,arms])
								shoulder_samples += 1
						if ball:
							check(absf(left_hand-previous_hand_z) < .25,"Free arm jumped while dribbling fps=%d f=%d step=%.3f diff=%.3f" % [fps,f,p.stride,absf(left_hand-previous_hand_z)])
					previous_hand_z = p.hands[0].position.z
					previous_stride = p.stride
					previous_upper = p.upper.rotation
					samples += 1
				check(peaks.size() >= 7,"Did not reach sustained running")
				check(observations == 0 or float(mismatch)/observations < .20,"Arms swing with the same-side leg rather than against it")
				settled_cycles += peaks.size()
	check(opposition_samples > 70 and shoulder_samples > 50,"Insufficient rendered limb timing coverage")
	print("RUN_RHYTHM frames=",samples," strides=",settled_cycles," opposition=",opposition_samples," shoulders=",shoulder_samples," peak_clearance_change=",peak_clearance_jump," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
