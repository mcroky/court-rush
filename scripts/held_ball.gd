extends RefCounted

# One planted forefoot owns a held-ball possession. Direction changes move the
# other foot and the hips around that contact; they never restart a dribble.
const DURATIONS={"pivot":.68,"jab":.62,"pump":.70,"upunder":.95,"through":.85,"turn":.84}
var valid=false
var support=0
var anchor=Vector3.ZERO
var support_from=Vector3.ZERO
var root_offset=Vector3.ZERO
var toes=[Vector3.ZERO,Vector3.ZERO]
var foot_bases=[Basis.IDENTITY,Basis.IDENTITY]
var kind=""
var duration=.5
var yaw_from=0.0
var yaw_target=0.0
var sign_side=1.0
var direction=Vector3.FORWARD
var entry_ball=Vector3.ZERO
var entry_time=0.0
var direction_latched=false
var last_direction=Vector3.ZERO
var queued_release=false
var pump_release=false
var press_time=0.0
var input_edges={}
var free_goal=Vector3.ZERO

func square_ready(actor) -> bool:
	return actor.action_time>=duration and absf(angle_difference(actor.rotation.y,yaw_target))<.003 and toes[1-support].distance_to(free_goal)<.004

func freeze(actor,ball: Vector3) -> void:
	capture(actor,ball)
	for i in 2:toes[i]=actor.skinned.toe_world[i]
	anchor=toes[support];anchor.y=.026;support_from=toes[support]
	root_offset=Basis(Vector3.UP,-actor.rotation.y)*(actor.global_position-anchor);root_offset.y=0
	yaw_target=actor.rotation.y;kind=""
	queued_release=false;pump_release=false;press_time=0
	entry_ball=ball;entry_time=0

func reset() -> void:
	valid=false;kind="";direction_latched=false
	last_direction=Vector3.ZERO
	queued_release=false;pump_release=false;press_time=0.0
	input_edges.clear()

func capture(actor,ball: Vector3) -> void:
	if valid:return
	valid=true
	for i in 2:
		if actor.skinned!=null:foot_bases[i]=actor.skinned.bone_world(actor.skinned.feet[i][2]).basis.orthonormalized()
	for i in 2:toes[i]=actor.skinned.toe_world[i] if actor.skinned!=null else actor.shoes[i].to_global(actor.LAYUP_TOE)
	# Prefer a grounded, nearby foot instead of pinning a distant sprint toe.
	var scores=[]
	for toe in toes:scores.append(Vector2(toe.x-actor.position.x,toe.z-actor.position.z).length()+maxf(0,toe.y-.05)*4)
	support=0 if scores[0]<=scores[1] else 1
	anchor=toes[support];anchor.y=.026
	support_from=toes[support]
	root_offset=actor.global_position-anchor;root_offset.y=0
	root_offset=Basis(Vector3.UP,-actor.rotation.y)*root_offset
	yaw_target=actor.rotation.y
	entry_ball=ball;entry_time=0.0

func owns(actor) -> bool:
	return valid and actor.has_ball and actor.dribble_ended and (actor.action in ["idle","held_fake","square"] or (actor.action=="gather" and kind=="turnshot"))

func begin(actor,next_kind: String,desired: Vector3,ball: Vector3,target_yaw: float=INF) -> void:
	capture(actor,ball)
	support_from=toes[support]
	root_offset=Basis(Vector3.UP,-actor.rotation.y)*(actor.global_position-anchor)
	root_offset.y=0
	kind=next_kind;duration=DURATIONS.get(kind,.6)
	yaw_from=actor.rotation.y
	if desired.length()>.1:
		direction=desired.normalized()
		sign_side=-1.0 if actor.global_basis.x.dot(direction)<0 else 1.0
	else:
		sign_side=actor.dribble_hand;direction=actor.global_basis.x*sign_side
	yaw_target=target_yaw if is_finite(target_yaw) else yaw_from
	if kind=="square":duration=.18+absf(angle_difference(yaw_from,yaw_target))/6.0
	elif kind=="pivot" and desired.length()>.1:yaw_target=atan2(desired.x,desired.z)
	elif kind=="turn":yaw_target=yaw_from+sign_side*1.80
	actor.action="square" if kind=="square" else "held_fake"
	actor.action_time=0;actor.jump=0;actor.motion=Vector2.ZERO
	actor.dribble_ended=true;actor.shot_gather_turn=false
	entry_ball=ball;entry_time=0.0

func begin_turn_shot(actor,ball: Vector3,aim: float) -> void:
	begin(actor,"square",Vector3.ZERO,ball,aim)
	kind="turnshot";duration=.36
	yaw_target=lerp_angle(yaw_from,aim,.66)
	actor.action="gather";actor.facing=aim

func tick(actor,delta: float) -> void:
	if not owns(actor):
		if not actor.has_ball or not actor.dribble_ended:reset()
		return
	entry_time+=delta
	var t=clampf(actor.action_time/maxf(.01,duration),0,1) if actor.action!="idle" else 1.0
	var yaw=yaw_target
	if actor.action!="idle":yaw=lerp_angle(yaw_from,yaw_target,smoothstep(.08 if kind=="turnshot" else .12,duration,actor.action_time))
	actor.rotation.y+=clampf(angle_difference(actor.rotation.y,yaw),-delta*6.5,delta*6.5)
	if kind!="turnshot":actor.facing=actor.rotation.y
	# A sprint contact can trail far behind the hips. Load the planted leg
	# before rotating, rather than rotating an overextended leg in place.
	var balanced=Vector3(.20 if support==0 else -.20,0,-.06)*actor.height_ratio
	var loaded_offset=root_offset.lerp(balanced,smoothstep(0,.20,entry_time))
	actor.global_position=BasketballRules.clamp_to_court(anchor+Basis(Vector3.UP,actor.rotation.y)*loaded_offset)
	actor.position.y=0
	toes[support]=support_from.lerp(anchor,smoothstep(0,.12,entry_time))
	var side=-1.0 if 1-support==0 else 1.0
	var width=.28 if kind!="through" else .40
	var goal=actor.to_global(Vector3(side*width*actor.height_ratio,0,.10))
	if actor.action=="held_fake" and kind in ["jab","upunder"]:
		var step=smoothstep(0,.22,t)*(1-smoothstep(.48,.90,t)) if kind=="jab" else smoothstep(.25,.50,t)*(1-smoothstep(.75,1,t))
		goal+=direction*(.42 if kind=="jab" else .32)*step
	goal.y=.026
	free_goal=goal
	var distance=Vector2(goal.x-toes[1-support].x,goal.z-toes[1-support].z).length()
	# The outer foot travels a longer arc than the hips during a half turn.
	# Let it keep up, then plant, instead of adding a dead wait after the turn.
	var lifted_goal=goal+Vector3.UP*minf(.055,maxf(0,distance-.02)*.18)
	toes[1-support]=toes[1-support].move_toward(lifted_goal,delta*3.8)
	actor.motion=Vector2.ZERO;actor.swinging=[false,false]
	for i in 2:
		actor.feet_world[i]=toes[i]-Basis(Vector3.UP,actor.rotation.y)*Vector3(0,0,.19)
		actor.feet_world[i].y=.105
		actor.feet_yaw[i]=actor.rotation.y

func pose(actor) -> Dictionary:
	var t=clampf(actor.action_time/maxf(.01,duration),0,1) if actor.action=="held_fake" else 0.0
	# Readable game poses: preload, show a committed threat, then counter and
	# recover. A sine-only wiggle has no moment for an opponent to read.
	var load=sin(clampf(t/.22,0,1)*PI)
	var show=smoothstep(0,.22,t)*(1-smoothstep(.48,.86,t))
	var counter=smoothstep(.22,.48,t)*(1-smoothstep(.72,1,t))
	var center=Vector3(0,1.19,.34)
	var twist=0.0;var pitch=.10;var drop=.10;var roll=0.0
	match kind if actor.action=="held_fake" else "":
		"pump":
			center.y+=.70*show-.10*load;drop+=.12*load-.08*show
			pitch+=.16*load-.06*show;roll=-sign_side*.07*show
		"upunder":
			center+=Vector3(sign_side*(.28*show-.42*counter),.65*show-.22*counter,.16*show+.20*counter)
			twist=sign_side*(.34*show-.56*counter);drop+=.14*counter-.05*show
			pitch+=.28*counter;roll=sign_side*(.10*show-.13*counter)
		"through":
			center+=Vector3(sign_side*.32*sin(t*TAU),-.62*show,-.28*show)
			drop+=.16*show;pitch+=.20*show;twist=sign_side*.40*sin(t*TAU);roll=-sign_side*.08*sin(t*TAU)
		"turn":
			center+=Vector3(-sign_side*.30*show,-.08*show,-.18*show)
			twist=sign_side*.55*show;drop+=.10*load;roll=-sign_side*.13*show
		"jab":
			center+=Vector3(sign_side*.26*show,-.16*show,.24*show)
			pitch+=.28*show;twist=sign_side*.36*show;roll=-sign_side*.14*show;drop+=.08*show
		"pivot":
			center.x+=sign_side*(.30*show-.18*counter)
			twist=sign_side*.42*show;drop+=.08*show;roll=sign_side*.10*show
	var world=actor.to_global(Vector3(center.x*actor.height_ratio,center.y*actor.height_ratio,center.z*actor.height_ratio))
	world=entry_ball.lerp(world,smoothstep(0,.18,entry_time))
	return {"center":world,"twist":twist,"pitch":pitch,"drop":drop,"roll":roll,"gaze":twist*.55}
