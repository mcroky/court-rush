extends Node3D
## Safe appearance viewer: the exact match actor, rig and ball, in a separate scene.
const Actor = preload("res://scripts/actor.gd")
const Art = preload("res://scripts/art.gd")
var athletes: Array = []
var balls: Array = []
var camera: Camera3D
var controls
var elapsed = 0.0
var mode = "idle"
var view = "full"
var previous_mode = "idle"
var previous_view = "full"

func _ready():
	DisplayServer.window_set_title("코트러시 · 캐릭터 스튜디오")
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("142b31")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d6df")
	env.ambient_light_energy = .38
	world.environment=env
	add_child(world)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_energy=.85
	sun.shadow_enabled=true
	add_child(sun)
	Art.box(self,Vector3(0,-.055,0),Vector3(25,.1,25),"247c7a")
	for i in range(2):
		var actor=Actor.new()
		add_child(actor)
		actor.setup(i==1)
		actor.position=Vector3(-.8 if i==0 else .8,0,0)
		actor.has_ball=false
		actor.facing=.28 if i==0 else -.28
		actor.rotation.y=actor.facing
		actor.animate(.016,0)
		athletes.append(actor)
		balls.append(Art.basketball(self))
		Art.arc(self,actor.position+Vector3.UP*.004,.60,0,TAU,"e5d7b7",.013,48)
	camera=Camera3D.new()
	add_child(camera)
	camera.current=true
	if OS.has_feature("web"):controls=JavaScriptBridge.get_interface("window").crCharacterInput

func _physics_process(delta):
	if controls!=null:
		mode=str(controls.mode)
		view=str(controls.view)
		if bool(controls.slow):delta*=.35
		if bool(controls.paused):delta=0
	elapsed+=delta
	var mode_changed=mode!=previous_mode
	if mode_changed:elapsed=0
	for i in range(2):
		var actor=athletes[i]
		var facing=.28 if i==0 else -.28
		if mode=="cut":
			var stage=int(fposmod(elapsed,8.4)/1.2)
			facing=[.28,PI*.5,.28,-PI*.5,PI,.28,.28][stage]*(1 if i==0 else -1)
		if mode=="cross":
			var drive=smoothstep(.60,.95,actor.cross_phase()) if actor.crossing() else ((1-smoothstep(1.4,2.1,fposmod(elapsed,2.4))) if actor.cross_received else 0.0)
			facing+=actor.cross_to*.65*drive
		if view=="side":facing=facing+PI*.5 if mode in ["cut","cross"] else PI*.5
		if view=="other-side":facing=facing-PI*.5 if mode in ["cut","cross"] else -PI*.5
		if view=="back":facing=facing+PI if mode in ["cut","cross"] else (PI-.28 if i==0 else PI+.28)
		var presentation_turn=view!=previous_view
		actor.facing=facing
		if mode not in ["cut","cross","pullup"]:actor.rotation.y=facing
		# A camera presentation turn is not a basketball cut: rebuild its contacts.
		if presentation_turn or mode_changed:
			actor.rotation.y=facing
			actor.reset_stance()
			actor.feet_world.clear()
			actor.motion=Vector2.ZERO
			actor.action="idle"
			actor.animate(.016,elapsed)
		actor.has_ball=mode in ["dribble","handle","hold","shot","cross","cut","pullup"]
		actor.dribble_ended=mode=="hold"
		var defensive_preview=mode in ["guard","shuffle","boxout"]
		var defense_time=fposmod(elapsed,8.4)
		var stance_active=defensive_preview and defense_time>=.45 and defense_time<7.4
		actor.defending=stance_active
		actor.boxing_out=stance_active and mode=="boxout"
		# Use the match's stance/contact inputs so the preview exercises the real
		# receiving foot and support exchange, rather than a separate animation.
		actor.contact_pressure=(.60+.25*sin(defense_time*2.2))*smoothstep(.9,1.8,defense_time) if actor.boxing_out else 0.0
		actor.contact_direction=(-actor.global_basis.z+actor.global_basis.x*sin(defense_time*1.8)*.35).normalized() if actor.boxing_out else Vector3.ZERO
		actor.watch_direction=(actor.global_basis.z+actor.global_basis.x*sin(defense_time)*.22) if stance_active else Vector3.ZERO
		actor.jump=0
		if mode=="shot":
			var t=fposmod(elapsed,2.4)
			actor.finish_kind="shot"
			actor.dribble_ended=true
			actor.action="gather" if t<.55 else ("shot" if t<1.43 else "idle")
			actor.action_time=t if t<.55 else t-.55
			if actor.action=="shot":
				actor.jump=Actor.shot_height(actor.action_time)
				actor.has_ball=actor.action_time<.22
		var stopping=mode=="cut" and fposmod(elapsed,8.4)>=7.2
		var velocity=Vector2(sin(facing),cos(facing))*(4.7 if mode not in ["idle","handle","hold","shot"] and not stopping else 0)
		if mode=="pullup":
			var t=fposmod(elapsed,3.0)
			var next_action="idle" if t<.55 or t>=1.98 else ("gather" if t<1.10 else "shot")
			actor.finish_kind="shot"
			if next_action=="gather" and actor.action!="gather":
				actor.approach_velocity=actor.motion
				actor.shot_gather_yaw=actor.rotation.y
				actor.shot_gather_turn=true
				actor.gather_step_start=actor.step_serial
			actor.action=next_action
			actor.action_time=maxf(0,t-(.55 if next_action=="gather" else 1.10))
			actor.dribble_ended=t>=.55
			actor.facing=facing if t<.55 else facing+PI*.5
			if next_action=="gather":velocity=actor.gather_velocity()
			elif t>=.55:velocity=Vector2.ZERO
			if next_action=="shot":
				actor.jump=Actor.shot_height(actor.action_time)
				actor.has_ball=actor.action_time<.22
		if defensive_preview:
			var slide=0.0
			if mode!="guard":
				if defense_time>=1.0 and defense_time<2.2:slide=1.0
				elif defense_time>=2.65 and defense_time<4.85:slide=-1.0
				elif defense_time>=5.3 and defense_time<6.3:slide=1.0
			var direction=actor.global_basis.x*slide
			velocity=Vector2(direction.x,direction.z)*(1.2 if mode=="boxout" else 2.7)
		actor.steer_motion(velocity,24,delta)
		if mode=="pullup" and actor.action=="gather":actor.motion=velocity
		if mode!="cross" and actor.action=="cross":actor.finish_cross()
		if mode=="cross" and actor.action=="idle" and fposmod(elapsed,2.4)<.09:
			actor.prepare_cross(actor.ball_anchor(elapsed))
			actor.action="cross"
			actor.action_time=0
		if actor.action=="cross":
			actor.action_time+=delta
			if actor.action_time>=actor.cross_duration() and actor.cross_received:actor.finish_cross()
		var travel=actor.movement_step(delta)
		actor.position+=travel
		if delta>0:actor.animate(delta,elapsed)
		actor.position-=travel
		actor.previous_position-=travel
		for side in range(2):
			actor.feet_world[side]-=travel
			actor.swing_from[side]-=travel
			actor.swing_to[side]-=travel
		actor.skinned.shift_world_contacts(-travel)
		balls[i].visible=actor.has_ball
		balls[i].global_position=actor.ball_anchor(elapsed)
		actor.visible=view not in ["face","jersey"] or i==0
	previous_mode=mode
	previous_view=view
	var aspect=get_viewport().get_visible_rect().size.aspect()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=(.72 if view=="face" else (3.6 if mode in ["shot","pullup"] else 2.8))*maxf(1,1.1/maxf(.35,aspect))
	camera.position=Vector3(-.80,1.94,4) if view=="face" else Vector3(0,2.45 if mode in ["shot","pullup"] else 2.15,6)
	camera.look_at(Vector3(-.80,1.64,0) if view=="face" else Vector3(0,1.20 if mode in ["shot","pullup"] else .94,0))
	if view=="jersey":
		camera.size=1.30*maxf(1,1.1/maxf(.35,aspect))
		camera.position=Vector3(-.8,1.7,4)
		camera.look_at(Vector3(-.8,1.27,0))
