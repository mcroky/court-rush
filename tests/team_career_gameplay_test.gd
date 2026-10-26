extends SceneTree
var failures=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	var athlete={"role":"center","height":204,"level":3,"training":{"rebound":5},"skills":{"rebound":2},"appearance":{"jersey":"sunset_jersey"}}
	game.start_career({"mode":"team","matchId":"11111111-1111-4111-8111-111111111111","athlete":athlete,"opponents":[{"role":"guard","height":178},{"role":"forward","height":190},{"role":"center","height":204}]})
	var t=game.team_match
	check(game.mode=="team" and game.players.size()==6 and not game.career_match_id.is_empty(),"Growth ticket did not enter team mode")
	check(game.players[0].court_role=="center" and game.players[0].growth.training.rebound==5 and game.players[0].skill_rank("rebound")==2,"Personal growth was not applied")
	check(game.players[1].court_role!="center" and game.players[2].court_role!="center","Companion positions did not adapt")
	check(game.players[0].appearance.get("jersey","")=="sunset_jersey","Personal outfit was not applied")
	t.selected=0;t.capture_shot(0);game.shooter=0;game.flight_points=3;game.event_id+=1;t.register_score();t.register_score()
	check(t.controlled_stats.points==3 and game.scores[0]==3,"Personal score credited twice or not credited")
	t.selected=0;t.capture_shot(1);game.shooter=1;game.flight_points=2;game.event_id+=1;t.register_score()
	check(t.controlled_stats.points==3,"Uncontrolled teammate score counted as direct contribution")
	t.assist_candidate=0;t.assist_receiver=1;t.assist_until=game.time+6;t.capture_shot(1);game.event_id+=1;t.register_score()
	check(t.controlled_stats.assists==1,"Controlled pass assist not credited")
	t.record_contribution(1,"blocks");t.record_contribution(0,"rebounds");t.record_contribution(0,"steals")
	check(t.controlled_stats.blocks==0 and t.controlled_stats.rebounds==1 and t.controlled_stats.steals==1,"Controlled contribution ownership failed")
	t.reset(0);check(t.controlled_stats.points==3,"Check ball reset erased career stats")
	game.phase="live";var input=game.read_controls();input.x=.5
	for f in 90:t.tick(1.0/60,input)
	check(t.activity_seconds>1.4 and game.clock_left<179,"Direct activity did not advance with match time")
	var state={};t.decorate_state(state);check(state.careerStats.activeSeconds>=1 and state.careerStats.points==3,"Career result snapshot missing")
	game.start_mode("practice");check(game.career_match_id.is_empty() and game.players.size()==2,"Ordinary mode kept growth ticket")
	print("TEAM_CAREER_GAMEPLAY failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
