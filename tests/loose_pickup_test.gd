extends SceneTree
var failures=0
var cases=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<18:push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for mode in ["practice","duel","team"]:
		for height in [.20,.95,1.50,1.85]:
			for velocity in [-4.0,4.0]:
				for action in ["idle","block","shot"]:
					game.start_mode(mode)
					for i in game.players.size():
						game.players[i].has_ball=false;game.players[i].position=Vector3(5,0,3+i*.25)
					var p=game.players[0];p.position=Vector3.ZERO;p.action=action;p.jump=.15 if action=="shot" else 0.0
					p.animate(1.0/60,0)
					game.phase="loose";game.ball_owner=-1;game.shooter=1;game.loose_timer=0
					game.ball.position=Vector3(0,height+p.jump,0);game.ball_velocity=Vector3(0,velocity,0)
					if mode=="team":game.team_match.update_loose(.01)
					else:game.update_loose(.01)
					check(game.ball_owner==0 and p.has_ball and p.action=="pickup","First-bounce body contact missed: "+mode+" "+str(height)+" "+action)
					check(game.ball.position.distance_to(p.pickup_center())<.001,"Pickup teleported away from its contact")
					for f in 70:game.update_actions(1.0/60)
					check(p.action=="idle" and p.jump==0,"Pickup stranded a jumping actor")
					cases+=1
	game.start_mode("practice");var p=game.players[0];p.position=Vector3.ZERO;p.has_ball=false;p.animate(.016,0)
	for pos in [Vector3(0,3.2,0),Vector3(1.5,1.0,0)]:
		game.phase="loose";game.ball_owner=-1;game.ball.position=pos;game.ball_velocity=Vector3.ZERO;game.loose_timer=0
		game.update_loose(.01);check(game.ball_owner==-1,"Noncontact ball was vacuumed into player");cases+=1
	game.phase="loose";game.ball_owner=-1;game.ball.position=Vector3(-1,1,0);game.ball_velocity=Vector3(200,0,0)
	game.update_loose(.01);check(game.ball_owner==0,"Fast ball passed through the body between ticks");cases+=1
	print("LOOSE_PICKUP cases=",cases," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
