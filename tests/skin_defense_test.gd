extends SceneTree
## Inspect the rendered human rig; the hidden prototype can be planted while
## the shorter skinned legs cross, hop, or jump to an unrelated step phase.
var failures=0
var samples=0
var cases=0
var totals={"knee_speed":0.0,"elbow_speed":0.0,"palm_speed":0.0,"wrist_speed":0.0,"planted_slide":0.0,"toe_min":10.0,"stance_width":10.0}
const ATHLETES=[{}, {"role":"guard","height":178}, {"role":"forward","height":190}, {"role":"center","height":204}]
var athlete:Dictionary={}
var athlete_label="practice model"

func _init():call_deferred("run")

func check(ok:bool,message:String):
	if not ok:
		failures+=1
		if failures<12:push_error(athlete_label+": "+message)

func snapshot(v)->Dictionary:
	var state={"toes":v.toe_world.duplicate(),"palms":v.palm_world.duplicate(),"locked":v.locked.duplicate(),"knees":[],"elbows":[],"wrists":[]}
	for i in 2:
		state.knees.append(v.bone_world(v.feet[i][1]).origin)
		state.elbows.append(v.bone_world(v.arms[i][1]).origin)
		state.wrists.append(v.bone_world(v.arms[i][2]).basis.orthonormalized().get_rotation_quaternion())
	return state

func measure(p,old:Dictionary,dt:float,label:String,steady:bool):
	var v=p.skinned
	if steady:
		var width=(v.toe_world[1]-v.toe_world[0]).dot(p.global_basis.x)
		totals.stance_width=minf(totals.stance_width,width)
		check(width>.08,"Rendered defensive feet crossed: "+label)
		check(minf(v.toe_world[0].y,v.toe_world[1].y)<.04,"Rendered shuffle released both supporting feet: "+label)
	for i in 2:
		var knee=v.bone_world(v.feet[i][1]).origin
		var elbow=v.bone_world(v.arms[i][1]).origin
		var wrist=v.bone_world(v.arms[i][2]).basis.orthonormalized().get_rotation_quaternion()
		var knee_speed=knee.distance_to(old.knees[i])/dt
		var elbow_speed=elbow.distance_to(old.elbows[i])/dt
		var palm_speed=v.palm_world[i].distance_to(old.palms[i])/dt
		var wrist_speed=wrist.angle_to(old.wrists[i])/dt
		totals.knee_speed=maxf(totals.knee_speed,knee_speed)
		totals.elbow_speed=maxf(totals.elbow_speed,elbow_speed)
		totals.palm_speed=maxf(totals.palm_speed,palm_speed)
		totals.wrist_speed=maxf(totals.wrist_speed,wrist_speed)
		totals.toe_min=minf(totals.toe_min,v.toe_world[i].y)
		check(knee.is_finite() and elbow.is_finite() and v.toe_world[i].is_finite(),"Non-finite rendered joint: "+label)
		check(v.toe_world[i].y>=-.005,"Rendered foot passed through the floor: "+label)
		check(knee_speed<17,"Rendered knee snapped: %.2fm/s %s"%[knee_speed,label])
		check(elbow_speed<15 and palm_speed<15,"Rendered defensive arm snapped: %.2f/%.2fm/s %s"%[elbow_speed,palm_speed,label])
		check(wrist_speed<12.02,"Rendered empty-hand wrist flipped: %.2frad/s %s"%[wrist_speed,label])
		if steady and old.locked[i] and v.locked[i]:
			var slide=v.toe_world[i].distance_to(old.toes[i])
			totals.planted_slide=maxf(totals.planted_slide,slide)
			check(slide<.002,"Rendered planted shoe slid: %.4fm %s"%[slide,label])
		samples+=1

func reset_player(game):
	game.start_mode("duel")
	var p=game.players[0]
	p.apply_athlete(athlete)
	p.position=Vector3.ZERO;p.rotation.y=0;p.facing=0;p.reset_stance();p.feet_world.clear();p.has_ball=false
	return p

func run_scenarios(game):
	# Include the real player guard/box-out speeds and faster AI chase recovery.
	for boxing in [false,true]:
		for fps in [30,60,120]:
			for speed in [1.7,2.7,3.7]:
				var p=reset_player(game);var dt=1.0/fps
				p.defending=true;p.boxing_out=boxing
				for f in fps:p.animate(dt,f*dt)
				var elapsed=1.0
				var label="steady %dfps %.1fm/s box=%s"%[fps,speed,str(boxing)]
				var segments=[[Vector2.RIGHT,.75],[Vector2.ZERO,.18],[Vector2.LEFT,.75],[Vector2.RIGHT,.75],[Vector2(1,1).normalized(),.3],[Vector2(0,-1),.3],[Vector2.ZERO,.5]]
				for segment in segments:
					var direction:Vector2=segment[0]
					for f in int(fps*segment[1]):
						var old=snapshot(p.skinned)
						p.motion=p.motion.move_toward(direction*speed,(24 if direction.length() else 35)*dt)
						if direction.length():p.facing=sin(elapsed*2)*.65
						game.move_player(0,dt);p.animate(dt,elapsed);elapsed+=dt
						measure(p,old,dt,label,true)
				cases+=1
	# Press/release low guard during different running phases, then reverse and
	# box out. In particular, entering near the end of a step must not treat
	# that old step's 96% progress as 96% of a newly captured visible-foot path.
	for fps in [30,60,120]:
		for start_phase in [.2,.43,.7]:
			var p=reset_player(game);var dt=1.0/fps
			for f in int(fps*start_phase):
				p.steer_motion(Vector2(0,4.7),24,dt);p.position+=p.movement_step(dt);p.animate(dt,f*dt)
			var elapsed=start_phase;var section=0
			var segments=[[true,false,Vector2.RIGHT*2.7,.65],[true,false,Vector2.LEFT*2.7,.40],[false,false,Vector2(0,4.7),.55],[true,true,Vector2.RIGHT*1.7,.6],[false,false,Vector2(0,4.7),.55]]
			for segment in segments:
				p.defending=segment[0];p.boxing_out=segment[1];p.contact_pressure=.6 if p.boxing_out else 0
				for f in int(fps*segment[3]):
					var old=snapshot(p.skinned)
					p.steer_motion(segment[2],24,dt);p.position+=p.movement_step(dt);p.animate(dt,elapsed);elapsed+=dt
					measure(p,old,dt,"transition %dfps phase%.2f section%d t%.3f"%[fps,start_phase,section,f*dt],false)
				section+=1
			cases+=1
	# A beaten defender plants, turns, pursues, then re-enters guard. This also
	# covers the pelvis correction carrying both shoulders and arms downward.
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			for moving in [false,true]:
				game.start_mode("duel")
				var p=game.players[1];var dt=1.0/fps
				p.apply_athlete(athlete)
				game.players[0].position=Vector3(0,0,1)
				p.position=Vector3(0,0,-.3);p.rotation.y=0;p.facing=0;p.defending=true;p.feet_world.clear()
				for f in int(fps*.22):
					p.motion=Vector2(side*1.6,0) if moving else Vector2.ZERO
					p.position+=p.movement_step(dt);p.animate(dt,f*dt)
				game.crossover(Vector2(side,0))
				check(p.chase_recovery,"Rendered pursuit case did not enter recovery")
				for f in int(fps*1.7):
					var old=snapshot(p.skinned)
					game.players[0].position+=Vector3(side*.8,0,-3.8)*dt
					game.ai_reaction=maxf(0,game.ai_reaction-dt)
					game.ai_reaction_cooldown=maxf(0,game.ai_reaction_cooldown-dt)
					game.ai_freeze=0
					game.update_ai(dt);p.animate(dt,.22+f*dt)
					measure(p,old,dt,"pursuit %dfps side%.0f moving%s t%.3f"%[fps,side,str(moving),f*dt],false)
				check(not p.chase_recovery,"Rendered pursuit failed to resume")
				cases+=1

func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	# Keep the unscaled practice model and repeat every scenario for the three
	# career body sizes. A short guard must meet the same contact limits.
	for profile in ATHLETES:
		athlete=profile
		athlete_label="practice model" if athlete.is_empty() else "%s %dcm"%[athlete.role,athlete.height]
		var first_case=cases
		run_scenarios(game)
		check(cases-first_case==39,"Missing rendered defensive profile cases")
	check(cases==39*ATHLETES.size(),"Missing rendered defensive cases")
	print("SKIN_DEFENSE profiles=",ATHLETES.size()," cases=",cases," samples=",samples," metrics=",JSON.stringify(totals)," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
