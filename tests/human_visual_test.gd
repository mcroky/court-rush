extends SceneTree
var failures=0
var vertices_checked=0
var triangles=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func deform(a: Array,index: int,matrices: Array) -> Vector3:
	var result=Vector3.ZERO
	for j in range(4):result+=matrices[a[Mesh.ARRAY_BONES][index*4+j]]*a[Mesh.ARRAY_VERTEX][index]*a[Mesh.ARRAY_WEIGHTS][index*4+j]
	return result
func matrices_for(visual) -> Array:
	var result=[]
	var skin=visual.human_mesh.skin
	for i in range(skin.get_bind_count()):
		var bone=visual.skeleton.find_bone(skin.get_bind_name(i))
		result.append(visual.skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(i))
	return result
func run():
	var source_hash=FileAccess.get_sha256("res://assets/experiments/mannequiny/mannequiny.glb")
	check(source_hash=="8005cc2ab9221ad605be2d1cbb89eea894583e72bd5f50a5fbe40243a64f0493","Original rig asset changed")
	for opponent in [false,true]:
		var actor=load("res://scripts/actor.gd").new()
		root.add_child(actor)
		actor.setup(opponent)
		actor.has_ball=true
		actor.animate(1.0/60,0)
		var visual=actor.skinned
		var human=visual.human_mesh
		check(not actor.body.visible and human.visible,"Match did not replace the mannequin")
		check(visual.skeleton.get_bone_count()==45 and human.skin.get_bind_count()==45,"Human changed the skeleton")
		check(human.get_node(human.skeleton)==visual.skeleton,"New mesh uses a different skeleton")
		for other in visual.model.find_children("*","MeshInstance3D"):
			if other!=human:check(not other.visible,"Original mannequin still renders")
		check(human.mesh.get_meta("art_version","")=="human-v2","Missing human mesh")
		var parts={};var arrays=[];var mixed=0;var tri_count=0
		for surface in range(human.mesh.get_surface_count()):
			var a=human.mesh.surface_get_arrays(surface)
			arrays.append(a)
			parts[human.mesh.surface_get_material(surface).resource_name]=true
			tri_count+=a[Mesh.ARRAY_INDEX].size()/3
			for i in range(a[Mesh.ARRAY_VERTEX].size()):
				var total=0.0;var influences=0
				check(a[Mesh.ARRAY_VERTEX][i].is_finite() and a[Mesh.ARRAY_NORMAL][i].is_finite(),"Non-finite human geometry")
				check(a[Mesh.ARRAY_TEX_UV][i].is_finite(),"Invalid human UV")
				check(a[Mesh.ARRAY_NORMAL][i].length()>.95,"Invalid human normals")
				for j in range(4):
					var w=a[Mesh.ARRAY_WEIGHTS][i*4+j]
					check(a[Mesh.ARRAY_BONES][i*4+j]>=0 and a[Mesh.ARRAY_BONES][i*4+j]<45,"Invalid skin bind")
					check(w>=0 and w<=1,"Invalid bone weight")
					total+=w
					if w>.01:influences+=1
				check(absf(total-1)<.0001,"Unnormalized skin weights")
				if influences>1:mixed+=1
				vertices_checked+=1
		for name in ["skin","cloth","trim","face","features","hair","leather"]:check(parts.has(name),"Missing human appearance part "+name)
		check(mixed>300,"Human body does not blend across joints")
		check(tri_count<14000 and human.mesh.get_surface_count()<=7,"Appearance exceeded mobile prototype geometry budget")
		triangles+=tri_count
		var first=matrices_for(visual)
		var excursion=0.0
		for f in range(75):
			var dt=1.0/60
			actor.steer_motion(Vector2(0,4.7),24,dt)
			actor.position+=actor.movement_step(dt)
			actor.animate(dt,f*dt)
			if f%5:continue
			var matrices=matrices_for(visual)
			for a in arrays:
				for i in range(0,a[Mesh.ARRAY_VERTEX].size(),7):
					var p=deform(a,i,matrices)
					check(p.is_finite() and p.length()<3.5,"Human skin exploded during running/dribbling")
					excursion=maxf(excursion,p.distance_to(deform(a,i,first)))
		check(excursion>.15,"Human skin did not follow the running rig")
		print("HUMAN variant=",opponent," triangles=",tri_count," mixed_joint_vertices=",mixed," animated_excursion=",excursion)
		actor.queue_free()
		await process_frame
	var lab=load("res://scenes/character_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	for mode in ["idle","handle","hold","run","dribble","cross","cut","shot"]:
		lab.mode=mode
		for f in range(200):lab._physics_process(1.0/60)
		for actor in lab.athletes:check(actor.skinned.human_mesh.visible,"Appearance preview lost the human mesh")
	for view in ["face","jersey","side","back","full"]:
		lab.mode="idle"
		lab.view=view
		lab._physics_process(1.0/60)
		check(lab.camera.global_position.is_finite(),"Invalid appearance camera")
		for actor in lab.athletes:
			var left=actor.to_local(actor.skinned.toe_world[0])
			var right=actor.to_local(actor.skinned.toe_world[1])
			check(right.x-left.x>.15,"Presentation view turn crossed the planted feet view=%s left=%s right=%s action=%s" % [view,str(left),str(right),actor.action])
	lab.queue_free()
	await process_frame
	print("HUMAN_VISUAL vertices=",vertices_checked," triangles=",triangles," failures=",failures)
	quit(1 if failures else 0)
