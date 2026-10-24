extends SceneTree

var failures = 0
var samples = 0
var supported_samples = 0
var contact_events = 0
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
		for kind in ["rebound","block"]:
			for side in [-1.0,1.0]:
				game.start_mode("practice")
				game.set_drill(kind)
				var p = game.players[0]
				var target = p.position+Vector3(side*.20,2.6,-.32)
				p.facing = atan2(target.x-p.position.x,target.z-p.position.z)
				p.prepare_defense(kind,target)
				var trigger = .28 if side < 0 else .38
				var touched = false
				var contact_anchor = Vector3.ZERO
				var first_toe = Vector3.ZERO
				var first_recorded = false
				var pelvis_at_touch = 0.0
				var deepest = 1.0
				var single_support = 0
				for f in range(int(fps*(p.defense_duration()+.01))):
					p.action_time = f/float(fps)
					p.jump = p.defense_height()
					p.position = p.defense_position()
					p.animate(1.0/fps,p.action_time)
					if not touched and p.action_time >= trigger:
						touched = true
						contact_events += 1
						if kind == "rebound":
							p.has_ball = true
							p.capture_rebound(p.rebound_anchor(),Vector3(0,-3,0))
						else: p.record_block_contact()
						contact_anchor = p.hand_world
					if touched and p.action_time-trigger < .04 and kind == "block":
						check(p.hand_world.distance_to(contact_anchor) < .12,"Block jumped to a preset pose at contact")
					if p.action_time >= p.defense_land_time():
						var first = p.defense_land_first
						var toe = p.shoes[first].to_global(p.LAYUP_TOE)
						if not first_recorded:
							first_recorded = true
							first_toe = toe
							pelvis_at_touch = p.body.position.y
						check(toe.distance_to(first_toe) < .006,"Landing support toe slid or lifted")
						supported_samples += 1
						deepest = minf(deepest,p.body.position.y)
						if p.action_time < p.defense_touch_time(1-first):
							var other_toe = p.shoes[1-first].to_global(p.LAYUP_TOE)
							if other_toe.y > toe.y+.005: single_support += 1
					for i in range(2):
						check(p.shoes[i].to_global(p.LAYUP_TOE).y >= .099,"Toe penetrated the floor during landing")
						check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Landing shin stretched")
						check(absf(p.joint_knees[i].distance_to(p.joint_hips[i])-p.THIGH_LENGTH) < .0002,"Landing thigh stretched")
					if kind == "rebound" and p.defense_caught:
						check(p.ball_anchor(0).distance_to(p.rebound_anchor()) < .005,"Secured ball separated from grip")
						samples += 1
				check(single_support > 0,"Both feet still snapped down together")
				check(deepest < pelvis_at_touch-.10,"Knees compressed before contact instead of after it")
				check(p.body.position.y > deepest+.10,"Landing failed to recover from compression")
	print("CONTACT_LANDING catch/block events=",contact_events," grip_samples=",samples," supported_samples=",supported_samples," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
