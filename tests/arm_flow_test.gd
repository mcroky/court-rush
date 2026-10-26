extends SceneTree

var failures = 0
var samples = 0
var opposed = 0
var wrong_phase = 0
var max_elbow_width = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 10: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			game.start_mode("practice")
			var p = game.players[0]
			p.position = Vector3.ZERO
			p.facing = 0
			p.rotation.y = 0
			p.reset_stance()
			p.has_ball = true
			p.dribble_hand = side
			p.ball_side = side
			var free = 0 if side > 0 else 1
			var last_elbows = [Vector3.ZERO,Vector3.ZERO]
			var lengths=[]
			var swing_samples: Array = []
			for f in range(int(fps*2.4)):
				p.motion = Vector2(0,4.2)
				p.position += p.movement_step(1.0/fps)
				p.animate(1.0/fps,f/float(fps))
				var v=p.skinned
				# Bind-bone axes point diagonally down/forward in this source.
				# Measure swing in visible shoulder heading and world gravity.
				var chest=Transform3D(v.chest_motion_frame(),v.bone_world(v.skeleton.find_bone("spine_02")).origin)
				var current=[]
				for chain in v.arms:
					current.append([v.bone_world(chain[0]).origin.distance_to(v.bone_world(chain[1]).origin),v.bone_world(chain[1]).origin.distance_to(v.bone_world(chain[2]).origin)])
				if lengths.is_empty():lengths=current
				if f < fps*.6:
					for i in 2:last_elbows[i]=p.to_local(v.bone_world(v.arms[i][1]).origin)
					continue
				for i in range(2):
					var sign_side = -1.0 if i == 0 else 1.0
					var elbow = chest.affine_inverse()*v.bone_world(v.arms[i][1]).origin
					max_elbow_width = maxf(max_elbow_width,elbow.x*sign_side)
					check(elbow.x*sign_side < .47,"Running elbow flared away from ribs")
					var local_elbow=p.to_local(v.bone_world(v.arms[i][1]).origin)
					check(local_elbow.distance_to(last_elbows[i]) < 6.0/fps,"Visible elbow plane snapped: fps=%d hand=%d frame=%d phase=%.3f speed=%.3f ball_side=%.0f" % [fps,i,f,fposmod(p.dribble_phase,TAU)/TAU,local_elbow.distance_to(last_elbows[i])*fps,side])
					check(absf(current[i][0]-lengths[i][0])<.004,"Actual upper arm stretched")
					check(absf(current[i][1]-lengths[i][1])<.004,"Actual forearm stretched")
					last_elbows[i] = local_elbow
				var forearm = (v.bone_world(v.arms[free][2]).origin-v.bone_world(v.arms[free][1]).origin).normalized()
				var free_frame=v.bone_world(v.arms[free][2]).basis.orthonormalized()*v.palm_frames[free]
				check(free_frame.y.dot(forearm)>.85,"Visible free wrist did not continue from forearm dot=%.3f" % free_frame.y.dot(forearm))
				var phase = fposmod(p.dribble_phase,TAU)/TAU
				if phase < .20 or phase > .94:
					var frame=v.bone_world(v.arms[1-free][2]).basis.orthonormalized()*v.palm_frames[1-free]
					check(frame.z.dot(Vector3.DOWN)>.50,"Visible dribble palm was not above ball")
				var leg = p.to_local(v.toe_world[free])-p.to_local(v.toe_world[1-free])
				var wrist=chest.affine_inverse()*v.palm_world[free]
				var shoulder=chest.affine_inverse()*v.bone_world(v.arms[free][0]).origin
				if absf(leg.z) > .20:
					swing_samples.append(Vector2(leg.z,wrist.z-shoulder.z))
				samples += 1
			# Judge timing around the observed protective-hand position. The
			# previous hardcoded17cm offset misclassified a forward balance pose
			# as a phase error even when the wrist followed the opposite foot.
			var minimum = INF
			var maximum = -INF
			for sample in swing_samples:
				minimum = minf(minimum,sample.y)
				maximum = maxf(maximum,sample.y)
			check(maximum-minimum>.10,"Free arm stopped counter-swinging")
			for sample in swing_samples:
				opposed += 1
				if sample.x*(sample.y-(minimum+maximum)*.5)>0: wrong_phase += 1
	check(opposed > 100 and float(wrong_phase)/maxi(opposed,1) < .12,"Free arm lagged the opposite foot rhythm")
	print("ARM_FLOW frames=",samples," opposition_samples=",opposed," mismatches=",wrong_phase," max_elbow_lateral=",max_elbow_width," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
