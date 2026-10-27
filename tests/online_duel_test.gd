extends SceneTree
const Simulation=preload("res://scripts/online/duel_simulation.gd")
const Controls=preload("res://scripts/online/duel_control.gd")
var failures=0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else: push_error("FAIL: "+message); failures+=1
func run() -> void:
	var game=Simulation.new(); root.add_child(game)
	game.reset_positions(0)
	check(game.players.size()==2 and game.players[0].skinned.initialized,"authority preserves actual contact rigs")
	check(game.players[0].height_ratio==game.players[1].height_ratio and game.players[0].court_role=="forward","same physical profile for both slots")
	game.players[1].position=game.players[0].position+Vector3.RIGHT
	for i in 30:
		game.players[1].action="idle";game.fake_shot(0)
		check(game.players[1].action=="idle","pump fake cannot force the other human to jump") if i==29 else null
	game.reset_positions(0)
	var inputs=[Controls.neutral(),Controls.neutral()]
	var before=game.players[1].position
	inputs[1].x=1.0
	for i in 30: game.step(1.0/60,inputs)
	check(game.players[1].position.x>before.x+.5,"second human moves without AI")
	inputs[1]=Controls.neutral()
	game.reset_positions(1)
	for i in 2: game.controllers[i].edges={}
	inputs[1].shoot=true
	for i in 70: game.step(1.0/60,inputs)
	check(game.shooter==1 and game.phase in ["flight","dead","loose"],"slot one gathers and releases real shot")
	var state=game.snapshot([1,2])
	check(state.players[0].boneCount==45 and state.players[1].boneCount==45,"45 bone poses replicate for both players")
	check(JSON.stringify(state).length()<4096,"snapshot remains below 4 KiB")
	var decoded=game.PoseCodec.decode(state.players[0].pose,45)
	var rig_error=0.0
	for i in 45:
		var bone=game.players[0].skinned.skeleton.get_bone_pose(i)
		rig_error=maxf(rig_error,bone.origin.distance_to(Vector3(decoded[i][4],decoded[i][5],decoded[i][6])))
	check(rig_error<.0001,"pose compression retains bone translations within 0.1 mm")
	var prediction=state.duplicate(true)
	prediction.phase="live";prediction.players[0].position=[-3,0,1];prediction.players[1].position=[3,0,1]
	prediction.players[0].predictable=true;prediction.players[0].motion=[0,0];prediction.acks=[-1,-1]
	var replay=Controls.Movement.replay(prediction,0,[{"seq":0,"x":1,"z":0,"age":.1}])
	check(replay.x>-3 and replay.x<-2.5,"unacknowledged ordinary movement is replayed with a bounded offset")
	prediction.acks=[0,-1]
	check(Controls.Movement.replay(prediction,0,[{"seq":0,"x":1,"z":0,"age":.1}]).x==-3,"acknowledged input is never applied twice")
	game.shooter=1; game.flight_points=3; game.event_id+=1
	game.register_score(); var score=game.scores[1]; game.register_score()
	check(game.scores[1]==score,"duplicate authority score ignored")
	game.reset_positions(0); game.scores=[2,0]; game.clock_left=.01
	inputs=[Controls.neutral(),Controls.neutral()]
	game.step(1.0/60,inputs)
	check(game.phase=="ended","authority clock finishes without client command")
	game.queue_free()
	print("ONLINE_DUEL_TEST failures=",failures)
	quit(1 if failures else 0)
