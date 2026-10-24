extends SceneTree

var failures = 0
var contacts = 0
var samples = 0
var rolling_samples = 0
var visible_release_samples=0
var max_palm_speed=0.0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 8: push_error(message)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30, 60, 120]:
		for hand in [-1.0, 1.0]:
			game.start_mode("practice")
			var p = game.players[0]
			p.position = Vector3(hand * .7, 0, -3.0)
			p.dribble_hand = hand
			p.motion = Vector2(0,-3.5)
			p.feet_world.clear()
			p.animate(1.0/fps, 0)
			game.begin_gather(0)
			for f in range(int(fps*.20)):
				p.action_time = float(f)/fps
				p.position.z -= 2.1/fps
				p.animate(1.0/fps, p.action_time)
			var before_y = p.body.global_position.y
			game.launch_shot(0)
			var plant = p.layup_plant_index
			var anchor = p.layup_plant_anchor
			var entry = p.gather_velocity()
			p.action_time = .0001
			var entry_velocity = (p.finish_position()-p.air_start)/.0001
			check(entry_velocity.distance_to(Vector3(entry.x,0,entry.y)) < .02, "Running speed broke at gather-to-push transition")
			p.action_time = 0
			check((plant == 0 and p.dribble_hand > 0) or (plant == 1 and p.dribble_hand < 0), "Takeoff must oppose shooting hand")
			var previous_palms=[p.to_local(p.palm_position(0)),p.to_local(p.palm_position(1))]
			var previous_frames=[p.palm_frame(0).get_rotation_quaternion(),p.palm_frame(1).get_rotation_quaternion()]
			for frame in range(int(fps*.84)):
				game._physics_process(1.0/fps)
				if p.action != "layup": break
				var t = p.action_time
				if frame == 0: check(absf(p.body.global_position.y-before_y) < .055, "Pelvis popped up at launch")
				if t <= p.LAYUP_PLANT_TIME:
					check(p.jump == 0, "Body rose before plant extension")
					if t >= .04:
						# Heel lift is intentional: the forefoot, not the shoe origin, stays fixed.
						var toe = p.shoes[plant].to_global(p.LAYUP_TOE)
						var ground_toe = anchor + Basis(Vector3.UP,p.layup_plant_yaw) * p.LAYUP_TOE * p.VISUAL_SCALE
						check(toe.distance_to(ground_toe) < .006, "Forefoot slipped during push-off")
						if t >= .07:
							var heel = p.shoes[plant].to_global(Vector3(0,0,-.12))
							check(heel.y > toe.y + .035, "Heel did not roll above the planted forefoot")
							rolling_samples += 1
					contacts += 1
				if t > .20 and t < .40:
					check(p.shoes[1-plant].position.y > p.shoes[plant].position.y + .10, "Both legs used the same jump pose")
				for i in range(2):
					var local_palm=p.to_local(p.palm_position(i))
					var palm_speed=local_palm.distance_to(previous_palms[i])*fps
					max_palm_speed=maxf(max_palm_speed,palm_speed)
					check(palm_speed<12,"Visible layup arm jumped fps=%d t=%.3f hand=%d speed=%.2f" % [fps,t,i,palm_speed])
					check(p.palm_frame(i).get_rotation_quaternion().angle_to(previous_frames[i])<14.0/fps,"Visible layup wrist snapped fps=%d t=%.3f hand=%d rate=%.2f" % [fps,t,i,p.palm_frame(i).get_rotation_quaternion().angle_to(previous_frames[i])*fps])
					previous_palms[i]=local_palm
					previous_frames[i]=p.palm_frame(i).get_rotation_quaternion()
					check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002, "Thigh stretched during takeoff")
					check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002, "Shin stretched during takeoff")
				samples += 1
				if t>=.30 and t<=.34:
					var shooter=1 if p.dribble_hand>0 else 0
					var v=p.skinned
					check(p.palm_frame(shooter).z.dot(Vector3.UP)>.65,"Layup wrist failed to support ball before finger roll")
					check(p.palm_position(shooter).y>v.bone_world(v.skeleton.find_bone("head")).origin.y+.12,"Layup released before extending above face fps=%d t=%.3f head=%.3f palm=%.3f" % [fps,t,v.bone_world(v.skeleton.find_bone("head")).origin.y,p.palm_position(shooter).y])
					check(p.palm_position(shooter).distance_to(p.palm_position(1-shooter))>.24,"Guide hand did not peel away for one-handed layup")
					check(v.arm_errors[shooter]<.03,"Layup palm target exceeded actual arm reach")
					visible_release_samples+=1
	check(contacts > 20, "No planted takeoff intervals were checked")
	check(rolling_samples > 10, "No heel-to-toe push-off intervals were checked")
	# The upward speed comes from leg extension, with no velocity jump at liftoff.
	var p = game.players[0]
	p.layup_load = .20
	p.action_time = p.LAYUP_PLANT_TIME-.0001
	var low = p.layup_pelvis_height()
	p.action_time = p.LAYUP_PLANT_TIME
	var middle = p.layup_pelvis_height()
	var high = p.layup_height(p.LAYUP_PLANT_TIME+.0001)
	check(absf((middle-low)/.0001 - (high-middle)/.0001) < .02, "Vertical push velocity jumped at toe-off")
	check(visible_release_samples>=12,"Missing actual layup release coverage")
	print("LAYUP_TAKEOFF fps=30/60/120 both_hands samples=",samples," contact_samples=",contacts," rolling_samples=",rolling_samples," visible_release_samples=",visible_release_samples," max_palm_speed=",max_palm_speed," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
