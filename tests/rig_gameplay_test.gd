extends SceneTree
var failures = 0
var contact_samples = 0
var planted_samples = 0
var worst_palm_gap = 0.0
var worst_slide = 0.0
var received = 0
func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures<16: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			game.start_mode("practice")
			var p = game.players[0]
			check(p.skinned!=null and not p.body.visible,"Live match did not enable skinned character")
			p.position = Vector3.ZERO
			p.rotation.y = 0
			p.facing = 0
			p.reset_stance()
			p.dribble_hand = side
			p.ball_side = side
			var old_toes = [Vector3.ZERO,Vector3.ZERO]
			var old_locked = [false,false]
			var lengths: Array = []
			for f in range(int(fps*2.2)):
				var dt = 1.0/fps
				p.steer_motion(Vector2(0,4.7),24,dt)
				p.position += p.movement_step(dt)
				p.animate(dt,f*dt)
				var visual = p.skinned
				check(visual.clip=="run" or f<fps*.3,"Live running did not play original run clip")
				var phase = fposmod(p.dribble_phase,TAU)/TAU
				if f>fps*.4 and (phase<.12 or phase>.94):
					var gap = visual.palm_world[1 if side>0 else 0].distance_to(p.ball_anchor(0)+Vector3.UP*p.DRIBBLE_PALM)
					worst_palm_gap = maxf(worst_palm_gap,gap)
					check(gap<.03,"Visible rig palm missed dribble push/catch %.3fm" % gap)
					contact_samples += 1
					var wrist = visual.bone_world(visual.arms[1 if side>0 else 0][2])
					var normal = (wrist.basis.orthonormalized()*visual.palm_frames[1 if side>0 else 0]).z
					check(normal.dot(Vector3.DOWN)>.65,"Actual skinned palm did not face the dribble")
				check(p.hand_world.distance_to(visual.palm_world[1 if side>0 else 0])<.001,"Gameplay contact diverged from visible palm")
				for i in range(2):
					if old_locked[i] and visual.locked[i]:
						var slide = visual.toe_world[i].distance_to(old_toes[i])
						worst_slide = maxf(worst_slide,slide)
						check(slide<.008,"Visible skinned support slid %.3fm" % slide)
						planted_samples += 1
					old_locked[i] = visual.locked[i]
					old_toes[i] = visual.toe_world[i]
				var current_lengths: Array = []
				for chain in visual.feet+visual.arms:
					for j in range(2): current_lengths.append(visual.bone_world(chain[j]).origin.distance_to(visual.bone_world(chain[j+1]).origin))
				if lengths.is_empty(): lengths = current_lengths
				for j in range(lengths.size()): check(absf(lengths[j]-current_lengths[j])<.004,"Actual skinned limb changed length")
			check(p.skinned.skeleton.get_bone_count()==45,"Wrong live skeleton")
			game.start_mode("practice")
			p.dribble_hand = side
			p.ball_side = side
			key(KEY_UP,true)
			for f in range(int(fps*.5)): game._physics_process(1.0/fps)
			key(KEY_UP,false)
			key(KEY_LEFT if side<0 else KEY_RIGHT,true)
			key(KEY_A,true)
			var saw_receive = false
			for f in range(int(fps*1.1)):
				game._physics_process(1.0/fps)
				if p.crossing() and p.cross_received:
					var palm = p.skinned.palm_world[1 if p.dribble_hand>0 else 0]
					check(palm.distance_to(p.cross_ball_world()+Vector3.UP*p.DRIBBLE_PALM)<.11,"Skinned receiving hand missed the crossover ball")
					saw_receive = true
			check(saw_receive and p.action=="idle","Visible crossover did not receive and return to running")
			if saw_receive: received += 1
			key(KEY_A,false)
			key(KEY_LEFT if side<0 else KEY_RIGHT,false)
	check(contact_samples>50 and planted_samples>100,"Missing actual skin contact samples")
	check(received==6,"Missing visible skinned crossover receipts")
	print("RIG_GAMEPLAY palm_samples=",contact_samples," planted_samples=",planted_samples," crossover_receipts=",received," worst_palm_gap=",worst_palm_gap," worst_slide=",worst_slide," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
