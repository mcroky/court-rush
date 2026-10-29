extends SceneTree
var failures=0
var selected={}
var max_pose_change=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		push_error(message)
func run():
	var actor=load("res://scripts/actor.gd").new()
	root.add_child(actor);actor.setup(false)
	var visual=actor.skinned
	var layer=visual.motionbricks
	check(layer.bones.size()==9,"Retarget channels not bound")
	for label in ["run","stop_l","stop_r","left_l","left_r","right_l","right_r"]:
		for frame in 26:
			for channel in 45:
				var q=layer.sample(label,frame/25.0,channel)
				check(q.is_finite() and absf(q.length()-1)<.001,"Invalid baked quaternion")
	for channel in 45:check(layer.sample("run",0,channel).angle_to(layer.sample("run",1,channel))<.015,"Run loop endpoint discontinuity")
	for fps in [30,60,120]:
		for ball in [false,true]:
			actor.position=Vector3.ZERO;actor.motion=Vector2.ZERO;actor.action="idle";actor.has_ball=ball;actor.rotation.y=0;actor.facing=0;actor.dribble_ended=false;actor.reset_stance();actor.feet_world.clear();layer.reset()
			for frame in int(fps*3.2):
				var t=frame/float(fps)
				var desired=Vector2(0,4.7) if t<.65 else (Vector2(-4.7,0) if t<1.2 else (Vector2(4.7,0) if t<1.8 else Vector2.ZERO))
				actor.steer_motion(desired,24,1.0/fps);actor.position+=actor.movement_step(1.0/fps)
				if desired.length()>.1:actor.facing=atan2(desired.x,desired.y)
				actor.animate(1.0/fps,t)
				selected[layer.active]=true
				for bone in visual.bone_count:
					check(visual.skeleton.get_bone_pose(bone).is_finite(),"Runtime nonfinite pose")
			# Compare exactly the same source frame with/without the actual layer.
			actor.brake_state="";actor.redirect_left=0;actor.has_ball=ball
			visual.sample_base(.016,4.7,false,.31)
			var bone=layer.bones[1]
			var before=visual.skeleton.get_bone_pose_rotation(bone)
			layer.active="run";layer.weight=1
			layer.apply(visual.skeleton,actor,.016,.31,4.7)
			max_pose_change=maxf(max_pose_change,before.angle_to(visual.skeleton.get_bone_pose_rotation(bone)))
	check(max_pose_change>.01,"Generated poses had no real skeleton effect")
	check(selected.has("run") and (selected.has("stop_l") or selected.has("stop_r")),"Missing stop/run selection")
	check((selected.has("left_l") or selected.has("left_r")) and (selected.has("right_l") or selected.has("right_r")),"Missing both direction changes")
	var count=layer.applied_frames
	actor.action="shot";layer.apply(visual.skeleton,actor,.016,.3,4.7)
	check(layer.applied_frames==count,"Layer overrode shooting")
	print("MOTIONBRICKS_POSE clips=7 finite_quaternions=8190 scenarios=6 selected=",selected.keys()," actual_spine_change_rad=",max_pose_change," failures=",failures)
	actor.queue_free();await process_frame;quit(1 if failures else 0)
