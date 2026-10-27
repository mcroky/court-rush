extends SceneTree
const Web=preload("res://tests/block_quick_input_test.gd")
var failures=0
var samples=0
var max_contact_error=0.0
var max_pose_error=0.0
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func run():
	var reference=load("res://scenes/main.tscn").instantiate();root.add_child(reference);reference.set_physics_process(false);reference.sound_enabled=false
	var optimized=load("res://scenes/main.tscn").instantiate();root.add_child(optimized);optimized.set_physics_process(false);optimized.sound_enabled=false
	for mode in ["practice","duel","team"]:
		reference.web_input=null;optimized.web_input=null
		for g in [reference,optimized]:
			g.start_mode(mode);g.rng.seed=623817
			for p in g.players:p.skinned.motion_cache_enabled=g==optimized;p.motion_buffers_enabled=g==optimized
			g.web_input=Web.web();g.web_control_reset=-1
		for frame in 1500:
			for g in [reference,optimized]:
				var input=g.web_input
				input.x=sin(frame*.013)*.75;input.z=cos(frame*.013)*.75
				input.shoot=frame%210>=95 and frame%210<130
				input.cross=frame%180==35;input.spin=frame%310==40
				input.behind=frame%270==50;input.guard=frame%200>145
				if frame%110==0:input.passSeq+=1
				if frame%270==0:input.switchSeq+=1
				g._physics_process(1.0/60)
			check(reference.phase==optimized.phase and reference.ball_owner==optimized.ball_owner,"Motion caching changed phase or possession")
			check(reference.ball.position.distance_to(optimized.ball.position)<.002,"Motion caching changed the visible ball path")
			for i in reference.players.size():
				var a=reference.players[i];var b=optimized.players[i]
				check(a.action==b.action,"Motion caching changed an action transition")
				for side in 2:
					max_contact_error=maxf(max_contact_error,a.palm_position(side).distance_to(b.palm_position(side)))
					max_contact_error=maxf(max_contact_error,a.skinned.toe_world[side].distance_to(b.skinned.toe_world[side]))
					var rendered=b.skinned.bone_world(b.skinned.arms[side][2])*b.skinned.palm_offsets[side]
					check(rendered.distance_to(b.skinned.palm_world[side])<.0001,"Published palm did not match the committed skeleton")
				if frame%15==0:
					for bone in a.skinned.skeleton.get_bone_count():
						var old=a.skinned.skeleton.get_bone_global_pose(bone)
						var current=b.skinned.skeleton.get_bone_global_pose(bone)
						max_pose_error=maxf(max_pose_error,old.origin.distance_to(current.origin))
						if failures==0 and (old.basis.x.distance_to(current.basis.x)>=.002 or old.basis.y.distance_to(current.basis.y)>=.002):print("FIRST_POSE_DIFF mode=",mode," frame=",frame," actor=",i," action=",a.action," bone=",bone," name=",a.skinned.skeleton.get_bone_name(bone)," old=",a.skinned.skeleton.get_bone_pose(bone)," new=",b.skinned.skeleton.get_bone_pose(bone))
						check(old.basis.x.distance_to(current.basis.x)<.002 and old.basis.y.distance_to(current.basis.y)<.002,"Bone orientation changed during caching")
				samples+=1
	check(max_contact_error<.000001,"Hand/foot trajectory deviated from the original solve")
	check(max_pose_error<.00005,"Joint trajectory deviated from the original solve")
	var hits=0
	for p in optimized.players:hits+=p.skinned.finger_cache_hits
	check(hits>100,"No finger poses were reused in representative play")
	print("MOTION_CACHE actor_samples=",samples," max_contact_error_m=",max_contact_error," max_joint_error_m=",max_pose_error," finger_hits=",hits," failures=",failures)
	for g in [reference,optimized]:g.web_input=null;g.queue_free()
	await process_frame;quit(1 if failures else 0)
