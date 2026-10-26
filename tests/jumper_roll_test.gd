extends SceneTree
var failures=0
var cases=0
var frames=0
var max_slide=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func run():
	var actor=load("res://scripts/actor.gd").new();root.add_child(actor);actor.setup(false)
	for role in ["guard","forward","center"]:
		for fps in [30,60,120]:
			for hand in [-1.0,1.0]:
				actor.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
				actor.position=Vector3.ZERO;actor.rotation.y=0;actor.facing=0;actor.motion=Vector2.ZERO
				actor.reset_stance();actor.feet_world.clear();actor.has_ball=true;actor.dribble_ended=true;actor.dribble_hand=hand;actor.finish_kind="shot";actor.action="idle";actor.jump=0
				var dt=1.0/fps
				for frame in fps:actor.animate(dt,frame*dt)
				actor.action="gather"
				for frame in int(fps*.55):actor.action_time=frame*dt;actor.animate(dt,1+frame*dt)
				var v=actor.skinned
				var old_toes=v.toe_world.duplicate()
				var highest_heel=0.0
				var air_pitch=10.0
				var loaded_knee=[]
				for chain in v.feet:loaded_knee.append(PI-(v.bone_world(chain[0]).origin-v.bone_world(chain[1]).origin).angle_to(v.bone_world(chain[2]).origin-v.bone_world(chain[1]).origin))
				var pushed_knee=[10.0,10.0]
				var early_knee=[0.0,0.0]
				var apex_knee=[0.0,0.0]
				var settled_pitch=10.0
				actor.action="shot"
				for frame in int(fps*.88):
					var t=frame*dt
					actor.action_time=t;actor.jump=actor.shot_height(t);actor.has_ball=t<.22;actor.animate(dt,1.55+t)
					for i in 2:
						var chain=v.feet[i]
						var hip=v.bone_world(chain[0]).origin;var knee=v.bone_world(chain[1]).origin;var ankle=v.bone_world(chain[2]).origin
						var actual=(actor.global_basis.inverse()*v.bone_world(chain[2]).basis.orthonormalized()*v.foot_rest_basis[i].inverse()).orthonormalized()
						var pitch=actual.get_euler().x
						var times=v.jumper_times(actor,i)
						if t>0 and t<=times.x:
							pushed_knee[i]=minf(pushed_knee[i],PI-(hip-knee).angle_to(ankle-knee))
							var slide=v.toe_world[i].distance_to(old_toes[i]);max_slide=maxf(max_slide,slide)
							check(slide<.006,"Toe-off plant slid "+str(slide))
							var bind=-1
							for b in v.human_mesh.skin.get_bind_count():
								if str(v.human_mesh.skin.get_bind_name(b))==v.skeleton.get_bone_name(chain[2]):bind=b;break
							var inverse=v.human_mesh.skin.get_bind_pose(bind)
							var point=inverse*Vector3(inverse.affine_inverse().origin.x,.025,-.105)
							highest_heel=maxf(highest_heel,(v.bone_world(chain[2])*point).y-v.toe_world[i].y)
						if t>.18 and t<.60:air_pitch=minf(air_pitch,pitch)
						if absf(t-.17)<dt:early_knee[i]=PI-(hip-knee).angle_to(ankle-knee)
						if absf(t-.40)<dt:apex_knee[i]=PI-(hip-knee).angle_to(ankle-knee)
						if t>.83:settled_pitch=minf(settled_pitch,absf(pitch))
						for segment in [[chain[0],chain[1]],[chain[1],chain[2]]]:
							var length=v.skeleton.get_bone_rest(segment[1]).origin.length()*v.render_scale
							check(absf(v.bone_world(segment[0]).origin.distance_to(v.bone_world(segment[1]).origin)-length)<.001,"Jumper stretched a leg")
						old_toes[i]=v.toe_world[i];frames+=1
				check(maxf(loaded_knee[0]-pushed_knee[0],loaded_knee[1]-pushed_knee[1])>.06,"Loaded knees did not extend into toe-off")
				check(highest_heel>.045,"Shoe heel never rolled above planted forefoot")
				check(air_pitch>.12,"Airborne ankle returned to flat rigid elevator pose")
				check(maxf(absf(apex_knee[0]-early_knee[0]),absf(apex_knee[1]-early_knee[1]))>.08,"Airborne knees never articulated")
				check(settled_pitch<.035,"Heels did not settle after forefoot landing")
				cases+=1
	# A deeper shot load must also hand off safely when a short press becomes
	# a pump fake. Carry the loaded pelvis instead of snapping back upright.
	for fps in [30,60,120]:
		var dt=1.0/fps
		actor.action="idle";actor.jump=0;actor.motion=Vector2.ZERO
		for f in fps:actor.animate(dt,f*dt)
		actor.action="gather"
		for f in int(fps*.16):actor.action_time=f*dt;actor.animate(dt,1+f*dt)
		var v=actor.skinned
		var before=v.bone_world(v.skeleton.find_bone("pelvis")).origin.y
		actor.action="fake";actor.action_time=0;actor.animate(dt,1.2)
		check(absf(v.bone_world(v.skeleton.find_bone("pelvis")).origin.y-before)<.025,"Pump fake snapped from the deeper shot load")
	print("JUMPER_ROLL cases=",cases," actual_leg_frames=",frames," max_plant_slide=",max_slide," failures=",failures)
	actor.queue_free();await process_frame;quit(1 if failures else 0)
