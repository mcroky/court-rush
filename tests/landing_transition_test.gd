extends SceneTree

var failures = 0
var transitions = 0
var supported_samples = 0
var worst_support_drift = 0.0
var push_samples = 0
var scenario_context=""
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 15: push_error(message+" "+scenario_context)
func key(code: Key,down: bool) -> void:
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
	for fps in [30,60,120]:
		for kind in ["rebound","block"]:
			for scenario in ["left","right","forward","backward","diagonal","reverse","stop","guard","idle"]:
				scenario_context="fps=%d kind=%s scenario=%s" % [fps,kind,scenario]
				game.start_mode("practice")
				game.set_drill(kind)
				var p = game.players[0]
				for f in range(int(fps*.10)): game._physics_process(1.0/fps)
				if kind == "block":
					for f in range(int(fps*.34)): game._physics_process(1.0/fps)
				key(KEY_D,true)
				game._physics_process(1.0/fps)
				check(p.defensive_jump(),"D did not start the defensive jump")
				var land_time = p.defense_land_time()
				var support = p.defense_land_first
				var released = false
				var release_time = 0.0
				var release_position = Vector3.ZERO
				var support_position = Vector3.ZERO
				var first_step = false
				var last_height = p.body.position.y
				var peak_heel = 0.0
				var push_stalls = 0
				var opening_reach = 0.0
				var extended_reach = 0.0
				for f in range(int(fps*1.55)):
					var elapsed = (f+1)/float(fps)
					# Intent is present before contact; airborne motion must remain owned by the jump.
					if elapsed > land_time-.20:
						if kind=="block":
							# This fixture measures an unobstructed landing/first step.
							# A rival directly behind the landing point and a made-shot
							# dead-ball pause legitimately stop movement; tested elsewhere.
							game.players[1].position.x=3
							game.ai_freeze=10
							if game.phase=="flight":game.flight_made=false
						key(KEY_LEFT,scenario == "left" or (scenario == "reverse" and elapsed < land_time+.22))
						key(KEY_RIGHT,scenario in ["right","guard","diagonal"] or (scenario == "reverse" and elapsed >= land_time+.22) or (scenario == "stop" and elapsed < land_time+.20))
						key(KEY_UP,scenario in ["forward","diagonal"])
						key(KEY_DOWN,scenario == "backward")
						key(KEY_W,scenario == "guard")
					var previous_position = p.position
					game._physics_process(1.0/fps)
					if not released and not p.defensive_jump():
						released = true
						transitions += 1
						release_time = elapsed
						release_position = p.position
						support_position = p.shoes[support].to_global(p.LAYUP_TOE)
						check(elapsed >= land_time+.10,"Movement released before heel contact and absorption")
						if scenario != "idle":
							check(elapsed < land_time+.18,"Held movement still waits for the full recovery")
							check(p.motion.length() > .05,"Landing erased movement velocity")
					if released and p.landing_pose_left > 0:
						check(absf(p.body.position.y-last_height) < .070,"Pelvis snapped during the landing handoff")
					if released and p.landing_push_left > 0 and scenario in ["left","right","forward","backward","diagonal"]:
						var push_phase = p.landing_push_phase()
						if push_phase < 1:
							var heel = p.shoes[support].to_global(Vector3(0,0,-.15))
							var toe = p.shoes[support].to_global(p.LAYUP_TOE)
							peak_heel = maxf(peak_heel,heel.y-toe.y)
							var reach = p.joint_hips[support].distance_to(p.joint_ankles[support])
							if push_phase < .25: opening_reach = maxf(opening_reach,reach)
							if push_phase > .70: extended_reach = maxf(extended_reach,reach)
						if push_phase > .50 and push_phase < 1.35:
							if p.position.distance_to(previous_position)*fps < .10:
								push_stalls += 1
							push_samples += 1
					if released and p.landing_recovery_left > .03:
						if not first_step and (p.swinging[0] or p.swinging[1]):
							first_step = true
							check(p.swinging[1-support],"Loaded support foot lifted before the opening foot")
						if not p.swinging[support]:
							var drift = p.shoes[support].to_global(p.LAYUP_TOE).distance_to(support_position)
							worst_support_drift = maxf(worst_support_drift,drift)
							check(drift < .008,"Planted support slid during recovery")
							supported_samples += 1
						if elapsed-release_time > .11 and scenario not in ["stop","idle"]:
							check(p.position.distance_to(release_position) > .025,"Loaded leg failed to push into movement")
					check(not (p.swinging[0] and p.swinging[1]),"Both feet swung together on exit")
					for i in range(2):
						check(absf(p.joint_knees[i].distance_to(p.joint_hips[i])-p.THIGH_LENGTH) < .0002,"Recovery thigh stretched")
						check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Recovery shin stretched")
						if p.landing_recovery_left > 0: check(p.shoes[i].to_global(p.LAYUP_TOE).y > .098,"Recovery toe penetrated floor")
					last_height = p.body.position.y
				check(released and (first_step or scenario == "idle"),"Missing landing-to-step transition")
				if scenario in ["left","right","forward","backward","diagonal"]:
					check(peak_heel > .045,"Loaded foot failed to roll onto the forefoot")
					check(extended_reach > opening_reach+.015,"Support knee did not extend into the push")
					check(push_stalls == 0,"Root stopped between the push and receiving step")
				check(game.attempts == 0,"Held D triggered a shot after landing")
				if kind == "rebound": check(game.ball_owner == 0,"Recovery lost the secured rebound")
				for code in [KEY_D,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_W]: key(code,false)
	print("LANDING_TRANSITION transitions=",transitions," supported_samples=",supported_samples," push_samples=",push_samples," worst_support_drift=",worst_support_drift," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
