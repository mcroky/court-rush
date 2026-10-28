extends SceneTree
var game
var failures=0
func _init() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:print("PASS: ",label)
	else:failures+=1;push_error("FAIL: "+label)
func sample(tier: int,fps: int=60) -> Dictionary:
	game.start_career({"mode":"challenge","matchId":"","athlete":{"role":"forward","height":190},"opponents":[{"role":"guard","height":178}],"challenge":{"kind":"steal","tier":tier,"name":"steal","tag":"STEAL KING","description":"test","seconds":100,"rounds":8,"target":2}})
	var p=game.players[1]
	var initial=p.position
	var low=p.position;var high=p.position;var last=p.position
	var distance=0.0;var idle_time=0.0;var actions={};var max_step=0.0;var anchor_error=0.0
	for frame in int(fps*8.5):
		game._physics_process(1.0/fps)
		low=low.min(p.position);high=high.max(p.position)
		distance+=last.distance_to(p.position);max_step=maxf(max_step,last.distance_to(p.position));last=p.position
		if p.action=="idle":idle_time+=1.0/fps
		else:actions[p.action]=true
		anchor_error=maxf(anchor_error,game.ball.position.distance_to(p.ball_anchor(game.time)))
	check(game.ball_owner==1 and game.challenge.value==0 and game.challenge.rounds==0,"tier %d/%dHz does not auto-score, shoot or finish an attempt"%[tier,fps])
	check(max_step<7.5/fps+.02 and anchor_error<.001,"tier %d/%dHz keeps continuous root travel and actual rig ball anchor"%[tier,fps])
	return {"spanX":high.x-low.x,"spanZ":high.z-low.z,"distance":distance,"idle":idle_time,"actions":actions,"start":initial}
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	var easy=sample(1)
	check(easy.spanX>1.2 and easy.spanZ>.5 and easy.distance>4,"first tier visibly patrols across width and depth")
	check(easy.actions.is_empty(),"first tier leaves ordinary dribble timing available for beginners")
	var second=sample(2)
	check(second.actions.has("cross"),"second tier introduces a real crossover")
	for tier in [3,4,5]:
		var progress=sample(tier)
		var added={3:"behind",4:"hesi",5:"spin"}[tier]
		check(progress.actions.has(added),"tier %d introduces %s"%[tier,added])
	var hard=sample(6)
	check(hard.actions.size()>=3,"highest tier mixes at least three real dribble skills")
	check(hard.distance>easy.distance*1.4,"highest tier travels more quickly than the first tier")
	check(hard.idle>2.0,"highest tier still leaves ordinary dribble steal windows")
	for fps in [30,120]:
		var result=sample(6,fps)
		check(result.actions.size()>=3 and absf(result.distance-hard.distance)<hard.distance*.15,"advanced patrol and skill timing stay consistent at %dHz"%fps)
	# Returning from a completed attempt starts a fresh movement/skill schedule.
	game.challenge.complete(false)
	game.challenge.next_round()
	check(game.players[1].action=="idle" and game.players[1].has_ball,"next attempt resets the attacker without a stale skill")
	game.start_mode("practice");game.set_drill("steal")
	var start=game.players[1].position
	for frame in 120:game._physics_process(1.0/60)
	check(game.players[1].position.distance_to(start)<.001 and game.players[1].action=="idle","stationary Finish Lab steal practice stays stationary")
	print("STEAL_CHALLENGE_AI failures=",failures," easy=",easy," hard=",hard)
	game.queue_free();await process_frame;quit(1 if failures else 0)
