extends RefCounted
## Presentation only: poses and possession come from the authoritative contact rig.
const Rules=preload("res://scripts/rules.gd")
const PoseCodec=preload("res://scripts/online/pose_codec.gd")
const Movement=preload("res://scripts/online/movement_prediction.gd")
const LocalPrediction=preload("res://scripts/online/local_prediction.gd")
var prediction
var game
var slot=0
var match_id=""
var epoch=""
var sequence=-1
var snapshots: Array=[]
var current: Dictionary={}
var render_time=0.0
var labels: Array=[]
var nicknames: Array=[]
var event_seen=-1
var commands: Array=[]
var original_meshes: Array=[]
var local_text=""
var inputs_text=""
var local_meta: Dictionary={}

func _init(owner) -> void:
	game=owner

func start(data: Dictionary) -> void:
	slot=int(data.slot); match_id=str(data.matchId); epoch=str(data.serverEpoch)
	game.start_mode("duel")
	game.mode="online"; game.paused=false
	for i in 2:
		var mesh=game.players[i].skinned.human_mesh
		original_meshes.append(mesh.get_meta("wardrobe_original",mesh.mesh))
		mesh.set_meta("wardrobe_original",game.players[i].skinned.HumanPlayer)
		mesh.mesh=game.players[i].skinned.HumanPlayer
		game.players[i].apply_athlete(data.participants[i].get("athlete",{"role":"forward","height":190}))
		game.players[i].apply_appearance(data.participants[i].appearance)
		game.players[i].marker.visible=i==slot
		var label=Label3D.new(); game.add_child(label)
		nicknames.append(str(data.participants[i].nickname))
		label.text=""; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=36; label.pixel_size=.005; label.outline_size=8; label.no_depth_test=true
		labels.append(label)
	push(data.state)
	prediction=LocalPrediction.new()
	prediction.start(game,data)
	prediction.receive(current)

func stop() -> void:
	if prediction!=null: prediction.stop(); prediction=null
	for i in original_meshes.size():
		var mesh=game.players[i].skinned.human_mesh
		mesh.set_meta("wardrobe_original",original_meshes[i]);mesh.mesh=original_meshes[i]
		game.players[i].apply_appearance(game.equipped_appearance if i==0 else {})
	original_meshes.clear()
	for label in labels: label.queue_free()
	labels.clear()

func push(state: Dictionary) -> void:
	if not state.get("players",null) is Array or state.players.size()!=2: return
	if not snapshots.is_empty() and int(state.tick)<=int(snapshots[-1].tick): return
	for player in state.players:
		player.bones=PoseCodec.decode(str(player.pose),int(player.boneCount))
	current=state; snapshots.append(state)
	if prediction!=null: prediction.receive(state)
	if snapshots.size()==1 or absf(render_time-float(state.time))>.5: render_time=float(state.time)-.1
	while snapshots.size()>10: snapshots.pop_front()

func tick(delta: float, local_input: Dictionary={}) -> void:
	var web=game.web_input
	if web!=null:
		var next_local=str(web.get("onlineLocal","{}") if web is Dictionary else web.onlineLocal)
		if next_local!=local_text:
			local_text=next_local
			var meta=JSON.parse_string(local_text)
			if meta is Dictionary: local_meta=meta
		var next_inputs=str(web.onlineInputs)
		if next_inputs!=inputs_text:
			inputs_text=next_inputs
			var recent=JSON.parse_string(inputs_text)
			if recent is Array: commands=recent
		var seq=int(web.onlineSeq)
		if seq!=sequence:
			sequence=seq
			var state=JSON.parse_string(str(web.onlineState))
			if state is Dictionary: push(state)
		var right=game.camera.global_basis.x*Vector3(1,0,1)
		var down=game.camera.global_basis.z*Vector3(1,0,1)
		web.onlineAxes=JSON.stringify([right.normalized().x,right.normalized().z,down.normalized().x,down.normalized().z])
	if snapshots.is_empty(): return
	if prediction!=null:
		var local=local_input.duplicate()
		if local.is_empty(): local=preload("res://scripts/online/duel_control.gd").neutral()
		var right=game.camera.global_basis.x*Vector3(1,0,1)
		var down=game.camera.global_basis.z*Vector3(1,0,1)
		var direction=(right.normalized()*float(local.x)+down.normalized()*float(local.z)).limit_length()
		local.x=direction.x; local.z=direction.z
		prediction.tick(delta,local,int(local_meta.get("nextSeq",0)),web!=null and not local_input.is_empty() and bool(local_meta.get("enabled",false)))
	render_time=minf(render_time+delta,float(current.time))
	while snapshots.size()>2 and float(snapshots[1].time)<render_time: snapshots.pop_front()
	var a: Dictionary=snapshots[0]
	var b: Dictionary=snapshots[1] if snapshots.size()>1 else a
	var blend=clampf((render_time-float(a.time))/maxf(.0001,float(b.time)-float(a.time)),0,1)
	for i in 2:
		# The local sandbox already solved the complete pose at full prediction weight.
		if i==slot and prediction!=null and prediction.weight>=1.0: continue
		var first: Dictionary=a.players[i]; var second: Dictionary=b.players[i]
		var p=game.players[i]
		p.position=vector(first.position).lerp(vector(second.position),blend)
		p.rotation.y=lerp_angle(float(first.yaw),float(second.yaw),blend)
		p.body.transform=transform_of(first.body).interpolate_with(transform_of(second.body),blend)
		p.skinned.transform=transform_of(first.rig).interpolate_with(transform_of(second.rig),blend)
		p.skinned.model.transform=transform_of(first.model).interpolate_with(transform_of(second.model),blend)
		var skeleton: Skeleton3D=p.skinned.skeleton
		if first.bones.size()==skeleton.get_bone_count() and second.bones.size()==skeleton.get_bone_count():
			for j in skeleton.get_bone_count():
				var left: Array=first.bones[j]; var right_bone: Array=second.bones[j]
				skeleton.set_bone_pose_rotation(j,Quaternion(left[0],left[1],left[2],left[3]).normalized().slerp(Quaternion(right_bone[0],right_bone[1],right_bone[2],right_bone[3]).normalized(),blend))
				skeleton.set_bone_pose_position(j,Vector3(left[4],left[5],left[6]).lerp(Vector3(right_bone[4],right_bone[5],right_bone[6]),blend))
		p.action=str(second.action); p.action_time=float(second.actionTime)
		p.motion=Vector2(second.motion[0],second.motion[1]); p.dribble_ended=bool(second.held)
		p.jump=float(second.jump); p.defending=bool(second.guard); p.boxing_out=bool(second.boxout)
		p.has_ball=int(b.owner)==i; p.facing=p.rotation.y
		for side in 2:p.skinned.palm_world[side]=p.skinned.bone_world(p.skinned.arms[side][2])*p.skinned.palm_offsets[side]
		p.skinned.initialized=true
		labels[i].position=p.position+Vector3.UP*2.35
	game.ball.position=vector(a.ball).lerp(vector(b.ball),blend) if a.possessionRevision==b.possessionRevision else vector(b.ball)
	if prediction!=null and prediction.weight>0:
		var p=game.players[slot]; var source=prediction.simulation.players[slot]; var w=prediction.weight
		if w>=1.0:
			p.position=source.position; p.rotation.y=source.rotation.y
			p.body.transform=source.body.transform; p.skinned.transform=source.skinned.transform
			p.skinned.model.transform=source.skinned.model.transform
		else:
			p.position=p.position.lerp(source.position,w)
			p.rotation.y=lerp_angle(p.rotation.y,source.rotation.y,w)
			p.body.transform=p.body.transform.interpolate_with(source.body.transform,w)
			p.skinned.transform=p.skinned.transform.interpolate_with(source.skinned.transform,w)
			p.skinned.model.transform=p.skinned.model.transform.interpolate_with(source.skinned.model.transform,w)
		var skeleton=p.skinned.skeleton; var other=source.skinned.skeleton
		for j in skeleton.get_bone_count():
			if w>=1.0:
				skeleton.set_bone_pose(j,other.get_bone_pose(j))
			else:
				skeleton.set_bone_pose_rotation(j,skeleton.get_bone_pose_rotation(j).slerp(other.get_bone_pose_rotation(j),w))
				skeleton.set_bone_pose_position(j,skeleton.get_bone_pose_position(j).lerp(other.get_bone_pose_position(j),w))
		if prediction.active:
			p.action=source.action; p.motion=source.motion; p.action_time=source.action_time
			p.dribble_ended=source.dribble_ended; p.defending=source.defending; p.jump=source.jump
			p.boxing_out=source.boxing_out
		p.has_ball=int(b.owner)==slot; p.facing=p.rotation.y; p.skinned.initialized=true
		for side in 2: p.skinned.palm_world[side]=p.skinned.bone_world(p.skinned.arms[side][2])*p.skinned.palm_offsets[side]
		labels[slot].position=p.position+Vector3.UP*2.35
		if prediction.active and int(current.owner)==slot and prediction.simulation.phase in ["live","takeoff"]:
			game.ball.position=game.ball.position.lerp(prediction.simulation.ball.position,w)
	elif current.players[slot].get("predictable",false) and current.phase=="live" and a.possessionRevision==b.possessionRevision:
		var predicted=Movement.replay(current,slot,commands)
		var offset=(predicted-game.players[slot].position).limit_length(.65)
		if vector(current.players[slot].position).distance_to(vector(current.players[1-slot].position))>=1.6:
			game.players[slot].position+=offset
			labels[slot].position+=offset
			if int(b.owner)==slot and int(current.owner)==slot: game.ball.position+=offset
	game.time=render_time; game.phase=str(current.phase)
	game.ball_owner=int(current.owner); game.shooter=int(current.shooter)
	game.scores=current.score.duplicate(); game.clock_left=float(current.seconds)
	game.shot_clock=float(current.shotClock); game.needs_clear=bool(current.clear)
	game.shot_hold=float(current.charge)*.62
	game.frame_court(delta); game.update_ball_visual()
	if int(current.eventSequence)!=event_seen:
		event_seen=int(current.eventSequence)
		if current.event=="score": game.play_sound("swish",-9)
		elif current.event=="block": game.play_sound("block",-9)
		elif current.event=="rim": game.play_sound("rim",-12)

func hud() -> Dictionary:
	if current.is_empty(): return {}
	var player=current.players[slot]
	var own=int(current.owner)
	var scores_local=[current.score[slot],current.score[1-slot]]
	var defense=str(player.get("defense",""))
	var state={"ready":true,"started":true,"paused":false,"mode":"online","online":true,"phase":current.phase,"owner":0 if own==slot else 1 if own>=0 else -1,"score":scores_local,"seconds":ceili(float(current.seconds)),"shotClock":ceili(float(current.shotClock)),"clear":current.clear,"attempts":0,"makes":0,"headline":"","detail":"","feedback":false,"charge":current.charge if own==slot else 0,"crossReady":true,"event":current.event,"player":[player.position[0],player.position[2]],"ball":current.ball,"action":player.action,"sound":game.sound_enabled,"finish":(player.style if player.style!="jumper" else player.finish) if player.action in ["gather","shot"] else Rules.finish_type(vector(player.position),Vector2(player.motion[0],player.motion[1])),"sweet":Rules.release_bonus(game.shot_hold)>0 and player.action=="gather","drill":"free","slowPractice":false,"boxout":player.boxout,"guard":player.guard,"secured":player.action=="rebound","inspecting":false,"closeup":false,"motionPreview":0,"held":player.held,"courtRole":str(player.get("role","forward")),"canChangeRole":false,"careerMatchId":"","careerMode":"","careerStage":0,"defenseAction":defense if own!=slot else "","reboundWindow":defense=="rebound","onlineMatchId":match_id,"onlineSlot":slot,"onlineTick":current.tick}
	var viewport_size=game.get_viewport().get_visible_rect().size
	var names: Array=[]
	for i in 2:
		var screen=game.camera.unproject_position(labels[i].position)
		names.append({"name":nicknames[i],"x":screen.x/maxf(1,viewport_size.x),"y":screen.y/maxf(1,viewport_size.y),"self":i==slot})
	state["onlineNames"]=names
	state["onlinePrediction"]=prediction!=null and prediction.active
	if prediction!=null and prediction.active:
		var local=prediction.simulation.players[slot]
		state.action=local.action; state.held=local.dribble_ended
		state.guard=local.defending
		state.charge=prediction.simulation.shot_hold/.62 if own==slot and local.action=="gather" else 0
		state.sweet=Rules.release_bonus(prediction.simulation.shot_hold)>0 and local.action=="gather"
	return state

static func vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

static func transform_of(value: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(value[3],value[4],value[5],value[6]).normalized()).scaled(Vector3(value[7],value[8],value[9])),Vector3(value[0],value[1],value[2]))
