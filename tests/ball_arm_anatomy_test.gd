extends SceneTree
## Inspect visible bones/palm frames during holding, dribbling, cuts and stops.
## Contact distance alone can pass while the wrist folds back over the forearm.
var failures = 0
var samples = 0
var min_wrist_alignment = 1.0
var min_elbow_forward = 0.0
var side_failures = 0
var maximum_stretch = 0.0
var maximum_elbow_speed = 0.0
func _init(): call_deferred("run")
func run():
	var p = load("res://scripts/actor.gd").new()
	root.add_child(p)
	p.setup(false)
	for fps in [30,60,120]:
		for height in [178,190,204]:
			for state in ["held","stationary","running"]:
				for hand in [-1.0,1.0]:
					p.apply_athlete({"role":{178:"guard",190:"forward",204:"center"}[height],"height":height})
					p.position = Vector3.ZERO
					p.facing = 0
					p.rotation.y = 0
					p.motion = Vector2.ZERO
					p.action = "idle"
					p.has_ball = true
					p.dribble_ended = state == "held"
					p.dribble_hand = hand
					p.ball_side = hand
					p.reset_stance()
					var low = 1.0
					var back = 0.0
					var lengths: Array = []
					var previous_elbows: Array = []
					for f in int(fps*3):
						var frame60 = f*60.0/fps
						p.facing = 0 if frame60 < 50 else PI*.5 if frame60 < 85 else -PI*.5 if frame60 < 125 else PI
						var velocity = Vector2(sin(p.facing),cos(p.facing))*4.2 if state == "running" else Vector2.ZERO
						if frame60 >= 125 and frame60 < 145: velocity = Vector2.ZERO
						p.steer_motion(velocity,24,1.0/fps)
						p.position += p.movement_step(1.0/fps)
						p.animate(1.0/fps,f/float(fps))
						if frame60 < 25: continue
						var v = p.skinned
						if lengths.is_empty():
							for chain in v.arms:
								lengths.append(Vector2(v.bone_world(chain[0]).origin.distance_to(v.bone_world(chain[1]).origin),v.bone_world(chain[1]).origin.distance_to(v.bone_world(chain[2]).origin)))
						for i in 2:
							var chain = v.arms[i]
							var shoulder = v.bone_world(chain[0]).origin
							var elbow = v.bone_world(chain[1]).origin
							var wrist = v.bone_world(chain[2]).origin
							var local_elbow = p.to_local(elbow)
							if previous_elbows.size() <= i: previous_elbows.append(local_elbow)
							var elbow_speed = local_elbow.distance_to(previous_elbows[i])*fps
							previous_elbows[i] = local_elbow
							maximum_elbow_speed=maxf(maximum_elbow_speed,elbow_speed)
							if elbow_speed > 12:
								failures += 1
								if failures < 3: print("ELBOW_SNAP ",elbow_speed)
							var fingers = p.palm_frame(i).y
							var forward = (wrist-elbow).normalized()
							var stretch = maxf(absf(shoulder.distance_to(elbow)-lengths[i].x),absf(elbow.distance_to(wrist)-lengths[i].y))
							maximum_stretch=maxf(maximum_stretch,stretch)
							if stretch > .004:
								failures += 1
								if failures < 3: print("BONE_LENGTH_CHANGED ",stretch)
							var alignment = forward.dot(fingers)
							low = minf(low,alignment)
							back = minf(back,(elbow-shoulder).dot(v.chest_motion_frame().z))
							if (elbow-shoulder).dot(v.chest_motion_frame().z) < -.12*p.height_ratio:
								side_failures += 1
								if side_failures < 4: print("SIDE_ELBOW state=",state," height=",height," frame=",f," hand=",i," back=",(elbow-shoulder).dot(v.chest_motion_frame().z))
							if not wrist.is_finite() or not elbow.is_finite() or alignment < .05:
								failures += 1
								if failures < 3: print("REVERSE_WRIST state=",state," height=",height," hand=",i," frame=",f," alignment=",alignment," shoulder=",p.to_local(shoulder)," elbow=",p.to_local(elbow)," wrist=",p.to_local(wrist)," palm=",p.to_local(p.palm_position(i))," phase=",fposmod(p.dribble_phase,TAU)/TAU)
							samples += 1
					min_wrist_alignment = minf(min_wrist_alignment,low)
					min_elbow_forward = minf(min_elbow_forward,back)
					print("ARM_PROFILE ",height," ",state," hand=",hand," wrist_dot=",low," elbow_back=",back)
	print("BALL_ARM_ANATOMY samples=",samples," min_alignment=",min_wrist_alignment," min_elbow_forward=",min_elbow_forward," max_stretch=",maximum_stretch," max_elbow_speed=",maximum_elbow_speed," side_failures=",side_failures," failures=",failures)
	quit(1 if failures or side_failures else 0)
