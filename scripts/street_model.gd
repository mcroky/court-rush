class_name StreetModel
extends RefCounted

static var materials: Dictionary = {}
static var ink: ShaderMaterial

static func material(color: String, detail: String = "") -> ShaderMaterial:
	var key = color + detail
	if materials.has(key): return materials[key]
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 cloth_color : source_color;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 tile = vec2(0.0);
uniform bool textured = false;
uniform bool face = false;
uniform bool skin = false;
uniform bool sleeve = false;
varying float front;
void vertex(){ front = NORMAL.z; }
void fragment(){
 float grain = sin(UV.x * 185.0) * sin(UV.y * 263.0);
 ALBEDO = cloth_color.rgb * (0.96 + grain * 0.025);
 if(textured){
  vec2 local_uv = UV;
  if(sleeve){local_uv.y = local_uv.y * 0.33 + 0.18;}
  vec2 uv = tile + clamp(local_uv,vec2(0.008),vec2(0.992)) * 0.5;
  if(skin){uv = vec2(0.018,0.012) + UV * vec2(0.055,0.06);}
  vec3 paint = texture(atlas,uv).rgb;
  if(face){ ALBEDO = mix(cloth_color.rgb, mix(paint * vec3(0.94,0.97,1.04),cloth_color.rgb,0.30),smoothstep(0.12,0.55,front)); }
  else if(skin){ALBEDO = mix(paint,cloth_color.rgb,0.55);}
  else { ALBEDO = paint * cloth_color.rgb; }
 }
 ROUGHNESS = 1.0;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cloth_color", Color(color))
	if not detail.is_empty():
		mat.set_shader_parameter("atlas", load("res://assets/textures/street-atlas-v04.png"))
		mat.set_shader_parameter("textured", true)
		mat.set_shader_parameter("face", detail == "face")
		mat.set_shader_parameter("skin", detail == "skin")
		mat.set_shader_parameter("sleeve", detail == "stripe_sleeve")
		mat.set_shader_parameter("tile", {"skin": Vector2.ZERO, "face": Vector2.ZERO, "jersey": Vector2(.5, 0), "stripe": Vector2(0, .5), "stripe_sleeve": Vector2(0, .5), "denim": Vector2(.5, .5)}[detail])
	materials[key] = mat
	return mat

# A continuous tailored silhouette, rather than a stack of spheres and cylinders.
# Ring = (height, half width, half depth). Smooth profile normals preserve shoulder volume.
static func loft(parent: Node3D, rings: Array, color: String, outlined: bool = true, detail: String = "") -> MeshInstance3D:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides = 32 if detail == "face" else 24
	for row in range(rings.size() - 1):
		for side in range(sides):
			for corner in [[0, 0], [1, 1], [1, 0], [0, 0], [0, 1], [1, 1]]:
				var ring: Vector3 = rings[row + corner[0]]
				var angle = float(side + corner[1]) / sides * TAU
				var p = Vector3(cos(angle) * ring.y, ring.x, sin(angle) * ring.z)
				var uv = Vector2(float(side + corner[1]) / sides, float(row + corner[0]) / (rings.size() - 1))
				if not detail.is_empty():
					uv = Vector2(cos(angle) * .5 + .5, 1 - (ring.x - rings[0].x) / (rings[-1].x - rings[0].x))
					if detail == "face": uv = Vector2(p.x / .264 + .5, (.17 - p.y) / .34)
				surface.set_uv(uv)
				var ring_index: int = row + corner[0]
				var previous: Vector3 = rings[maxi(0, ring_index - 1)]
				var next: Vector3 = rings[mini(rings.size() - 1, ring_index + 1)]
				var slope = (next - previous) / maxf(.001, next.x - previous.x)
				var normal_y = -(cos(angle) * cos(angle) * slope.y / ring.y + sin(angle) * sin(angle) * slope.z / ring.z)
				surface.set_normal(Vector3(cos(angle) / ring.y, normal_y, sin(angle) / ring.z).normalized())
				surface.add_vertex(p)
	# Close garment hems and the scalp so inside-facing outlines never read as holes.
	for end in [0, rings.size() - 1]:
		var ring: Vector3 = rings[end]
		for side in range(sides):
			var a = float(side) / sides * TAU
			var b = float(side + 1) / sides * TAU
			var points = [Vector3(0, ring.x, 0), Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z), Vector3(cos(b) * ring.y, ring.x, sin(b) * ring.z)]
			# Godot's front faces use clockwise winding (opposite the cross-product normal).
			if end == 0: points.reverse()
			for point in points:
				surface.set_normal(Vector3.DOWN if end == 0 else Vector3.UP)
				surface.set_uv(Vector2(.5, .5))
				surface.add_vertex(point)
	var result = MeshInstance3D.new()
	result.mesh = surface.commit()
	result.material_override = material(color, detail)
	parent.add_child(result)
	if outlined:
		if ink == null:
			ink = ShaderMaterial.new()
			var outline_shader = Shader.new()
			outline_shader.code = "shader_type spatial; render_mode cull_front, unshaded; void vertex(){VERTEX += NORMAL * 0.008;} void fragment(){ALBEDO=vec3(0.07,0.075,0.08);}"
			ink.shader = outline_shader
		var edge = MeshInstance3D.new()
		edge.mesh = result.mesh
		edge.material_override = ink
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		result.add_child(edge)
	return result
