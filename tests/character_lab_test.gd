extends SceneTree

var failures=0
var frames=0

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		if failures<12:push_error(message)

func run() -> void:
	var lab=load("res://scenes/character_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	for fps in [30,60,120]:
		for mode in ["guard","shuffle","boxout"]:
			# Enter from a shot to catch stale possession/action state in the viewer.
			lab.mode="shot"
			for f in range(int(fps*.8)):lab._physics_process(1.0/fps)
			lab.mode=mode
			var left=false
			var right=false
			var low=false
			var pressure=false
			for f in range(int(fps*8.3)):
				lab._physics_process(1.0/fps)
				frames+=1
				for i in range(2):
					var p=lab.athletes[i]
					check(not p.has_ball and not lab.balls[i].visible,"Defense preview retained the shot ball")
					check(p.action=="idle" and is_zero_approx(p.jump),"Defense preview retained the shot action")
					check(p.position.distance_to(Vector3(-.8 if i==0 else .8,0,0))<.0001,"Preview actor drifted out of frame")
					check(not(p.swinging[0] and p.swinging[1]),"Defense preview lifted both supports")
					for foot in p.feet_world:check(foot.is_finite(),"Non-finite preview contact")
					var lateral=p.motion.dot(Vector2(p.global_basis.x.x,p.global_basis.x.z))
					left=left or lateral<-.5
					right=right or lateral>.5
					low=low or p.defense_weight>.8
					pressure=pressure or p.pressure_weight>.4
			check(low,"Defense preview never entered its low stance")
			check(lab.athletes[0].defense_weight<.1,"Defense preview did not recover to standing")
			check(lab.athletes[0].motion.length()<.01,"Defense preview did not settle after moving")
			if mode!="guard":check(left and right,"Defense preview missed a direction reversal")
			if mode=="boxout":check(pressure,"Box-out preview never applied contact pressure")
	# The shared stance flags must not leak back into the existing run preview.
	lab.mode="run"
	for f in range(60):lab._physics_process(1.0/60)
	for p in lab.athletes:
		check(not p.defending and not p.boxing_out and p.defense_weight<.01,"Defense state leaked into running")
	for view in ["side","other-side"]:
		lab.view=view
		lab.mode="dribble"
		for f in 60:lab._physics_process(1.0/60)
		for p in lab.athletes:
			check(absf(angle_difference(p.rotation.y,PI*.5 if view=="side" else -PI*.5))<.01,"Side view did not present the requested shoulder")
			check(p.has_ball and p.ordinary_dribble(),"Side view lost its real gameplay dribble pose")
	print("CHARACTER_LAB frames=",frames," failures=",failures)
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
