extends SceneTree
var failures=0
var contacts=0
var minimum_escape=INF
const Web=preload("res://tests/block_quick_input_test.gd")
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func setup(g,mode:String):
	g.web_input=null;g.start_mode(mode)
	if mode=="practice":g.set_drill("block")
	else:
		var t=g.team_match;t.reset(1);t.selected=0;t.decisions=999
		for i in 6:
			g.players[i].position=Vector3((i-2)*2.5,0,2);g.players[i].motion=Vector2.ZERO;t.goals[i]=g.players[i].position
		g.players[3].position=Vector3(0,0,-3.3);t.goals[3]=g.players[3].position;g.ball_owner=3;g.players[3].has_ball=true
		g.begin_gather(3);g.players[3].finish_kind="shot";g.players[3].finish_running=false
	var p=g.players[0];p.position=Vector3(0,0,-4.1);p.reset_stance();p.feet_world.clear();g.face_target(0,g.players[1 if mode=="practice" else 3].position);p.rotation.y=p.facing
	var input=Web.web();g.web_input=input;g.web_control_reset=-1;g.web_shoot_seq=0
	return input
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false
	for fps in [30,60,120]:
		var dt=1.0/fps
		for mode in ["practice","team"]:
			var input=setup(g,mode)
			for f in roundi(.33*fps):g._physics_process(dt)
			input.shootSeq=1
			var hit=false
			for f in fps:
				if mode=="team" and f==roundi(.13*fps):g.launch_shot(3)
				g._physics_process(dt)
				if g.players[0].block_contact:hit=true;contacts+=1;break
			check(hit,"Real block fixture missed %s %s fps"%[mode,fps])
			if not hit:continue
			var origin=g.ball.position;var previous=origin
			for f in ceili(.16*fps):
				g._physics_process(dt)
				check(g.phase=="loose" and g.ball_owner<0,"Swat was recaptured inside the escape window")
				check(g.ball.position.distance_to(previous)<.65,"Block teleported the ball out of a body")
				previous=g.ball.position
			var distance=g.ball.position.distance_to(origin);minimum_escape=minf(minimum_escape,distance)
			check(distance>1.25,"Block failed to send the ball clearly outside the contact bodies")
			# Force a body overlap: every participant, including a nearby third
			# player, is unable to gather during the strike but can gather later.
			for owner in ([0,1] if mode=="practice" else [0,3,4]):
				g.phase="loose";g.last_event="block";g.loose_timer=0;g.ball_owner=-1
				g.ball.position=Vector3(0,1.1,0);g.previous_ball_position=g.ball.position;g.ball_velocity=Vector3.ZERO
				for i in g.players.size():
					var p=g.players[i];p.action="idle";p.jump=0;p.has_ball=false;p.position=Vector3(5,0,4)
				g.players[owner].position=Vector3.ZERO
				if mode=="team":g.team_match.update_loose(dt)
				else:g.update_loose(dt)
				check(g.ball_owner<0,"Body contact caught the initial swat %s owner=%s"%[mode,owner])
				g.loose_timer=.19
				if mode=="team":g.team_match.update_loose(dt)
				else:g.update_loose(dt)
				check(g.ball_owner==owner,"Playable loose ball remained locked after escape %s owner=%s"%[mode,owner])
	# The selected lane must avoid the occupied flank in a six-player scrum.
	g.web_input=null;g.start_mode("team");g.shooter=3
	for i in 6:g.players[i].position=Vector3(1.1,0,float(i%3)*.25);g.players[i].jump=0;g.players[i].motion=Vector2.ZERO
	g.players[0].position=Vector3(0,0,-.7);g.players[3].position=Vector3(0,0,.4);g.ball.position=Vector3(0,2,0)
	check(g.block_escape_direction(g.players[0]).x<-.7,"Swat chose a crowded flank instead of open court")
	g.players[0].position=Vector3(-.7,0,-6.2);g.players[3].position=Vector3(0,0,-5.7);g.ball.position=Vector3(-.1,2,-6.2)
	check(not g.Rules.ball_outside(g.ball.position+g.block_escape_direction(g.players[0])*8*.4),"Swat preferred the baseline despite an open in-bounds flank")
	for mode in ["duel","team"]:
		for event in ["block","rim"]:
			g.start_mode(mode);g.phase="loose";g.ball_owner=-1;g.loose_timer=0;g.last_event=event;g.shooter=1 if mode=="duel" else 3
			g.ball.position=Vector3(7.6,1,-3);g.ball_velocity=Vector3.RIGHT
			if mode=="team":g.team_match.last_touch=0 if event=="block" else 3;g.team_match.update_loose(1.0/60)
			else:g.update_loose(1.0/60)
			check(g.phase=="check" and g.ball_owner<0,"Out-of-bounds skipped its visible stoppage")
			for frame in 1200:
				if g.phase!="check":break
				g.check_ball.tick(g,1.0/60)
			if g.phase=="check":
				for id in g.players.size():print("CHECK_WAIT ",mode," ",event," id=",id," action=",g.players[id].action," offset=",g.players[id].position.distance_to(g.CheckBall.spot(id,g.check_ball.next_side,mode=="team"))," motion=",g.players[id].motion)
			check(g.ball_owner==((1 if event=="block" else 0) if mode=="duel" else (3 if event=="block" else 0)),"Wrong check-ball ownership after %s %s went out"%[mode,event])
	g.last_event="block";g.phase="loose";g.loose_timer=0;g.shooter=4
	g.start_mode("practice");g.set_drill("rebound")
	check(not g.block_escape_active() and g.shooter<g.players.size(),"Mode/drill restart retained a previous team's block state")
	print("BLOCK_DEFLECTION actual_contacts=",contacts," minimum_escape_m=",minimum_escape," body/hand gather lock and later possession, open 3v3 lane failures=",failures)
	g.web_input=null;g.queue_free();await process_frame;quit(1 if failures else 0)
