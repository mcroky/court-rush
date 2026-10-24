extends SceneTree

var failures = 0
var contacts = 0
var cycles = 0
var follow_through = 0
var max_hand_speed = 0.0
var max_elbow_raise = -100.0
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
	for fps in [30,60,120]:
		for speed in [0.0,4.2]:
			for side in [-1.0,1.0]:
				game.start_mode("practice")
				var p = game.players[0]
				p.position = Vector3.ZERO
				p.rotation.y = 0
				p.facing = 0
				p.reset_stance()
				p.has_ball = true
				p.dribble_hand = side
				p.ball_side = side
				p.dribble_phase = 0
				var lowest = 100.0
				var highest = -100.0
				var low_yaw = 100.0
				var high_yaw = -100.0
				var previous_palm=Vector3.ZERO
				for f in range(int(fps*2.2)):
					p.motion = Vector2(0,speed)
					p.position += p.movement_step(1.0/fps)
					p.animate(1.0/fps,f/float(fps))
					var ball = p.ball_anchor(0)
					var visible_local=p.to_local(p.palm_position(1 if side>0 else 0))
					var hand_speed=visible_local.distance_to(previous_palm)*fps
					previous_palm=visible_local
					if f < int(fps*.5): continue
					var phase = fposmod(p.dribble_phase,TAU)/TAU
					var h = p.hands[1 if side > 0 else 0]
					var palm=p.palm_position(1 if side>0 else 0)
					var v=p.skinned
					var chain=v.arms[1 if side>0 else 0]
					var shoulder=v.bone_world(chain[0]).origin
					var elbow=v.bone_world(chain[1]).origin
					max_elbow_raise=maxf(max_elbow_raise,elbow.y-shoulder.y)
					max_hand_speed=maxf(max_hand_speed,hand_speed)
					check(elbow.y<shoulder.y-.17,"Dribbling elbow lifted toward shoulder instead of staying beside ribs")
					check(hand_speed<4.0,"Visible dribble hand jumped between loop phases speed=%.3f" % hand_speed)
					if phase>.26 and phase<.35:
						check(palm.y<p.bounce_height(.18)+p.DRIBBLE_PALM-.04,"Hand retracted upward immediately after releasing ball")
						follow_through+=1
					lowest = minf(lowest,palm.y)
					highest = maxf(highest,palm.y)
					low_yaw = minf(low_yaw,p.upper.rotation.y)
					high_yaw = maxf(high_yaw,p.upper.rotation.y)
					if phase < .18 or phase > .90:
						check(palm.distance_to(ball+Vector3.UP*p.DRIBBLE_PALM) < .03,"Visible push/receive palm gap=%.3f fps=%d speed=%.1f phase=%.3f target=%s palm=%s root=%.3f error=%.3f" % [palm.distance_to(ball+Vector3.UP*p.DRIBBLE_PALM),fps,speed,phase,ball+Vector3.UP*p.DRIBBLE_PALM,palm,p.skinned.model.position.y,p.skinned.arm_errors[1 if side>0 else 0]])
						contacts += 1
					check(ball.y >= p.DRIBBLE_FLOOR-.001,"Dribble penetrated floor")
					if phase > .48 and phase < .90: check(palm.y > ball.y,"Visible receiving palm went under ball (carrying)")
				# World metres on the visible rig, rather than hidden body units.
				check(highest-lowest > .15,"Visible palm missed its18cm pressing stroke fps=%d speed=%.1f side=%.0f range=%.3f" % [fps,speed,side,highest-lowest])
				if speed > 0: check(high_yaw-low_yaw > .14,"Running dribbler's torso remained too fixed")
				cycles += 1
	check(follow_through>30,"Missing visible follow-through samples")
	print("DRIBBLE_FEEL cases=",cycles," push_receive_samples=",contacts," follow_through_samples=",follow_through," max_hand_speed=",max_hand_speed," max_elbow_raise=",max_elbow_raise," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
