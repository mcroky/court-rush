extends SceneTree

var failures = 0
var contacts = 0
var frames = 0
var worst_slide = 0.0
var longest_step = 0.0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 10: push_error(message)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for speed in [1.7,2.7,3.7]:
			for turn in [0.0,.65]:
				game.start_mode("duel")
				var p = game.players[0]
				p.position = Vector3.ZERO
				p.rotation.y = 0
				p.facing = 0
				p.has_ball = false
				p.defending = true
				p.boxing_out = speed == 1.7
				p.feet_world.clear()
				for f in range(fps): p.animate(1.0/fps,f/float(fps))
				var elapsed = 1.0
				var segments = [[Vector2.RIGHT,.75],[Vector2.ZERO,.18],[Vector2.LEFT,.75],[Vector2.RIGHT,.75],[Vector2(1,1).normalized(),.3],[Vector2(0,-1),.3],[Vector2.ZERO,.5]]
				for segment in segments:
					var origin = p.position
					var direction: Vector2 = segment[0]
					var ideal = 0.0
					for f in range(int(fps*segment[1])):
						var before = [p.shoes[0].global_position,p.shoes[1].global_position]
						var was_swinging = p.swinging.duplicate()
						var serial = p.step_serial
						p.motion = p.motion.move_toward(direction*speed,24.0/fps if direction.length() else 35.0/fps)
						if direction.length(): p.facing = sin(elapsed*2)*turn
						ideal += p.motion.dot(direction)/fps
						game.move_player(0,1.0/fps)
						p.animate(1.0/fps,elapsed)
						elapsed += 1.0/fps
						frames += 1
						check(not(p.swinging[0] and p.swinging[1]),"Both shuffle feet airborne")
						check((p.feet_world[1]-p.feet_world[0]).dot(p.global_basis.x) > .08,"Shuffle feet crossed or closed together")
						for i in range(2):
							if not p.swinging[i] and not was_swinging[i] and (serial == p.step_serial or p.last_step != i):
								var slide = p.shoes[i].global_position.distance_to(before[i])
								worst_slide = maxf(worst_slide,slide)
								contacts += 1
								check(slide < .002,"Planted defensive shoe slid: %.4fm (%dfps, %.1fm/s)" % [slide,fps,speed])
							if p.swinging[i]:
								longest_step = maxf(longest_step,p.swing_from[i].distance_to(p.swing_to[i]))
							check(p.shoes[i].global_position.y >= .099,"Shuffle foot sank")
							check(p.shoes[i].global_position.y <= .15,"Shuffle foot lifted like running")
							check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Shuffle thigh stretched")
							check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Shuffle calf stretched")
					if direction.length() and segment[1] > .7:
						check((p.position-origin).dot(Vector3(direction.x,0,direction.y)) > ideal*.65,"Shuffle movement became unresponsive (%.3f / %.3f)" % [(p.position-origin).dot(Vector3(direction.x,0,direction.y)),ideal])
				check(not p.swinging[0] and not p.swinging[1],"Feet kept stepping after stopping")
	check(contacts > 300,"Missing planted contact samples")
	print("DEFENSE_SHUFFLE frames=",frames," planted_samples=",contacts," worst_slide_m=",worst_slide," longest_step_m=",longest_step," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
