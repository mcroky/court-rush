extends SceneTree
var failures=0
var cases=0
var max_turn_rate=0.0
var max_pivot_drift=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func key(code: Key,down: bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()
func clear_keys():
	for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_D,KEY_A,KEY_Z,KEY_C,KEY_V,KEY_X]:key(code,false)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		var dt=1.0/fps
		for move in [[],[KEY_DOWN],[KEY_RIGHT],[KEY_LEFT,KEY_DOWN],[KEY_UP]]:
			clear_keys();game.start_mode("practice")
			var p=game.players[0];p.position=Vector3(0,0,3.5);p.rotation.y=0;p.facing=0;p.reset_stance();p.feet_world.clear()
			for f in int(fps*.20):game._physics_process(dt)
			for code in move:key(code,true)
			for f in int(fps*.30):game._physics_process(dt)
			key(KEY_D,true)
			var squared=false;var released=false;var old_yaw=p.rotation.y
			for f in int(fps*2.8):
				if f==int(fps*.44):key(KEY_D,false)
				game._physics_process(dt)
				if p.action=="square":
					squared=true
					var rate=absf(angle_difference(old_yaw,p.rotation.y))/dt;max_turn_rate=maxf(max_turn_rate,rate)
					check(rate<6.6,"Turnaround snapped instead of using the grounded turn")
					var drift=p.skinned.toe_world[p.held.support].distance_to(p.held.anchor)
					if p.held.entry_time>=.12:max_pivot_drift=maxf(max_pivot_drift,drift)
					if p.held.entry_time>=.12:check(drift<.04,"Turnaround pivot toe slid fps="+str(fps)+" move="+str(move)+" t="+str(p.action_time)+" drift="+str(drift))
					check(p.jump==0 and game.phase=="live","Turnaround jumped or released before squaring")
				if p.action=="gather" and squared:check(absf(angle_difference(p.rotation.y,atan2(game.HOOP.x-p.position.x,game.HOOP.z-p.position.z)))<.10,"Shot lift started while facing away")
				if game.phase=="flight" and not released:
					released=true
					check(p.global_basis.z.dot((Vector3(game.HOOP.x,0,game.HOOP.z)-p.position).normalized())>.95,"Release still faces sideways")
				old_yaw=p.rotation.y
			check(released and game.attempts==1,"Queued turnaround release did not shoot exactly once fps="+str(fps)+" move="+str(move)+" action="+p.action+" phase="+game.phase+" attempts="+str(game.attempts)+" queued="+str(p.held.queued_release)+" pump="+str(p.held.pump_release))
			cases+=1
		for binding in [[KEY_A,"pivot"],[KEY_Z,"turn"],[KEY_C,"upunder"],[KEY_V,"through"],[KEY_X,"pump"]]:
			clear_keys();game.start_mode("practice")
			var p=game.players[0];p.position=Vector3(0,0,3.5);p.rotation.y=PI;p.facing=PI;p.reset_stance();p.feet_world.clear()
			var role=["guard","forward","center"][cases%3]
			p.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
			for f in int(fps*.20):game._physics_process(dt)
			key(KEY_D,true)
			for f in int(fps*.08):game._physics_process(dt)
			key(KEY_D,false)
			for f in int(fps*.85):game._physics_process(dt)
			check(p.action=="idle" and p.dribble_ended and p.has_ball,"Pump did not return to a held-ball stance")
			var anchor=p.held.anchor;var support=p.held.support;var phase=p.dribble_phase
			key(binding[0],true);game._physics_process(dt);key(binding[0],false)
			check(p.action=="held_fake" and p.held.kind==binding[1],"Held skill did not use its contextual fake")
			var max_ball_motion=0.0;var old_ball=game.ball.position
			for f in int(fps*1.10):
				game._physics_process(dt)
				check(p.has_ball and p.dribble_ended and p.jump==0,"Fake restarted a dribble or lost possession")
				check(absf(p.dribble_phase-phase)<.0001,"Held fake advanced the bounce clock")
				var drift=p.skinned.toe_world[support].distance_to(anchor);max_pivot_drift=maxf(max_pivot_drift,drift)
				check(drift<.04,"Held fake moved its pivot toe")
				check(game.ball.position.distance_to((p.palm_position(0)+p.palm_position(1))*.5)<.001,"Fake ball disconnected from both hands")
				check(game.ball.position.y>.48,"Through-the-legs fake became an illegal bounce")
				max_ball_motion=maxf(max_ball_motion,game.ball.position.distance_to(old_ball)/dt);old_ball=game.ball.position
			check(max_ball_motion<10,"Held fake handoff teleported the ball")
			check(p.action=="idle" and game.attempts==0,"Fake committed a shot without D")
			key(KEY_D,true)
			for f in int(fps*2.1):game._physics_process(dt)
			key(KEY_D,false)
			check(game.attempts==1,"Cannot shoot after a held fake")
			cases+=1
	for fps in [30,60,120]:
		var dt=1.0/fps
		for code in [KEY_UP,KEY_RIGHT]:
			clear_keys();game.start_mode("practice")
			var p=game.players[0];p.rotation.y=PI;p.facing=PI;p.reset_stance();p.feet_world.clear()
			for f in int(fps*.2):game._physics_process(dt)
			game.fake_shot(0)
			for f in int(fps*.8):game._physics_process(dt)
			key(code,true);game._physics_process(dt)
			check(p.action=="held_fake" and p.held.kind==("jab" if code==KEY_UP else "pivot"),"Direction did not select jab/pivot")
			for f in int(fps*1.2):game._physics_process(dt)
			check(p.action=="idle","Holding one direction repeated the fake")
			key(code,false);key(KEY_DOWN if code==KEY_UP else KEY_LEFT,true);game._physics_process(dt)
			check(p.action=="held_fake" and p.held.kind=="pivot","Direction reversal required an extra neutral frame")
			check(p.dribble_ended and p.has_ball and game.attempts==0,"Direction fake restarted the dribble")
			cases+=1
	for selection in [0,2]:
		clear_keys();game.start_mode("team")
		game.team_match.selected=selection;game.ball_owner=selection
		for actor in game.players:actor.has_ball=false
		var p=game.players[selection];p.has_ball=true;p.facing=PI;p.rotation.y=PI;p.reset_stance();p.feet_world.clear()
		for f in 15:game._physics_process(1.0/60)
		game.fake_shot(selection)
		for f in 50:game._physics_process(1.0/60)
		key(KEY_C,true);game._physics_process(1.0/60);key(KEY_C,false)
		check(p.action=="held_fake" and p.held.kind=="upunder","3v3 selected player did not receive the contextual fake")
		for f in 60:game._physics_process(1.0/60)
		check(p.has_ball and p.dribble_ended and game.ball_owner==selection,"3v3 fake changed possession or allowed a new dribble")
		key(KEY_Q,true);game._physics_process(1.0/60);key(KEY_Q,false)
		check(game.phase=="pass_windup","3v3 could not pass after the held fake")
		cases+=1
	for state in ["square","held_fake"]:
		var p=game.players[0];p.action=state;p.has_ball=false;p.dribble_ended=true
		game.update_actions(1.0/60)
		check(p.action=="idle" and not p.dribble_ended and not p.held.valid,"Lost possession left a held-ball action running")
		cases+=1
	clear_keys();print("HELD_BALL cases=",cases," max_turn_rate=",max_turn_rate," max_pivot_drift=",max_pivot_drift," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
