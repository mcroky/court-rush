extends SceneTree
const Authority=preload("res://scripts/online/duel_simulation.gd")
const View=preload("res://scripts/online/duel_view.gd")
var failures=0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if ok: print("PASS: ",message)
	else: push_error("FAIL: "+message); failures+=1
func run() -> void:
	var authority=Authority.new();root.add_child(authority)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	var initial=JSON.parse_string(JSON.stringify(authority.snapshot()))
	var data={"slot":1,"matchId":"qa-match","serverEpoch":"qa-epoch","participants":[{"nickname":"A","appearance":{}},{"nickname":"B","appearance":{}}],"state":initial}
	data=JSON.parse_string(JSON.stringify(data))
	game.web_input={"appearance":"{}","sound":false,"reduced":false,"x":0,"z":0,"shoot":false,"cross":false,"spin":false,"twostep":false,"behind":false,"hesi":false,"steal":false,"guard":false,"passBall":false,"switchPlayer":false,"controlReset":0,"switchSeq":0,"passSeq":0,"shootSeq":0,"shootCancelSeq":0,"commandId":123,"command":"online-begin","onlineMatch":JSON.stringify(data),"suspended":false,"onlineInputs":"[]","onlineSeq":0,"onlineState":JSON.stringify(initial),"onlineAxes":"[]","compactCamera":false}
	game.read_controls()
	var view=game.online_view
	check(view!=null,"JSON numeric slot enters online mode through the real command bridge")
	view.tick(0)
	check(view.hud().online and view.hud().onlineSlot==1,"second client owns its own HUD and camera")
	check(game.controlled_player()==game.players[1],"camera follows local slot rather than slot zero")
	var p=game.players[1];var q=authority.players[1]
	check(p.position.distance_to(q.position)<.001,"render root agrees with authoritative root")
	var skeleton=p.skinned.skeleton
	var error=0.0
	for i in skeleton.get_bone_count(): error=maxf(error,skeleton.get_bone_pose(i).origin.distance_to(q.skinned.skeleton.get_bone_pose(i).origin))
	check(error<.0001,"replicated rig uses server bone translations within 0.1 mm")
	var clock=game.clock_left;game._physics_process(1.0/60)
	check(game.clock_left==clock,"client never advances the server match clock")
	game.start_mode("practice")
	check(game.online_view==null and game.mode=="practice","leaving online releases puppet mode")
	game.web_input=null;game.queue_free();authority.queue_free();await process_frame;quit(1 if failures else 0)
