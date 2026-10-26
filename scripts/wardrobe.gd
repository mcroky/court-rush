class_name CourtWardrobe
extends RefCounted
## Cosmetic IDs only. Currency and ownership are authoritative on the server.
static var catalog: Dictionary = {}
static var meshes: Dictionary = {}
static func asset(path: String) -> Mesh:
	if not meshes.has(path):meshes[path]=load(path)
	return meshes[path]
static func data() -> Dictionary:
	if catalog.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/wardrobe.json"))
		if parsed is Dictionary:catalog=parsed
	return catalog
static func item(id: String) -> Dictionary:
	for entry in data().get("items",[]):
		if entry.id==id:return entry
	return {}
static func appearance(ids: Dictionary) -> Dictionary:
	var result: Dictionary=data().get("defaults",{}).duplicate()
	for slot in result:
		var entry=item(str(ids.get(slot,"")))
		if entry.get("slot","")==slot:result[slot]=entry.id
	return result
static func apply(mesh: MeshInstance3D,ids: Dictionary) -> void:
	var chosen=appearance(ids)
	var defaults=data().defaults
	if not mesh.has_meta("wardrobe_original"):mesh.set_meta("wardrobe_original",mesh.mesh)
	var original: Mesh=mesh.get_meta("wardrobe_original")
	var top=str(item(chosen.jersey).get("form","jersey"))
	var bottom=str(item(chosen.shorts).get("form","shorts"))
	var target=original
	if not original.get_meta("opponent",false) and (top!="jersey" or bottom!="shorts"):
		target=asset("res://assets/characters/outfits/%s_%s.res" % [top,bottom])
	if mesh.mesh!=target:
		for surface in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(surface,null)
		mesh.mesh=target
	var hat=item(chosen.hat)
	var hair=item(chosen.hair)
	var tucked=str(hat.form)!="none"
	var replace_hair=tucked or str(hair.form)!="original"
	var clothing_changed=false
	for slot in ["jersey","shorts","shoes"]:
		if chosen[slot]!=defaults[slot]:clothing_changed=true
	for surface in range(mesh.mesh.get_surface_count()):
		var source=mesh.mesh.surface_get_material(surface)
		if source.resource_name=="hair":
			var hidden: ShaderMaterial=null
			if replace_hair:
				hidden=ShaderMaterial.new()
				hidden.shader=preload("res://assets/characters/hidden_surface.gdshader")
			mesh.set_surface_override_material(surface,hidden)
			continue
		if source.resource_name not in ["cloth","trim","leather"]:continue
		if not clothing_changed:
			mesh.set_surface_override_material(surface,null)
			continue
		var material=mesh.get_surface_override_material(surface) as ShaderMaterial
		if material==null:
			material=ShaderMaterial.new()
			material.shader=preload("res://assets/characters/court_fabric.gdshader")
			material.set_shader_parameter("fabric",source.resource_name=="cloth")
			material.set_shader_parameter("vertex_srgb",source.resource_name!="cloth")
			material.set_shader_parameter("surface_kind",1 if source.resource_name=="trim" else 2 if source.resource_name=="leather" else 0)
			if source is ShaderMaterial:material.set_shader_parameter("jersey_mark",source.get_shader_parameter("jersey_mark"))
			mesh.set_surface_override_material(surface,material)
		for slot in ["jersey","shorts","shoes"]:
			var entry=item(chosen[slot])
			material.set_shader_parameter(slot+"_custom",chosen[slot]!=defaults[slot])
			for channel in ["base","panel","accent"]:material.set_shader_parameter(slot+"_"+channel,Color(entry[channel]))
			material.set_shader_parameter(slot+"_pattern",int(entry.pattern))
	apply_part(mesh,"WardrobeHair","res://assets/characters/headwear/hair_%s%s.res" % [hair.form,"_tucked" if tucked else ""],hair,replace_hair)
	apply_part(mesh,"WardrobeHat","res://assets/characters/headwear/hat_%s.res" % hat.form,hat,tucked)

static func apply_part(parent: MeshInstance3D,node_name: String,path: String,entry: Dictionary,enabled: bool) -> void:
	var part=parent.get_node_or_null(node_name) as MeshInstance3D
	if not enabled:
		if part!=null:part.visible=false
		return
	if part==null:
		part=MeshInstance3D.new()
		part.name=node_name
		parent.add_child(part)
		part.skin=parent.skin
		part.skeleton=NodePath("../..")
		part.extra_cull_margin=.6
	var desired=asset(path)
	if part.mesh!=desired:
		if part.mesh!=null:
			for surface in range(part.mesh.get_surface_count()):part.set_surface_override_material(surface,null)
		part.mesh=desired
	part.visible=true
	for surface in range(desired.get_surface_count()):
		var source=desired.surface_get_material(surface)
		var material=part.get_surface_override_material(surface) as StandardMaterial3D
		if material==null:material=source.duplicate();part.set_surface_override_material(surface,material)
		material.albedo_color=Color(entry.accent if source.resource_name=="hat_trim" else entry.base)
