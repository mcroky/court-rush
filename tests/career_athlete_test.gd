extends SceneTree
var failures=0
var contacts=0
var releases=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.sound_enabled=false
	for role in ["guard","forward","center"]:
		var height={"guard":178,"forward":190,"center":204}[role]
		var athlete={"role":role,"height":height,"level":2,"shoot":65,"finish":65,"defense":60,"training":{"speed":3,"rebound":2},"skills":{"cross":1,"shoot":1,"rebound":1}}
		game.start_career({"matchId":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","stage":2,"athlete":athlete,"opponent":{"name":"검증 상대","athlete":{"role":"forward","height":190,"level":2}}})
		var p=game.players[0];var v=p.skinned
		check(game.career_stage==2 and p.court_role==role,"Career snapshot was not applied")
		check(absf(v.human_mesh.mesh.get_aabb().size.y*v.render_scale-float(height)/100)<.002,"Position height was label-only")
		check(p.athletic_profile().speed>game.Rules.role_profile(role).speed,"Speed training did not affect game")
		p.position=Vector3.ZERO;p.facing=0;p.rotation.y=0;p.feet_world.clear()
		# An explicit fixture teleport has no prior contact history. Settle the
		# same 120ms source-pose entry used by the original rig before measuring.
		for f in 18:p.animate(1.0/60,f/60.0)
		for f in 120:
			p.steer_motion(Vector2(0,4),24,1.0/60);p.position+=p.movement_step(1.0/60);p.animate(1.0/60,f/60.0)
			var t=fposmod(p.dribble_phase,TAU)/TAU
			if t<.18 or t>.84:
				check(p.palm_position(1).distance_to(p.ball_anchor(0)+Vector3.UP*p.DRIBBLE_PALM)<.04,"Height-scaled dribble hand lost ball %s f=%d gap=%.3f hand=%.1f" % [role,f,p.palm_position(1).distance_to(p.ball_anchor(0)+Vector3.UP*p.DRIBBLE_PALM),p.dribble_hand]);contacts+=1
			for i in 2:check(v.arm_errors[i]<.045,"Height-scaled arm target unreachable %s f=%d hand=%d err=%.3f weight=%.3f" % [role,f,i,v.arm_errors[i],v.arm_weight[i]])
		# A held jumper on the actual rig must still release above the face.
		p.motion=Vector2.ZERO;p.action="gather";p.action_time=0;p.dribble_ended=true;p.finish_kind="shot"
		for f in 32:p.action_time=f/60.0;p.animate(1.0/60,3+f/60.0)
		p.action="shot"
		for f in 53:
			p.action_time=f/60.0;p.jump=p.shot_height(p.action_time);p.animate(1.0/60,4+f/60.0)
			if p.action_time>=.18 and p.action_time<=.22:
				check(p.palm_position(1).y>v.bone_world(v.skeleton.find_bone("head")).origin.y+.10,"Position-specific shot released into face "+role);releases+=1
	game.start_mode("practice")
	check(game.career_match_id.is_empty() and game.players[0].growth.is_empty(),"Career stats leaked into normal match")
	print("CAREER_ATHLETE roles=3 actual_dribble_contacts=",contacts," actual_releases=",releases," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
