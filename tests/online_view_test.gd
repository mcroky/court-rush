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
	var look=CourtWardrobe.data().defaults.duplicate()
	for item in CourtWardrobe.data().items:
		if item.get("form","")=="hoodie":look.jersey=item.id;break
	var athletes=[{"role":"guard","height":178,"speed":76,"shoot":70,"defense":60,"training":{"speed":12},"skills":{"cross":3},"appearance":{}},{"role":"center","height":204,"shoot":55,"defense":79,"training":{"rebound":10},"skills":{"rebound":2},"appearance":look}]
	for i in 2:authority.players[i].apply_athlete(athletes[i])
	authority.reset_positions(0)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	var initial=JSON.parse_string(JSON.stringify(authority.snapshot()))
	var data={"slot":1,"matchId":"qa-match","serverEpoch":"qa-epoch","participants":[{"nickname":"A","appearance":{},"athlete":athletes[0]},{"nickname":"B","appearance":look,"athlete":athletes[1]}],"state":initial}
	data=JSON.parse_string(JSON.stringify(data))
	game.web_input={"appearance":"{}","sound":false,"reduced":false,"x":0,"z":0,"shoot":false,"cross":false,"spin":false,"twostep":false,"behind":false,"hesi":false,"steal":false,"guard":false,"passBall":false,"switchPlayer":false,"controlReset":0,"switchSeq":0,"passSeq":0,"shootSeq":0,"shootCancelSeq":0,"commandId":123,"command":"online-begin","onlineMatch":JSON.stringify(data),"suspended":false,"onlineInputs":"[]","onlineSeq":0,"onlineState":JSON.stringify(initial),"onlineAxes":"[]","compactCamera":false}
	game.read_controls()
	var view=game.online_view
	check(view!=null,"JSON numeric slot enters online mode through the real command bridge")
	view.tick(0)
	check(view.hud().online and view.hud().onlineSlot==1,"second client owns its own HUD and camera")
	check(game.controlled_player()==game.players[1],"camera follows local slot rather than slot zero")
	check(game.players[0].court_role=="guard" and game.players[1].court_role=="center" and game.players[0].height_ratio<game.players[1].height_ratio,"career roles and physical heights are preserved")
	check(game.players[1].skinned.human_mesh.mesh.resource_path.contains("hoodie") and game.players[1].appearance.jersey==look.jersey,"slot one keeps its own equipped garment geometry")
	var p=game.players[1];var q=authority.players[1]
	check(p.position.distance_to(q.position)<.001,"render root agrees with authoritative root")
	var skeleton=p.skinned.skeleton
	var error=0.0
	for i in skeleton.get_bone_count(): error=maxf(error,skeleton.get_bone_pose(i).origin.distance_to(q.skinned.skeleton.get_bone_pose(i).origin))
	check(error<.0001,"replicated rig uses server bone translations within 0.1 mm")
	game.web_input=null
	var controls=[authority.ControlSlot.neutral(),authority.ControlSlot.neutral()]
	controls[1].x=1.0
	var palm_error=0.0
	for frame in 80:
		if frame==30:controls[1].shoot=true
		authority.step(1.0/60,controls)
		var state=JSON.parse_string(JSON.stringify(authority.snapshot()))
		view.push(state);view.render_time=state.time;view.tick(0)
		for side in 2:palm_error=maxf(palm_error,game.players[1].palm_position(side).distance_to(authority.players[1].palm_position(side)))
	print("ONLINE_PALM_ERROR=",palm_error)
	check(palm_error<.003,"moving and shooting display palms agree with authority within 3 mm")
	var clock=game.clock_left;game._physics_process(1.0/60)
	check(game.clock_left==clock,"client never advances the server match clock")
	authority.reset_positions(1)
	authority.step(1.0/60,[authority.ControlSlot.neutral(),authority.ControlSlot.neutral()])
	var latest=JSON.parse_string(JSON.stringify(authority.snapshot([-1,-1])))
	game.web_input={"onlineLocal":JSON.stringify({"enabled":true,"nextSeq":100}),"onlineInputs":"[]","onlineSeq":1,"onlineState":JSON.stringify(latest),"onlineAxes":"[]","compactCamera":false}
	for frame in 8:view.tick(1.0/60,authority.ControlSlot.neutral())
	var predicted=view.prediction.simulation.players[1]
	var exact_error=0.0
	for bone in skeleton.get_bone_count():
		var actual_pose=skeleton.get_bone_pose(bone)
		var expected_pose=predicted.skinned.skeleton.get_bone_pose(bone)
		exact_error=maxf(exact_error,actual_pose.origin.distance_to(expected_pose.origin))
		for axis in 3:exact_error=maxf(exact_error,actual_pose.basis[axis].distance_to(expected_pose.basis[axis]))
	check(view.prediction.weight==1 and exact_error<.000001,"full local prediction preserves all 45 rendered bone transforms without a second pose solve")
	check(game.players[1].palm_position(0).distance_to(predicted.palm_position(0))<.0001,"direct local rig copy preserves actual palm position within 0.1 mm")
	game.web_input.onlineLocal=JSON.stringify({"enabled":false,"nextSeq":100})
	for frame in 6:view.tick(1.0/60,authority.ControlSlot.neutral())
	view.render_time=float(latest.time);view.tick(0)
	check(view.prediction.weight==0 and game.players[1].position.distance_to(authority.players[1].position)<.001,"leaving prediction restores server rendering without retaining a speculative root")
	game.web_input=null
	game.start_mode("practice")
	check(game.online_view==null and game.mode=="practice","leaving online releases puppet mode")
	check(game.players[1].skinned.human_mesh.mesh.get_meta("opponent",false),"leaving restores the AI rival model")
	game.web_input=null;game.queue_free();authority.queue_free();await process_frame;quit(1 if failures else 0)
