extends SceneTree
var failures=0
var checks=0
var maximum_step=0.0
var maximum_ball_step=0.0
const Web=preload("res://tests/block_quick_input_test.gd")
func _init():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:
		failures+=1
		if failures<18:push_error(message)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false
	# A heading change must not rotate the captured world point around the hips.
	g.start_mode("practice")
	var p=g.players[0];p.position=Vector3.ZERO;p.rotation.y=0;p.facing=0;p.has_ball=true
	var contact=Vector3(.3,.45,.28)
	p.begin_pickup(contact,Vector3(6,-2,0));p.rotation.y=PI
	check(p.pickup_center().distance_to(contact)<.00001,"Pickup entry rotated with the receiving body")
	var previous=p.pickup_center()
	for f in 40:
		g.update_actions(1.0/60);p.position.x+=.012;p.facing=PI;p.animate(1.0/60,g.time)
		var current=p.ball_anchor(g.time)
		check(current.distance_to(previous)<.18,"Pickup/chest/dribble handoff jumped")
		previous=current
	check(p.action=="idle" and p.jump==0,"Pickup did not return to moving dribble")
	# Both modes retain world positions and the exit ball through the whistle,
	# then walk/jog back, visibly return the ball, and only then assign possession.
	for mode in ["duel","team"]:
		for event in ["block","rim"]:
			g.web_input=null;g.start_mode(mode);g.phase="loose";g.ball_owner=-1;g.last_event=event;g.shooter=1 if mode=="duel" else 3;g.loose_timer=.25
			for i in g.players.size():
				g.players[i].position=Vector3(-4+i*1.4,0,-3.2);g.players[i].action="idle";g.players[i].jump=0;g.players[i].motion=Vector2.ZERO;g.players[i].has_ball=false;g.players[i].reset_stance()
			g.ball.position=Vector3(7.49,.6,-3);g.ball_velocity=Vector3(8,-2,0)
			var positions=g.players.map(func(a):return a.position)
			if mode=="team":g.team_match.last_touch=0 if event=="block" else 3;g.team_match.update_loose(1.0/60)
			else:g.update_loose(1.0/60)
			check(g.phase=="check" and g.ball_owner<0,"Out-of-bounds instantly assigned a new carrier")
			for i in g.players.size():check(positions[i].distance_to(g.players[i].position)<.001,"Whistle teleported a player")
			g.web_input=Web.web();g.web_control_reset=-1
			var clock=g.clock_left;var ball_previous=g.ball.position;var frames=0
			while g.phase=="check" and frames<1000:
				g._physics_process(1.0/60)
				for i in g.players.size():
					var step=positions[i].distance_to(g.players[i].position);maximum_step=maxf(maximum_step,step)
					check(step<.18,"Check-ball return teleported a root")
					positions[i]=g.players[i].position
				maximum_ball_step=maxf(maximum_ball_step,ball_previous.distance_to(g.ball.position))
				check(ball_previous.distance_to(g.ball.position)<.55,"Check-ball return teleported the ball")
				ball_previous=g.ball.position;frames+=1
				check(g.clock_left==clock,"Stoppage consumed match time")
			var expected=(1 if event=="block" else 0) if mode=="duel" else (3 if event=="block" else 0)
			check(g.phase=="live" and g.ball_owner==expected,"Wrong or unfinished visible check-ball return")
			check(g.players[expected].action=="pickup","Check ball skipped receiving/secure motion")
	# A low, fast falling swat should be intercepted ahead, including its bounce.
	g.web_input=null;g.start_mode("duel");g.phase="loose";g.ball_owner=-1
	g.players[1].position=Vector3(-2,0,0);g.ball.position=Vector3(0,.75,0);g.ball_velocity=Vector3(6,-5,0)
	var target=g.loose_chase_target(g.players[1])
	check(target.x>.5 and not g.Rules.ball_outside(target),"Chaser targeted the old ball position instead of the bounce")
	g.players[1].position=Vector3(-.7,0,0);g.ball.position=Vector3(0,.45,0);g.ball_velocity=Vector3(2,-2,0);g.ai_decision=0;g.ai_freeze=0
	for f in 10:g.update_actions(1.0/60);g.update_ai(1.0/60);g.players[1].animate(1.0/60,g.time)
	check(absf(angle_difference(g.players[1].facing,PI*.5))<.35,"Loose-ball chaser faced the hoop while running sideways")
	check(g.players[1].loose_reach>.1,"Chaser never prepared hands/body before gathering a low ball")
	print("LOOSE_CONTINUITY checks=",checks," max_root_step_m=",maximum_step," max_ball_step_m=",maximum_ball_step," failures=",failures)
	g.web_input=null;g.queue_free();await process_frame;quit(1 if failures else 0)
