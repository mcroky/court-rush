extends SceneTree
var failures=0
var checks=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	var hero=game.players[0];var rival=game.players[1]
	var ids={"jersey":"sunset_jersey","shorts":"slate_shorts","shoes":"ice_shoes"}
	var bones=hero.skinned.skeleton.get_bone_count()
	hero.apply_appearance(ids)
	for s in hero.skinned.human_mesh.mesh.get_surface_count():
		var mat=hero.skinned.human_mesh.mesh.surface_get_material(s)
		var changed=hero.skinned.human_mesh.get_surface_override_material(s)
		check(rival.skinned.human_mesh.get_surface_override_material(s)==null,"Outfit leaked to rival")
		if mat.resource_name in ["cloth","trim","leather"]:
			check(changed is ShaderMaterial,"Garment not overridden")
			check(changed.get_shader_parameter("jersey_custom"),"Jersey was not applied")
		else:check(changed==null,"Face or skin was overridden")
		var arrays=hero.skinned.human_mesh.mesh.surface_get_arrays(s)
		for uv in arrays[Mesh.ARRAY_TEX_UV]:
			if mat.resource_name in ["face","skin","hair","features"]:check(uv.x<4,"Skin received garment coordinates")
	check(hero.skinned.skeleton.get_bone_count()==bones and bones==45,"Clothing replaced the motion rig")
	for entry in CourtWardrobe.data().items:
		var outfit={entry.slot:entry.id}
		hero.apply_appearance(outfit)
		check(hero.appearance[entry.slot]==entry.id,"Catalog item failed to apply: "+entry.id)
		check(hero.skinned.human_mesh.mesh.get_surface_count()==7,"Clothing added draw-call surfaces")
	hero.apply_appearance(ids)
	hero.apply_athlete({});check(hero.appearance==CourtWardrobe.appearance(ids),"Practice reset removed clothing")
	game.start_mode("duel");game.set_paused(true)
	var clock=game.clock_left;var pos=hero.position;var phase=game.phase
	game.equipped_appearance=ids
	game.open_wardrobe({"appearance":{"jersey":"volt_jersey"},"athlete":{"role":"center","height":204},"yaw":PI/2})
	for frame in 60:game._physics_process(1.0/60)
	check(game.clock_left==clock and hero.position==pos and game.phase==phase,"Try-on advanced the current match")
	check(game.showroom_players[0].appearance.jersey=="volt_jersey","Try-on missing")
	check(not game.showroom_players[1].visible,"Rival occludes preview")
	game.close_wardrobe()
	check(not game.inspecting and game.paused,"Shop close reset or resumed the match")
	check(hero.appearance==CourtWardrobe.appearance(ids),"Unpurchased preview leaked into game")
	check(game.showroom_players[0].appearance==CourtWardrobe.appearance(ids),"Try-on remained after close")
	hero.apply_appearance({})
	for s in hero.skinned.human_mesh.mesh.get_surface_count():check(hero.skinned.human_mesh.get_surface_override_material(s)==null,"Default clothing didn't restore original materials")
	print("WARDROBE_ENGINE checks=",checks," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
