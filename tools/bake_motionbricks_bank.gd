extends SceneTree
## Only generated, retargeted rotations are packaged. No model or inference runtime.
func _init():
	var input="res://artifacts/motionbricks-authored-v2/bank.json"
	var data=JSON.parse_string(FileAccess.get_file_as_string(input))
	assert(data is Dictionary and data.schema==1)
	var bank=Resource.new()
	bank.set_meta("names",PackedStringArray(data.names))
	bank.set_meta("source_sha256",data.source_sha256)
	bank.set_meta("source_commit","54fc563aeaaf819a753d72cc9fdc6713989cdd43")
	for label in data.clips:
		var clip=data.clips[label]
		var packed=PackedFloat32Array()
		for frame in clip.rotations:
			for q in frame:
				assert(q.size()==4)
				for value in q:packed.append(value)
		bank.set_meta(label,{"frames":clip.rotations.size(),"phase":clip.phase,"duration":clip.duration,"rotations":packed})
	DirAccess.make_dir_recursive_absolute("res://assets/motionbricks")
	var error=ResourceSaver.save(bank,"res://assets/motionbricks/locomotion.res",ResourceSaver.FLAG_COMPRESS)
	assert(error==OK)
	print("MOTIONBRICKS_BAKE clips=",data.clips.size()," joints=",data.names.size())
	quit()
