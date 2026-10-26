extends SceneTree
var failures=0
var frames=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func run():
	var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
	var v=a.skinned
	for top in ["court_teal","form_tee_1","form_hoodie_1","form_varsity_1"]:
		for pants in ["court_navy","form_joggers_1","form_cargo_1"]:
			a.apply_appearance({"jersey":top,"shorts":pants,"hat":"hat_cap_1","hair":"hair_curly_1"})
			check(v.human_mesh.skin.get_bind_count()==45,"New clothes replaced the skin")
			for name in ["WardrobeHair","WardrobeHat"]:
				var part=v.human_mesh.get_node(name)
				check(part.visible and part.skin==v.human_mesh.skin,"Accessory is not skinned to the player")
				check(part.get_node(part.skeleton)==v.skeleton,"Accessory points at wrong skeleton")
			for surface in v.human_mesh.mesh.get_surface_count():
				var arrays=v.human_mesh.mesh.surface_get_arrays(surface)
				var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
				for vertex in arrays[Mesh.ARRAY_VERTEX].size():
					var total=0.0
					for influence in 4:
						check(bones[vertex*4+influence]>=0 and bones[vertex*4+influence]<45,"Invalid garment bone")
						total+=weights[vertex*4+influence]
					check(absf(total-1)<.001,"Unnormalized garment skin weights")
			a.has_ball=true;a.dribble_ended=false;a.action="idle";a.position=Vector3.ZERO;a.facing=0;a.rotation.y=0;a.motion=Vector2.ZERO;a.reset_stance();a.feet_world.clear()
			for f in 100:
				a.steer_motion(Vector2(sin(f*.015)*3.5,3.0),24,1.0/60)
				a.position+=a.movement_step(1.0/60);a.animate(1.0/60,f/60.0)
				for chain in v.feet:
					for segment in [[chain[0],chain[1]],[chain[1],chain[2]]]:
						var expected=v.skeleton.get_bone_rest(segment[1]).origin.length()*v.render_scale
						check(absf(v.bone_world(segment[0]).origin.distance_to(v.bone_world(segment[1]).origin)-expected)<.001,"Outfit changed animated limb length")
				frames+=1
	for hair in ["hair_original","hair_buzz_1","hair_curly_1","hair_locs_1","hair_sidepart_1","hair_ponytail_1"]:
		for hat in ["hat_none","hat_cap_1","hat_cap_back_1","hat_beanie_1","hat_bucket_1"]:
			a.apply_appearance({"hair":hair,"hat":hat})
			a.animate(1.0/60,0)
			var part=v.human_mesh.get_node_or_null("WardrobeHair")
			check((part!=null and part.visible)==(hair!="hair_original" or hat!="hat_none"),"Default/custom hair visibility wrong")
	a.apply_appearance({})
	check(not v.human_mesh.get_node("WardrobeHat").visible and not v.human_mesh.get_node("WardrobeHair").visible,"Removing extras left them rendered")
	print("WARDROBE_FORMS_MOTION body_combinations=12 head_combinations=30 animated_frames=",frames," failures=",failures)
	a.queue_free();await process_frame;quit(1 if failures else 0)
