extends SceneTree

var failures = 0
var samples = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 8: push_error(message)
func key(code: Key,down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func sample(p) -> void:
	check(not (p.swinging[0] and p.swinging[1]),"Both defensive feet launched together")
	for i in range(2):
		check(absf(p.joint_hips[i].distance_to(p.joint_knees[i])-p.THIGH_LENGTH) < .0002,"Thigh stretched in stance")
		check(absf(p.joint_knees[i].distance_to(p.joint_ankles[i])-p.SHIN_LENGTH) < .0002,"Calf stretched in stance")
		check(p.shoes[i].global_position.y >= .095,"Defensive foot sank into floor")
		check(absf(p.arms[i][0].basis.y.length()-p.UPPER_ARM_LENGTH) < .0002 and absf(p.arms[i][1].basis.y.length()-p.FOREARM_LENGTH) < .0002,"Brace arm stretched")
	samples += 1

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for direction in [KEY_LEFT,KEY_RIGHT]:
			game.start_mode("duel")
			game.reset_positions(1)
			var p = game.players[0]
			var ai = game.players[1]
			p.position = Vector3.ZERO
			p.rotation.y = PI
			p.facing = PI
			p.feet_world.clear()
			ai.position = Vector3(0,0,-2.5)
			game.ai_freeze = 10
			p.animate(1.0/fps,0)
			var upright = p.body.global_position.y
			key(KEY_W,true)
			for f in range(int(fps*.4)):
				game._physics_process(1.0/fps)
				sample(p)
			check(p.body.global_position.y < upright-.13,"W did not lower defensive stance")
			key(direction,true)
			for f in range(int(fps*.45)):
				game._physics_process(1.0/fps)
				var target = ai.position-p.position
				check(absf(angle_difference(p.facing,atan2(target.x,target.z))) < .03,"Guard faced running direction instead of attacker")
				check(maxf(p.feet_world[0].y,p.feet_world[1].y) < .15,"Guard used high running knees")
				check((p.feet_world[1]-p.feet_world[0]).dot(p.global_basis.x) > -.05,"Defensive feet crossed")
				sample(p)
			key(direction,false)
			key(KEY_W,false)
			for f in range(int(fps*.6)): game._physics_process(1.0/fps)
			check(p.defense_weight < .01,"Low stance did not release")
	# Angled contact must put the opponent behind the back, not just face the rim.
	game.start_mode("practice")
	game.set_drill("boxout")
	var p = game.players[0]
	var ai = game.players[1]
	ai.position = p.position+Vector3(.35,0,.78)
	game.update_boxouts(true)
	var away = (p.position-ai.position).normalized()
	check(Vector3(sin(p.facing),0,cos(p.facing)).dot(away) > .99,"Box-out back did not align with opponent")
	for f in range(60): p.animate(1.0/60,f/60.0)
	check(p.pressure_weight > .25,"Contact did not load the brace pose")
	check(p.body.position.z < -.01,"Hips did not settle back into contact")
	var neutral_y = p.body.position.y
	var neutral_z = p.body.position.z
	p.contact_pressure = 1
	for f in range(30):
		p.animate(1.0/60,1+f/60.0)
		sample(p)
	check(p.body.position.y < neutral_y-.005 and p.body.position.z < neutral_z-.005,"Stronger pressure did not change body brace")
	for i in range(2):
		check(p.hands[i].position.y < 1.45,"Box-out arms stayed rigidly spread at shoulder height")
	game.update_boxouts(false)
	for f in range(45): p.animate(1.0/60,2+f/60.0)
	check(p.boxout_weight < .01 and p.pressure_weight < .01,"Contact pose failed to recover")
	print("DEFENSE_STANCE low guard, lateral facing, short steps, contact brace/recovery; samples=",samples," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
