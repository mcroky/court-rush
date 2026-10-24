extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var lab = load("res://scenes/motion_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	check(lab.skeleton.get_bone_count()==45,"Imported skeleton lost bones")
	var skin_mesh = lab.rig.find_children("*","MeshInstance3D")[0]
	check(skin_mesh.skin != null,"Comparison is not a skinned mesh")
	check(lab.animation.has_animation("run") and lab.animation.has_animation("idle"),"Missing original animation clips")
	var foot = lab.skeleton.find_bone("foot.l")
	var first = lab.skeleton.get_bone_global_pose(foot).origin
	var travel = 0.0
	for f in range(90):
		lab._physics_process(1.0/60)
		travel = maxf(travel,lab.skeleton.get_bone_global_pose(foot).origin.distance_to(first))
	check(travel>.10,"Original run keyframes did not move the skeleton")
	check(absf(lab.rig.position.x-1.05)<.001,"Source animation moved the comparison root")
	check(lab.legacy.position.distance_to(Vector3(-1.05,0,0))<.001,"Comparison treadmill drifted")
	lab.paused = true
	var frozen = [lab.elapsed,lab.skeleton.get_bone_global_pose(foot),lab.legacy.stride]
	for f in range(20): lab._physics_process(1.0/60)
	check(frozen==[lab.elapsed,lab.skeleton.get_bone_global_pose(foot),lab.legacy.stride],"Paused comparison kept moving")
	lab.paused = false
	lab.set_mode("flow")
	var seen = {}
	for f in range(450):
		lab._physics_process(1.0/60)
		seen[lab.animation.current_animation]=true
	check(seen.has("idle") and seen.has("run"),"Idle/run comparison never transitioned")
	lab.set_mode("land")
	for f in range(90): lab._physics_process(1.0/60)
	check(lab.animation.assigned_animation=="air_land","Landing source clip failed")
	print("RIG_MOTION bones=",lab.skeleton.get_bone_count()," run_foot_excursion=",travel," failures=",failures)
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
