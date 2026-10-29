extends SceneTree
## Only our existing CC BY 4.0 GDQuest clip enters the generation pipeline.
func pose(skeleton: Skeleton3D,rest: bool=false)->Array:
	var result=[]
	for i in skeleton.get_bone_count():
		var t=skeleton.get_bone_global_rest(i) if rest else skeleton.get_bone_global_pose(i)
		var q=t.basis.orthonormalized().get_rotation_quaternion()
		result.append([t.origin.x,t.origin.y,t.origin.z,q.x,q.y,q.z,q.w])
	return result
func _init():call_deferred("run")
func run():
	var model=load("res://assets/experiments/mannequiny/mannequiny.glb").instantiate();root.add_child(model)
	var skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
	var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if skeleton==null:skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var out={"license":"CC-BY-4.0","source":"GDQuest and contributors / Luciano Munoz","names":[],"parents":[],"rest":pose(skeleton,true),"clips":{}}
	for i in skeleton.get_bone_count():out.names.append(skeleton.get_bone_name(i));out.parents.append(skeleton.get_bone_parent(i))
	for key in ["idle","run"]:
		var selected=""
		for name in player.get_animation_list():
			if str(name).get_file().to_lower()==key:selected=name
		assert(not selected.is_empty(),str(player.get_animation_list()))
		player.play(selected);player.advance(0)
		var frames=[]
		for f in 61:
			player.seek(float(f)/60*player.current_animation_length,true)
			frames.append(pose(skeleton))
		out.clips[key]={"length":player.current_animation_length,"poses":frames}
	var file=FileAccess.open("res://artifacts/motionbricks-source.json",FileAccess.WRITE);file.store_string(JSON.stringify(out))
	print("MOTIONBRICKS_SOURCE names=",out.names," lengths=",out.clips.run.length,"/",out.clips.idle.length)
	quit()
