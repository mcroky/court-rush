extends SceneTree
## Original COURT RUSH character geometry. Uses the existing, unmodified named skin binds.
## Run with Godot --headless --path . --script tools/build_player_mesh.gd.
var surfaces: Dictionary = {}
var source_skin: Skin
var bind: Dictionary = {}
var neutral: Dictionary = {}
var rival = false
var skin_color: Color
var jersey: Color
var dark: Color
var cream = Color("efe4c6")
var mesh: ArrayMesh
const Fabric = preload("res://assets/characters/court_fabric.gdshader")
const Face = preload("res://assets/characters/court_face.gdshader")
var authoring_head=false

func _init(): call_deferred("run")
func run():
	var model = load("res://assets/experiments/mannequiny/mannequiny.glb").instantiate()
	root.add_child(model)
	source_skin = model.find_children("*","MeshInstance3D")[0].skin
	for i in range(source_skin.get_bind_count()):
		var name = str(source_skin.get_bind_name(i))
		bind[name] = i
		neutral[name] = source_skin.get_bind_pose(i).affine_inverse()
	DirAccess.make_dir_recursive_absolute("res://assets/characters")
	for opponent in [false,true]:
		rival = opponent
		build()
		var path = "res://assets/characters/rush_rival.res" if rival else "res://assets/characters/rush_player.res"
		var err = ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
		assert(err==OK)
		var tris = 0
		for s in range(mesh.get_surface_count()): tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
		print("HUMAN_MESH ",path," surfaces=",mesh.get_surface_count()," triangles=",tris," aabb=",mesh.get_aabb())
	quit()

func weights(a: String,b: String="",t: float=0.0) -> Array:
	return [PackedInt32Array([bind[a],bind[b] if not b.is_empty() else 0,0,0]),PackedFloat32Array([1-t,t,0,0])]
func torso_weights(y: float) -> Array:
	if y<1.15: return weights("pelvis","spine_01",smoothstep(1.01,1.15,y))
	return weights("spine_01","spine_02",smoothstep(1.15,1.36,y))
func surface(key: String) -> SurfaceTool:
	if not surfaces.has(key):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0)
		surfaces[key] = st
	return surfaces[key]
func vertex(st: SurfaceTool,p: Vector3,n: Vector3,uv: Vector2,c: Color,w: Array):
	st.set_normal(n.normalized())
	st.set_uv(uv)
	# Graphics live in garment UV space, so they deform with every fold.
	st.set_uv2(Vector2(.5+p.x/.16*(1 if n.z>=0 else -1),(1.365-p.y)/.26))
	st.set_color(c)
	st.set_bones(w[0])
	st.set_weights(w[1])
	if authoring_head:
		p=Vector3(p.x*.94,1.573+(p.y-1.573)*.93,p.z*.94)
	st.add_vertex(p)
func tri(key: String,p: Array,n: Array,u: Array,c: Color,w: Array):
	var order = [0,1,2]
	if (p[1]-p[0]).cross(p[2]-p[0]).dot(n[0]+n[1]+n[2])>0: order = [0,2,1]
	var st = surface(key)
	for i in order: vertex(st,p[i],n[i],u[i],c,w[i])

# Row: [center, half-width, half-depth, weights]. Axis y follows the limb.
func loft(key: String,rows: Array,color: Color,axis: Vector3=Vector3.UP,sides: int=20,fold: float=0.0):
	var x = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT))<.85 else Vector3.FORWARD
	x = (x-axis*x.dot(axis)).normalized()
	var z = x.cross(axis).normalized()
	for r in range(rows.size()-1):
		for side in range(sides):
			var pts = []
			var ns = []
			var uv = []
			var ws = []
			for rc in [[r,side],[r+1,side],[r+1,side+1],[r,side+1]]:
				var row: Array = rows[rc[0]]
				var a = float(rc[1])/sides*TAU
				var ripple = 1+fold*sin(a*7+row[0].y*26)*sin(float(rc[0])/(rows.size()-1)*PI)
				pts.append(row[0]+(x*cos(a)*row[1]+z*sin(a)*row[2])*ripple)
				var before: Array = rows[maxi(0,rc[0]-1)]
				var after: Array = rows[mini(rows.size()-1,rc[0]+1)]
				var d = maxf(.0001,absf((after[0]-before[0]).dot(axis)))
				var slope = -((after[1]-before[1])*cos(a)*cos(a)/maxf(.001,row[1])+(after[2]-before[2])*sin(a)*sin(a)/maxf(.001,row[2]))/d
				ns.append((x*cos(a)/maxf(.001,row[1])+z*sin(a)/maxf(.001,row[2])+axis*slope).normalized())
				uv.append(Vector2(float(rc[1])/sides,float(rc[0])/(rows.size()-1)))
				ws.append(row[3])
			for order in [[0,1,2],[0,2,3]]:
				var p=[];var n=[];var u=[];var w=[]
				for i in order: p.append(pts[i]);n.append(ns[i]);u.append(uv[i]);w.append(ws[i])
				tri(key,p,n,u,color,w)

func path(key: String,points: Array,radius: float,color: Color,bone: String):
	# Slim sculpted piping, eyelids and seams. Every vertex follows the named bone.
	for i in range(points.size()-1):
		var axis: Vector3 = (points[i+1]-points[i]).normalized()
		loft(key,[[points[i],radius,radius,weights(bone)],[points[i+1],radius,radius,weights(bone)]],color,axis,8)
func oval(key: String,center: Vector3,size: Vector3,color: Color,bone: String):
	var rows=[]
	for i in range(9):
		var a = -PI/2+PI*i/8.0
		rows.append([center+Vector3.UP*sin(a)*size.y,maxf(.0002,cos(a)*size.x),maxf(.0002,cos(a)*size.z),weights(bone)])
	loft(key,rows,color,Vector3.UP,20)

func build():
	surfaces.clear()
	mesh = ArrayMesh.new()
	mesh.resource_name = "COURT RUSH / human athlete / " + ("23" if rival else "07")
	skin_color = Color("9f6c50" if rival else "b98060")
	jersey = Color("ca5933" if rival else "246763")
	dark = Color("27323d" if rival else "172e39")
	make_torso()
	for suffix in [".r",".l"]:
		make_arm(suffix)
		make_leg(suffix)
	make_head()
	for key in surfaces:
		var st: SurfaceTool = surfaces[key]
		var material: Material
		if key=="face":
			var m=ShaderMaterial.new()
			m.shader=Face
			m.set_shader_parameter("face_map",load("res://assets/characters/face-painted-v2.png"))
			m.set_shader_parameter("skin_tone",skin_color)
			material=m
		elif key=="cloth":
			var m=ShaderMaterial.new()
			m.shader=Fabric
			m.set_shader_parameter("fabric",true)
			m.set_shader_parameter("jersey_mark",load("res://assets/characters/jersey_23.svg" if rival else "res://assets/characters/jersey_07.svg"))
			material=m
		else:
			var m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = .95
			material = m
		material.resource_name = key
		st.set_material(material)
		if key in ["cloth","hair","face"]:st.generate_normals()
		st.index()
		st.optimize_indices_for_cache()
		st.commit(mesh)
	mesh.set_meta("art_version","human-v2")
	mesh.set_meta("source_rig","mannequiny-0.3.0 / 45 named binds")
	mesh.set_meta("opponent",rival)

func make_torso():
	# Skin neckline and trapezius under the open shoulder straps.
	loft("skin",[[Vector3(0,1.32,.022),.169,.078,torso_weights(1.32)],[Vector3(0,1.405,.008),.177,.079,torso_weights(1.405)],[Vector3(0,1.431,.001),.168,.076,weights("spine_02")],[Vector3(0,1.451,-.005),.139,.067,weights("spine_02","neck_01",.12)],[Vector3(0,1.469,-.009),.095,.056,weights("spine_02","neck_01",.3)],[Vector3(0,1.487,-.012),.052,.043,weights("neck_01")],[Vector3(0,1.522,-.010),.040,.041,weights("neck_01")],[Vector3(0,1.566,-.003),.043,.042,weights("neck_01","head",.65)]],skin_color)
	var profile = [[1.005,.147,.091],[1.045,.162,.104],[1.13,.141,.090],[1.23,.168,.105],[1.31,.187,.108]]
	# Tailored tank: top boundary cuts both armholes and the U neckline.
	var rings=[]
	for r in range(25):
		var row=[]
		for s in range(49):
			var a = s/48.0*TAU
			var y: float;var width: float;var depth: float
			if r<21:
				y=lerpf(1.005,1.31,r/20.0)
				var p=profile[0]
				for j in range(4):
					if y>=profile[j][0] and y<=profile[j+1][0]+.0001:
						var t=(y-profile[j][0])/(profile[j+1][0]-profile[j][0])
						p=[y,lerpf(profile[j][1],profile[j+1][1],t),lerpf(profile[j][2],profile[j+1][2],t)]
				width=p[1];depth=p[2]
			else:
				width=.190;depth=.093
				var x = absf(cos(a)*width)
				var neckline = exp(-pow(x/.063,2.0))*(.064 if sin(a)>0 else .030)
				var armhole = smoothstep(.137,.188,x)*.145
				y=1.467-neckline-armhole
				var t=(r-20)/4.0
				y=lerpf(1.31,y,t);depth=lerpf(.108,depth,t)
			var waist=exp(-pow((y-1.065)/.075,2))
			var side_tension=pow(absf(cos(a)),3)*exp(-pow((y-1.28)/.12,2))
			var wrinkle=sin(a*7+(y-1.0)*27)*.009*waist
			wrinkle+=sin((y-1.18)*65+a*2)*.0045*side_tension
			wrinkle+=sin(a*10-y*25)*.002*sin(clampf((y-1.005)/.31,0,1)*PI)
			var p = Vector3(cos(a)*(width+wrinkle),y,sin(a)*(depth+wrinkle)+.018)
			var n = Vector3(cos(a)/width,.18,sin(a)/depth).normalized()
			row.append([p,n,Vector2(s/48.0,1-(y-1.005)/.47),torso_weights(y)])
		rings.append(row)
	for r in range(24):
		for s in range(48):
			for ids in [[[r,s],[r+1,s],[r+1,s+1]],[[r,s],[r+1,s+1],[r,s+1]]]:
				var p=[];var n=[];var u=[];var w=[]
				for id in ids:
					var v: Array=rings[id[0]][id[1]]
					p.append(v[0]);n.append(v[1]);u.append(v[2]);w.append(v[3])
				var side_panel = absf(cos((s+.5)/48.0*TAU))>.95
				tri("cloth",p,n,u,dark if side_panel else jersey,w)
	# Ribbed neckline / armhole binding follows exactly the tank's upper edge.
	for s in range(48):
		var a: Array = rings[24][s];var b: Array=rings[24][s+1]
		var inward = Vector3(0,-.010,0)
		tri("trim",[a[0]+a[1]*.001,b[0]+b[1]*.001,b[0]+inward],[a[1],b[1],b[1]],[a[2],b[2],b[2]],cream,[a[3],b[3],b[3]])
		tri("trim",[a[0]+a[1]*.001,b[0]+inward,a[0]+inward],[a[1],b[1],a[1]],[a[2],b[2],a[2]],cream,[a[3],b[3],a[3]])
	loft("trim",[[Vector3(0,1.003,.019),.166,.111,weights("pelvis")],[Vector3(0,1.022,.019),.166,.111,weights("pelvis")]],cream)
	# Short drawcord and stitched waist tabs follow the pelvis, not the hands.
	for side in [-1,1]:
		path("trim",[Vector3(side*.012,1.010,.123),Vector3(side*.016,.978,.131),Vector3(side*.024,.958,.129)],.0024,cream,"pelvis")

func make_arm(suffix: String):
	var upper="upperarm"+suffix;var lower="lowerarm"+suffix;var hand="hand"+suffix
	var shoulder: Vector3=neutral[upper].origin
	var elbow: Vector3=neutral[lower].origin
	var wrist: Vector3=neutral[hand].origin
	var axis=(wrist-shoulder).normalized()
	var rows=[]
	for item in [[-.16,.030],[-.11,.042],[-.06,.049],[0.0,.054],[.055,.057],[.13,.057],[.22,.054],[.33,.047],[.43,.038],[.51,.033],[.56,.032],[.60,.036],[.68,.041],[.78,.035],[.9,.026],[1.0,.024]]:
		var t: float=item[0]
		var p=shoulder.lerp(wrist,t)
		var w=weights(upper,lower,smoothstep(.49,.62,t))
		if t<0:w=weights("clavicle"+suffix,upper,smoothstep(-.17,.01,t))
		if t>.90:w=weights(lower,hand,smoothstep(.90,1.0,t))
		rows.append([p,item[1],item[1]*.88,w])
	loft("skin",rows,skin_color,axis,20)
	# Wrist sweatband; continuous skin underneath, no mechanical joint spheres.
	loft("cloth",[[wrist-axis*.047,.029,.026,weights(lower,hand,.2)],[wrist-axis*.023,.028,.026,weights(lower,hand,.6)]],cream if suffix==".l" else dark,axis,16)
	var middle: Vector3=neutral["middle_01"+suffix].origin
	var palm_axis=(middle-wrist).normalized()
	loft("skin",[[wrist,.025,.017,weights(hand)],[wrist.lerp(middle,.42),.039,.020,weights(hand)],[middle,.038,.014,weights(hand)]],skin_color,palm_axis,16)
	for finger in ["thumb","index","middle","ring"]:
		var rs=[]
		for j in range(1,4):
			var bone=finger+"_0"+str(j)+suffix
			var p: Vector3=neutral[bone].origin
			var radius=.011 if finger=="thumb" else .009
			rs.append([p,radius,radius*.85,weights(bone)])
		var last=neutral[finger+"_03"+suffix]
		rs.append([last.origin+last.basis.y*.018,.003,.003,weights(finger+"_03"+suffix)])
		loft("skin",rs,skin_color,(rs[-1][0]-rs[0][0]).normalized(),10)
	# Little finger follows ring joints on this 45-bone rig.
	var little=[]
	var side=1 if suffix==".l" else -1
	for j in range(1,4):
		var bone="ring_0"+str(j)+suffix
		var p: Vector3=neutral[bone].origin+Vector3(-.009*side,.0,-.022)
		little.append([p,.007,.006,weights(bone)])
	little.append([little[-1][0]+Vector3(.010*side,0,0),.002,.002,weights("ring_03"+suffix)])
	loft("skin",little,skin_color,palm_axis,8)

func make_leg(suffix: String):
	var thigh="thigh"+suffix;var calf="calf"+suffix;var foot="foot"+suffix
	var hip: Vector3=neutral[thigh].origin
	var knee: Vector3=neutral[calf].origin
	var ankle: Vector3=neutral[foot].origin
	var knee_fraction=hip.distance_to(knee)/(hip.distance_to(knee)+knee.distance_to(ankle))
	var rows=[]
	# Bottom-to-top ordering preserves profile normals.
	# Keep a covered overlap at the hem, but omit fully hidden upper thighs.
	# Their rigid hip cap otherwise punches through the pelvis-weighted waist
	# when a leg swings; it is not an exposed part of these shorts outfits.
	for item in [[1.0,.028],[.88,.030],[.69,.054],[.57,.061],[.49,.045],[.43,.045]]:
		var t: float=item[0]
		var p=hip.lerp(knee,t/knee_fraction) if t<knee_fraction else knee.lerp(ankle,(t-knee_fraction)/(1-knee_fraction))
		var w=weights(thigh,calf,smoothstep(.40,.58,t))
		if t>.94:w=weights(calf,foot,smoothstep(.94,1.0,t))
		rows.append([p,item[1],item[1]*.96,w])
	loft("skin",rows,skin_color,(hip-ankle).normalized(),20)
	# Continuous D-shaped half-waist into each leg: no floating open tubes.
	var garment=[]
	var side=1.0 if suffix==".l" else -1.0
	for row in range(21):
		var ring=[]
		var t=row/20.0
		var y=lerpf(1.016,.563,t)
		var along=clampf((hip.y-y)/(hip.y-knee.y),0,1)
		var center=hip.lerp(knee,along)
		var spread=smoothstep(.06,.32,t)
		var width=.164+.017*sin(t*PI)
		var radius=.109+.009*sin(t*PI)
		for s in range(33):
			var a=s/32.0*TAU
			var x=lerpf(side*width*maxf(0,cos(a)),center.x+side*cos(a)*radius,spread)
			var z=lerpf(.019+sin(a)*.108,center.z+sin(a)*radius*.96,spread)
			var fold=sin(a*7+t*10)*.006*sin(t*PI)+sin(a*4-t*13)*.003*sin(t*PI)
			x+=side*cos(a)*fold
			z+=sin(a)*fold
			var pos=Vector3(x,y,z)
			var n=Vector3(side*cos(a),.04,sin(a)).normalized()
			var w=weights("pelvis",thigh,smoothstep(.08,.36,t))
			ring.append([pos,n,Vector2(s/32.0,t),w])
		garment.append(ring)
	for r in range(20):
		for s in range(32):
			for ids in [[[r,s],[r+1,s],[r+1,s+1]],[[r,s],[r+1,s+1],[r,s+1]]]:
				var ps=[];var ns=[];var us=[];var ws=[]
				for id in ids:
					var v=garment[id[0]][id[1]]
					ps.append(v[0]);ns.append(v[1]);us.append(v[2]);ws.append(v[3])
				var panel=cos((s+.5)/32.0*TAU)>.65
				# Top D profiles turn into round legs. Their steep crotch slope can
				# oppose a radial normal; do not independently flip those faces.
				var st=surface("cloth")
				for vi in ([0,1,2] if side>0 else [0,2,1]):
					vertex(st,ps[vi],ns[vi],us[vi],jersey.darkened(.35) if panel else dark,ws[vi])
	var hem=Vector3(hip.lerp(knee,.92).x,.563,hip.lerp(knee,.92).z)
	var leg_axis=Vector3.UP
	loft("trim",[[hem,.113,.109,weights(thigh)],[hem+leg_axis*.012,.114,.110,weights(thigh)]],cream,leg_axis,32)
	# Compression sock, high-top basketball shoe and contrasting rubber sole.
	loft("cloth",[[ankle-Vector3.UP*.025,.032,.035,weights(foot)],[ankle+Vector3.UP*.09,.034,.035,weights(calf,foot,.6)],[ankle+Vector3.UP*.105,.035,.036,weights(calf,foot,.4)]],cream)
	var x=ankle.x
	var shoe_rows=[[.019,.057,.134],[.035,.058,.135],[.057,.057,.129],[.079,.052,.117],[.10,.040,.071],[.143,.035,.050]]
	var shoe=[]
	for row in shoe_rows:
		var center_z=lerpf(.016,-.035,smoothstep(.057,.143,row[0]))
		shoe.append([Vector3(x,row[0],center_z),row[1],row[2],weights(foot)])
	loft("leather",shoe,cream,Vector3.UP,24)
	loft("trim",[[Vector3(x,.019,.016),.058,.135,weights(foot)],[Vector3(x,.035,.016),.059,.136,weights(foot)]],dark,Vector3.UP,24)
	for i in range(4):
		var y=.10-i*.009
		var z=.053+i*.017
		path("trim",[Vector3(x-.026,y,z),Vector3(x+.026,y,z)],.0028,dark,foot)
	path("trim",[Vector3(x-.047,.052,-.02),Vector3(x-.052,.068,.045),Vector3(x-.031,.079,.105)],.006,jersey,foot)
	path("trim",[Vector3(x+.047,.052,-.02),Vector3(x+.052,.068,.045),Vector3(x+.031,.079,.105)],.006,jersey,foot)

func face_uv(p: Vector3) -> Vector2:
	var knots=[[1.55,1.0],[1.563,.94],[1.603,.75],[1.635,.61],[1.67,.385],[1.69,.285],[1.71,.20],[1.78,0.0]]
	var v=0.0
	for j in range(knots.size()-1):
		if p.y>=knots[j][0] and p.y<=knots[j+1][0]:v=lerpf(knots[j][1],knots[j+1][1],(p.y-knots[j][0])/(knots[j+1][0]-knots[j][0]))
	return Vector2(.5+p.x/.20,v)

func head_profile(y: float) -> Vector3:
	var profile=[[1.55,.034,.037,.018],[1.565,.049,.049,.014],[1.587,.067,.058,.008],[1.613,.077,.065,.002],[1.64,.080,.071,-.001],[1.674,.078,.074,-.002],[1.71,.075,.070,-.004],[1.744,.065,.062,-.006],[1.769,.042,.041,-.008],[1.78,.001,.001,-.010]]
	for j in range(profile.size()-1):
		if y>=profile[j][0] and y<=profile[j+1][0]+.0001:
			var t=(y-profile[j][0])/(profile[j+1][0]-profile[j][0])
			return Vector3(lerpf(profile[j][1],profile[j+1][1],t),lerpf(profile[j][2],profile[j+1][2],t),lerpf(profile[j][3],profile[j+1][3],t))
	return Vector3(.001,.001,-.01)

func make_head():
	authoring_head=true
	var head="head"
	var rings=[]
	for r in range(25):
		var y=lerpf(1.55,1.78,r/24.0)
		var profile=head_profile(y)
		var ring=[]
		for s in range(49):
			var a=s/48.0*TAU
			var p=Vector3(cos(a)*profile.x,y,sin(a)*profile.y+profile.z)
			if sin(a)>0:
				var socket=exp(-pow((absf(p.x)-.033)/.018,2)-pow((y-1.670)/.014,2))
				var cheek=exp(-pow((absf(p.x)-.047)/.024,2)-pow((y-1.638)/.022,2))
				p.z+=-.004*socket+.004*cheek
			var n=Vector3(cos(a)/maxf(profile.x,.001),.08,sin(a)/maxf(profile.y,.001)).normalized()
			ring.append([p,n,face_uv(p)])
		rings.append(ring)
	for r in range(24):
		for s in range(48):
			var key="face" if sin((s+.5)/48.0*TAU)>0 else "skin"
			for ids in [[[r,s],[r+1,s],[r+1,s+1]],[[r,s],[r+1,s+1],[r,s+1]]]:
				var ps=[];var ns=[];var us=[]
				for id in ids:
					var v=rings[id[0]][id[1]]
					ps.append(v[0]);ns.append(v[1]);us.append(v[2])
				tri(key,ps,ns,us,skin_color,[weights(head),weights(head),weights(head)])
	for side in [-1,1]:
		oval("skin",Vector3(side*.080,1.647,-.004),Vector3(.011,.025,.015),skin_color,head)
		oval("features",Vector3(side*.088,1.647,.004),Vector3(.0015,.012,.007),skin_color.darkened(.22),head)
	# One small bridge/tip volume, with the same painted UV projection as the cheek.
	var nose=[Vector3(-.008,1.681,.068),Vector3(.008,1.681,.068),Vector3(-.016,1.632,.073),Vector3(.016,1.632,.073),Vector3(0,1.640,.097),Vector3(0,1.626,.079)]
	for ids in [[0,1,4],[0,4,2],[1,3,4],[2,4,5],[4,3,5],[2,5,3]]:
		var ps=[];var us=[]
		for id in ids:ps.append(nose[id]);us.append(face_uv(nose[id]))
		var n=(ps[1]-ps[0]).cross(ps[2]-ps[0]).normalized()
		if n.z<0:n=-n
		tri("face",ps,[n,n,n],us,skin_color,[weights(head),weights(head),weights(head)])
	var hair=Color("20282b" if not rival else "292528")
	var hair_rows=[]
	for r in range(7):
		var row=[]
		for s in range(49):
			var a=s/48.0*TAU
			var level=r/6.0
			var front=maxf(0,sin(a))
			var bottom=1.676+front*.034-absf(cos(a))*.014+sin(a*9)*.003*front
			var y=lerpf(bottom,1.802,level)+sin(a*2+.6)*.006*sin(level*PI)
			var radius=[1.0,1.0,.98,.90,.76,.50,.015][r]
			var p=Vector3(cos(a)*.086*radius+level*.014,y,sin(a)*.086*radius-.005)
			row.append([p,Vector3(cos(a),.3+level,sin(a)).normalized()])
		hair_rows.append(row)
	for r in range(6):
		for s in range(48):
			for ids in [[[r,s],[r+1,s],[r+1,s+1]],[[r,s],[r+1,s+1],[r,s+1]]]:
				var ps=[];var ns=[]
				for id in ids:ps.append(hair_rows[id[0]][id[1]][0]);ns.append(hair_rows[id[0]][id[1]][1])
				tri("hair",ps,ns,[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],hair.lightened(.018 if s>25 and s<40 else 0),[weights(head),weights(head),weights(head)])
	if rival:
		loft("cloth",[[Vector3(0,1.697,-.006),.082,.078,weights(head)],[Vector3(0,1.710,-.006),.082,.078,weights(head)]],cream,Vector3.UP,48)
	authoring_head=false
