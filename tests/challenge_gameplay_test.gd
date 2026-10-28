extends SceneTree
var game
var failures=0
func _init():call_deferred("run")
func check(ok: bool,label: String):
	if not ok:failures+=1;push_error(label)
func setup(kind: String,tier: int=1):
	game.start_career({"mode":"challenge","matchId":"11111111-1111-4111-8111-111111111111","athlete":{"role":"forward","height":190},"opponents":[{"role":"guard","height":178},{"role":"forward","height":190}],"challenge":{"kind":kind,"tier":tier,"name":kind,"tag":kind,"description":"test","seconds":90 if kind=="two_one" else 120,"rounds":10 if kind in ["free_throw","three"] else 8,"target":3}})
func ticks(n: int):
	for f in n:game._physics_process(1.0/60)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	setup("three")
	for round_id in 10:
		game.challenge.rounds=round_id;game.challenge.next_round()
		check(game.Rules.shot_points(game.players[0].position)==3,"Three-point rack inside line: "+str(round_id))
	setup("free_throw")
	var input=game.read_controls();input.x=1;input.cross=true;game.challenge.filter_input(input)
	check(input.x==0 and not input.cross,"Set-shot drill movement not locked")
	game.begin_gather(0);game.shot_hold=.43;game.launch_shot(0)
	var start=game.players[0].position
	ticks(180)
	check(game.challenge.rounds==1,"Actual shot flight did not resolve a round")
	check(game.challenge.value<=1,"Duplicate shot event")
	game.challenge.next_round();game.begin_gather(0);game.challenge.round_time=10.1;ticks(130)
	check(game.challenge.rest<0 and game.players[0].action=="idle","Timed-out gather stalls next round")
	setup("free_throw")
	for frame in 3600:
		if game.phase=="ended":break
		if game.challenge.rest<0 and game.phase=="live" and game.players[0].action=="idle":
			game.begin_gather(0);game.shot_hold=.43;game.launch_shot(0)
		ticks(1)
	check(game.phase=="ended" and game.challenge.rounds==10,"Full ten-shot rack did not finish")
	setup("rebound")
	ticks(80)
	check(game.phase=="loose" or game.challenge.rounds==1,"Rim miss never creates a loose ball")
	game.players[0].action="idle";game.claim_ball(0)
	check(game.challenge.rounds==1 and game.challenge.value==0,"Ground pickup credited as air catch")
	game.challenge.next_round();game.players[0].action="rebound";game.players[0].jump=.5;game.claim_ball(0,true)
	check(game.challenge.value==1,"Air catch event not credited")
	setup("steal",6);var pos=game.players[1].position;ticks(50)
	check(game.players[1].position.distance_to(pos)>.02,"Steal rival never moves")
	check(game.challenge.value==0,"Passive defense credited steal")
	game.challenge.steal_result();game.challenge.steal_result()
	check(game.challenge.value==1 and game.challenge.rounds==1,"Steal duplicates within a possession")
	setup("two_one")
	check(game.team_match.active_ids==[0,3,4] and game.players.filter(func(p):return p.visible).size()==3,"One vs two roster")
	check(game.team_match.choose_receiver(0)==-1 and game.team_match.choose_receiver(3)==4,"Receiver selection includes hidden player")
	game.team_match.reset(1);ticks(600)
	check(game.team_match.selected==0 and (game.ball_owner<0 or game.ball_owner in [0,3,4]),"Inactive actor acquired ball or control")
	game.team_match.turnover("OUT OF BOUNDS","test",0);ticks(1500)
	check(game.phase!="check","One vs two check ball stuck")
	game.start_mode("team")
	check(game.team_match.active_ids.size()==6 and game.players.all(func(p):return p.visible),"Normal 3v3 roster not restored")
	game.start_mode("duel");check(not game.challenge.active and game.players.size()==2,"Challenge leaks into ordinary match")
	print("CHALLENGE_GAMEPLAY failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
