class_name CourtArt
extends RefCounted
const BALL_RADIUS = .125

static var materials: Dictionary = {}
static var ink: ShaderMaterial

static func material(hex: String, unlit: bool = false) -> StandardMaterial3D:
	var key = hex + str(unlit)
	if materials.has(key):
		return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.9
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unlit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = mat
	return mat

static func outline() -> ShaderMaterial:
	if ink == null:
		ink = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = "shader_type spatial; render_mode cull_front, unshaded; void vertex(){ VERTEX += NORMAL * 0.018; } void fragment(){ ALBEDO=vec3(0.055,0.08,0.11); }"
		ink.shader = shader
	return ink

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: String, outlined: bool = false) -> MeshInstance3D:
	var item = MeshInstance3D.new()
	item.mesh = shape
	item.material_override = material(color)
	item.position = pos
	parent.add_child(item)
	if outlined:
		var edge = MeshInstance3D.new()
		edge.mesh = shape
		edge.material_override = outline()
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.add_child(edge)
	return item

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: String, outlined: bool = false) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color, outlined)

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: String, outlined: bool = false) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 12
	shape.rings = 6
	var item = mesh(parent, shape, pos, color, outlined)
	item.scale = size
	return item

static func cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, color: String, outlined: bool = false) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 10
	return mesh(parent, shape, pos, color, outlined)

static func segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: String) -> MeshInstance3D:
	var item = cylinder(parent, (a + b) * 0.5, radius, radius, 1.0, color)
	align(item, a, b)
	return item

static func align(item: Node3D, a: Vector3, b: Vector3) -> void:
	item.position = (a + b) * 0.5
	var direction = (b - a).normalized()
	var side = Vector3.RIGHT
	if absf(direction.dot(side)) > 0.95:
		side = Vector3.FORWARD
	var z_axis = side.cross(direction).normalized()
	var x_axis = direction.cross(z_axis).normalized()
	item.basis = Basis(x_axis, direction, z_axis)
	item.scale.y = a.distance_to(b)

static func label(parent: Node3D, words: String, pos: Vector3, size: int, color: String) -> Label3D:
	var text = Label3D.new()
	text.text = words
	text.position = pos
	text.font_size = size
	text.pixel_size = 0.01
	text.modulate = Color(color)
	text.outline_size = 0
	text.no_depth_test = false
	parent.add_child(text)
	return text

static func arc(parent: Node3D, center: Vector3, radius: float, start: float, end: float, color: String, width: float = 0.028, count: int = 48) -> void:
	for i in range(count):
		var t = lerpf(start, end, float(i) / count)
		var u = lerpf(start, end, float(i + 1) / count)
		segment(parent, center + Vector3(cos(t) * radius, 0, sin(t) * radius), center + Vector3(cos(u) * radius, 0, sin(u) * radius), width, color)

static func floor_text(parent: Node3D, words: String, pos: Vector3, size: int, color: String) -> void:
	var text = label(parent, words, pos, size, color)
	text.rotation_degrees.x = -90

static func court(parent: Node3D) -> void:
	box(parent, Vector3(0, -0.32, 0), Vector3(60, .5, 60), "a2927c")
	box(parent, Vector3(0, -.05, -.225), Vector3(17, .25, 16), "45483e")
	var floor_mesh = box(parent, Vector3(0, .083, -.225), Vector3(15.5, .015, 14.5), "8d8877")
	floor_mesh.material_override = pavement("287e83")
	var key_mesh = box(parent, Vector3(0, .095, -4.325), Vector3(4.9, .015, 5.8), "a7624e")
	key_mesh.material_override = pavement("bf7047")
	var chalk = "e1d6bc"
	for x in [-BasketballRules.COURT_HALF_WIDTH, BasketballRules.COURT_HALF_WIDTH]:
		segment(parent, Vector3(x, .12, BasketballRules.COURT_BACK), Vector3(x, .12, BasketballRules.COURT_FRONT), .035, chalk)
	for z in [BasketballRules.COURT_BACK, BasketballRules.COURT_FRONT]:
		segment(parent, Vector3(-7.5, .12, z), Vector3(7.5, .12, z), .025, chalk)
	for x in [-2.45, 2.45]:
		segment(parent, Vector3(x, .13, -7.225), Vector3(x, .13, -1.425), .025, chalk)
		for z in [-5.3, -4.3, -3.3, -2.3]:
			segment(parent, Vector3(x, .13, z), Vector3(x + signf(x) * .3, .13, z), .026, chalk)
	segment(parent, Vector3(-2.45, .13, -1.425), Vector3(2.45, .13, -1.425), .025, chalk)
	arc(parent, Vector3(0, .13, -1.425), 1.8, 0, TAU, chalk, .025)
	var corner_angle = acos(BasketballRules.THREE_CORNER / BasketballRules.THREE_DISTANCE)
	arc(parent, Vector3(0, .13, BasketballRules.HOOP.z), BasketballRules.THREE_DISTANCE, corner_angle, PI - corner_angle, chalk, .025, 72)
	for x in [-BasketballRules.THREE_CORNER, BasketballRules.THREE_CORNER]:
		segment(parent, Vector3(x, .13, BasketballRules.COURT_BACK), Vector3(x, .13, BasketballRules.HOOP.z + sin(corner_angle) * BasketballRules.THREE_DISTANCE), .025, chalk)
	arc(parent, Vector3(0, .13, BasketballRules.HOOP.z), 1.25, 0, PI, chalk, .025)
	arc(parent, Vector3(0, .13, BasketballRules.COURT_FRONT), 1.8, PI, TAU, chalk, .025)
	floor_text(parent, "MAKE YOUR MOVE.", Vector3(0, .14, 3.8), 42, "c6bea5")
	floor_text(parent, "01", Vector3(-6.8, .15, -3.3), 100, "c6bea5")
	floor_text(parent, "ROKY / OPEN COURT", Vector3(0, .14, 7.5), 28, "d1b786")
	for origin in [Vector3(-7.3,.115,5),Vector3(6.8,.115,-3),Vector3(3.6,.115,8.7)]:
		for i in range(5):
			var a = origin + Vector3(sin(i * 2.2) * .12, 0, i * .24)
			var b = origin + Vector3(sin((i+1) * 2.2) * .12, 0, (i+1) * .24)
			segment(parent, a, b, .012, "696759")
	# Backboard and hoop: regulation-inspired height, deliberately bold silhouette.
	box(parent, Vector3(0, 1.85, -7.15), Vector3(0.22, 3.7, 0.22), "283b42")
	segment(parent, Vector3(0, 3.5, -7.15), Vector3(0, 3.5, -6.25), 0.11, "283b42")
	box(parent, Vector3(0, 3.6, -6.22), Vector3(2.0, 1.25, 0.11), "24373c", true)
	box(parent, Vector3(0, 3.6, -6.15), Vector3(1.83, 1.08, 0.04), "eee6cb")
	for x in [-0.39, 0.39]:
		box(parent, Vector3(x, 3.43, -6.117), Vector3(0.035, 0.52, 0.012), "d46b4f")
	for y in [3.17, 3.69]:
		box(parent, Vector3(0, y, -6.117), Vector3(0.8, 0.035, 0.012), "d46b4f")
	segment(parent, Vector3(0, 3.05, -6.1), Vector3(0, 3.05, -5.75), 0.045, "ea7643")
	arc(parent, Vector3(0, 3.05, -5.65), 0.23, 0, TAU, "ec8447", 0.02, 32)
	for i in range(12):
		var a = TAU * i / 12.0
		var b = a + 0.22
		segment(parent, Vector3(cos(a) * 0.21, 3.01, -5.65 + sin(a) * 0.21), Vector3(cos(b) * 0.14, 2.65, -5.65 + sin(b) * 0.14), 0.007, "f2dec5")
	arc(parent, Vector3(0, 2.82, -5.65), 0.18, 0, TAU, "f2dec5", 0.007, 24)
	arc(parent, Vector3(0, 2.65, -5.65), 0.14, 0, TAU, "f2dec5", 0.007, 24)
	# Court-side seating, fence and a hand-painted neighborhood mural.
	box(parent, Vector3(0, 1.4, -9.2), Vector3(22, 2.8, 0.3), "cc8b70")
	box(parent, Vector3(-3.3, 1.45, -9.01), Vector3(8.6, 2.4, 0.04), "273d43")
	var mural = label(parent, "COURT RUSH", Vector3(-3.3, 1.76, -8.96), 108, "efc96d")
	mural.rotation_degrees.z = -5
	label(parent, "THE GAME BELONGS TO THE STREETS", Vector3(-3.3, 0.82, -8.95), 22, "9fccc1")
	label(parent, "PLAY\nYOUR WAY", Vector3(4.9, 1.55, -8.96), 63, "f2e5c7")
	for x in [-9.4, 9.4]:
		for z in [-6.5, -2.0, 2.5, 7.0, 11.0]:
			segment(parent, Vector3(x, 0.1, z), Vector3(x, 2.5, z), 0.035, "344a49")
		for y in [0.55, 1.25, 1.95, 2.5]:
			segment(parent, Vector3(x, y, -7), Vector3(x, y, 11.4), 0.015, "48605a")
		for z in range(-7, 12):
			segment(parent, Vector3(x, 0.2, z), Vector3(x, 2.5, z + 0.65), 0.009, "48605a")
	for z in [-3.8, 2.0]:
		box(parent, Vector3(10.5, 0.57, z), Vector3(0.65, 0.15, 2.6), "b98153")
		box(parent, Vector3(10.8, 0.96, z), Vector3(0.1, 0.65, 2.6), "b98153")
		for zz in [-0.9, 0.9]:
			box(parent, Vector3(10.5, 0.3, z + zz), Vector3(0.6, 0.6, 0.1), "2c4144")
	for x in [-10.2, 10.2]:
		segment(parent, Vector3(x, 0, -7.7), Vector3(x, 5.4, -7.7), 0.065, "34434b")
		box(parent, Vector3(x, 5.35, -7.4), Vector3(0.65, 0.12, 0.8), "f3d8a5")
	var colors = ["b99f86", "b38775", "ad998b", "8c9290"]
	for i in range(8):
		var x = -19.0 + i * 5.0
		var h = 4.0 + (i % 3) * 1.8
		box(parent, Vector3(x, h * 0.5, -14.8 - (i % 2) * 2), Vector3(4.5, h, 4), colors[i % 4])
		box(parent, Vector3(x, h + 0.1, -14.8 - (i % 2) * 2), Vector3(4.7, 0.22, 4.2), "7e8179")
		for yy in range(1, int(h), 2):
			for xx in [-1.2, 0, 1.2]:
				box(parent, Vector3(x + xx, yy, -12.76 - (i % 2) * 2), Vector3(0.6, 0.9, 0.02), "596b6b")
	for pos in [Vector3(-12, 0, 3), Vector3(-12, 0, -8), Vector3(13, 0, -9)]:
		cylinder(parent, pos + Vector3(0, 1.5, 0), 0.13, 0.2, 3, "72694f")
		sphere(parent, pos + Vector3(0, 3.5, 0), Vector3(3, 3, 2.8), "71816a")
		sphere(parent, pos + Vector3(0.7, 4, 0), Vector3(2.1, 2.3, 2), "8d986e")

static func basketball(parent: Node3D) -> Node3D:
	var ball = Node3D.new()
	parent.add_child(ball)
	ball.scale = Vector3.ONE * (BALL_RADIUS * 2 / .46)
	sphere(ball, Vector3.ZERO, Vector3.ONE * 0.46, "ed9049", true)
	for axis in range(3):
		var ring = Node3D.new()
		ball.add_child(ring)
		if axis == 1:
			ring.rotation_degrees.x = 90
		elif axis == 2:
			ring.rotation_degrees.z = 90
		arc(ring, Vector3.ZERO, 0.232, 0, TAU, "453c36", 0.009, 24)
	return ball


static func pavement(color: String) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode specular_disabled;
uniform vec4 paint : source_color;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){float wear=noise(world.xz*.8)*.10+noise(world.xz*24.0)*.06;ALBEDO=paint.rgb*(.88+wear);ROUGHNESS=1.0;}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paint", Color(color))
	return mat
