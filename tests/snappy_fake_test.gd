extends SceneTree
var failures=0
var cases=0
var max_palm_speed=0.0
var max_knee_speed=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<24:push_error(message)
func key(code: Key,down: bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func clear_keys():
	for code in [KEY_D,KEY_A,KEY_Z,KEY_C,KEY_V,KEY_X,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:key(code,false)
func prepare(game,mode: String,index: int):
	clear_keys();game.start_mode(mode)
	for i in game.players.size():
		game.players[i].has_ball=i==index
		game.players[i].position=Vector3(6,0,3+i*.3)
	game.ball_owner=index;game.needs_clear=false
	if mode=="team":game.team_match.selected=index;game.team_match.decisions=99
	var p=game.players[index];p.position=Vector3(.6,0,-3.5);p.rotation.y=PI;p.facing=PI;p.reset_stance();p.feet_world.clear()
	for f in 20:game._physics_process(1.0/60)
	game.fake_shot(index)
	for f in 30:game._physics_process(1.0/60)
	return p
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		var dt=1.0/fps
		for kind in ["pivot","jab","pump","upunder","through","turn"]:
			var p=prepare(game,"practice",0);var v=p.skinned
			var origin=game.ball.position;var shown_at=-1.0;var ended_at=-1.0
			var old_palms=v.palm_world.duplicate();var old_knees=[]
			for chain in v.feet:old_knees.append(v.bone_world(chain[1]).origin)
			p.held.begin(p,kind,p.global_basis.x,game.ball.position)
			for f in int(fps*.70):
				game._physics_process(dt)
				if shown_at<0 and game.ball.position.distance_to(origin)>.27:shown_at=float(f+1)/fps
				if ended_at<0 and p.action=="idle":ended_at=float(f+1)/fps
				for i in 2:
					var knee=v.bone_world(v.feet[i][1]).origin
					var ks=knee.distance_to(old_knees[i])/dt;var ps=v.palm_world[i].distance_to(old_palms[i])/dt
					max_knee_speed=maxf(max_knee_speed,ks);max_palm_speed=maxf(max_palm_speed,ps)
					check(ks<18 and ps<14,"Fake snapped a joint: "+kind+" fps="+str(fps)+" knee="+str(ks)+" palm="+str(ps))
					old_knees[i]=knee;old_palms[i]=v.palm_world[i]
			check(shown_at>0 and shown_at<=.20,"Fake threat was still delayed: "+kind+" t="+str(shown_at))
			check(ended_at>0 and ended_at<=.54,"Fake remained locked too long: "+kind+" t="+str(ended_at))
			check(p.has_ball and p.dribble_ended and game.attempts==0,"Quick fake lost possession or restarted dribble")
			print("QUICK_FAKE ",fps," ",kind," threat=",shown_at," complete=",ended_at)
			cases+=1
		for mode in ["practice","team"]:
			var index=2 if mode=="team" else 0
			for direction in [KEY_UP,KEY_DOWN,KEY_LEFT,0]:
				var p=prepare(game,mode,index)
				if direction!=0:key(direction,true)
				key(KEY_D,true);game._physics_process(dt)
				check(p.finish_kind==("layup" if direction==KEY_UP else "shot"),"Post-fake direction chose wrong finish: "+mode+" dir="+str(direction))
				var released=false
				for f in int(fps*1.5):
					game._physics_process(dt)
					if game.phase=="takeoff":check(p.dribble_ended,"Step-through illegally restarted dribble")
					if game.phase=="flight":released=true
				check(released and game.attempts==1,"Post-fake finish did not release exactly once")
				cases+=1
		for mode in ["practice","team"]:
			var index=2 if mode=="team" else 0
			var early=prepare(game,mode,index)
			game.fake_shot(index)
			for f in maxi(1,int(fps*.10)):game._physics_process(dt)
			key(KEY_UP,true);key(KEY_D,true)
			for f in int(fps*.15)+1:game._physics_process(dt)
			check(early.action in ["gather","layup"] and early.finish_kind=="layup","Early Shoot after fake was lost or became a pivot")
			check(early.held.pending_shot_left==0,"Consumed Shoot repeated from the buffer")
			cases+=1
		for mode in ["practice","team"]:
			var index=2 if mode=="team" else 0
			var held_shot=prepare(game,mode,index)
			held_shot.held.begin(held_shot,"upunder",Vector3.ZERO,game.ball.position)
			key(KEY_D,true)
			for f in int(fps*.32)+1:game._physics_process(dt)
			check(held_shot.action=="gather" and held_shot.finish_kind=="shot","Held Shoot was swallowed during a longer fake")
			cases+=1
		var p=prepare(game,"practice",0)
		game.fake_shot(0)
		for f in maxi(1,int(fps*.10)):game._physics_process(dt)
		key(KEY_V,true);game._physics_process(dt);key(KEY_V,false)
		var chained=false
		for f in int(fps*.13)+1:
			game._physics_process(dt)
			if p.held.kind=="through":chained=true
		check(chained,"Early fake input was swallowed at "+str(fps)+" Hz")
		for f in fps:game._physics_process(dt)
		check(p.action=="idle" and p.held.pending_kind=="","A consumed input repeated after the fake")
		cases+=1
		game.fake_shot(0)
		for f in maxi(1,int(fps*.08)):game._physics_process(dt)
		key(KEY_C,true);game._physics_process(dt);key(KEY_C,false)
		game.set_paused(true);check(p.held.pending_kind=="","Pause retained a queued fake")
		game.set_paused(false)
		cases+=1
	for direction in [KEY_UP,0]:
		var p=prepare(game,"practice",0)
		p.rotation.y=0;p.facing=0;p.held.freeze(p,game.ball.position)
		if direction!=0:key(direction,true)
		key(KEY_D,true)
		for f in 100:game._physics_process(1.0/60)
		check(game.attempts==1 and p.finish_kind==("layup" if direction==KEY_UP else "shot"),"Facing-away turn lost post-fake finish intent")
		cases+=1
	clear_keys();print("SNAPPY_FAKE cases=",cases," max_knee_speed=",max_knee_speed," max_palm_speed=",max_palm_speed," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
