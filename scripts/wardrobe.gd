class_name CourtWardrobe
extends RefCounted
## Cosmetic IDs only. Currency and ownership are authoritative on the server.
static var catalog: Dictionary = {}
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
	for surface in range(mesh.mesh.get_surface_count()):
		var source=mesh.mesh.surface_get_material(surface)
		if source.resource_name not in ["cloth","trim","leather"]:continue
		if chosen==defaults:
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
		for slot in chosen:
			var entry=item(chosen[slot])
			material.set_shader_parameter(slot+"_custom",chosen[slot]!=defaults[slot])
			for channel in ["base","panel","accent"]:material.set_shader_parameter(slot+"_"+channel,Color(entry[channel]))
			material.set_shader_parameter(slot+"_pattern",int(entry.pattern))
