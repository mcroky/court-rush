extends RefCounted

# One planted forefoot owns a held-ball possession. Direction changes move the
# other foot and the hips around that contact; they never restart a dribble.
const DURATIONS={"pivot":.56,"jab":.50,"pump":.60,"upunder":.82,"through":.72,"turn":.74}
var valid=false
var support=0
var anchor=Vector3.ZERO
var support_from=Vector3.ZERO
var root_offset=Vector3.ZERO
var toes=[Vector3.ZERO,Vector3.ZERO]
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
	return actor.action_time>=duration and absf(angle_difference(actor.rotation.y,yaw_target))<.06 and toes[1-support].distance_to(free_goal)<.025

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
	return valid and actor.has_ball and actor.dribble_ended and actor.action in ["idle","held_fake","square"]

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
	elif kind=="turn":yaw_target=yaw_from+sign_side*1.15
	actor.action="square" if kind=="square" else "held_fake"
	actor.action_time=0;actor.jump=0;actor.motion=Vector2.ZERO
	actor.dribble_ended=true;actor.shot_gather_turn=false
	entry_ball=ball;entry_time=0.0

func tick(actor,delta: float) -> void:
	if not owns(actor):
		if not actor.has_ball or not actor.dribble_ended:reset()
		return
	entry_time+=delta
	var t=clampf(actor.action_time/maxf(.01,duration),0,1) if actor.action!="idle" else 1.0
	var yaw=yaw_target
	if actor.action!="idle":yaw=lerp_angle(yaw_from,yaw_target,smoothstep(.12,duration,actor.action_time))
	actor.rotation.y+=clampf(angle_difference(actor.rotation.y,yaw),-delta*6.5,delta*6.5)
	actor.facing=actor.rotation.y
	# A sprint contact can trail far behind the hips. Load the planted leg
	# before rotating, rather than rotating an overextended leg in place.
	var balanced=Vector3(.20 if support==0 else -.20,0,-.06)*actor.height_ratio
	var loaded_offset=root_offset.lerp(balanced,smoothstep(0,.20,entry_time))
	actor.global_position=BasketballRules.clamp_to_court(anchor+Basis(Vector3.UP,actor.rotation.y)*loaded_offset)
	actor.position.y=0
	toes[support]=support_from.lerp(anchor,smoothstep(0,.12,entry_time))
	var side=-1.0 if 1-support==0 else 1.0
	var width=.28 if kind!="through" else .34
	var goal=actor.to_global(Vector3(side*width*actor.height_ratio,0,.10))
	if actor.action=="held_fake" and kind in ["jab","upunder"]:goal+=direction*(.26 if kind=="jab" else .20)*sin(t*PI)
	goal.y=.026
	free_goal=goal
	var distance=Vector2(goal.x-toes[1-support].x,goal.z-toes[1-support].z).length()
	# The outer foot travels a longer arc than the hips during a half turn.
	# Let it keep up, then plant, instead of adding a dead wait after the turn.
	toes[1-support]=toes[1-support].move_toward(goal,delta*3.8)
	toes[1-support].y=.026+minf(.055,distance*.18)
	actor.motion=Vector2.ZERO;actor.swinging=[false,false]
	for i in 2:
		actor.feet_world[i]=toes[i]-Basis(Vector3.UP,actor.rotation.y)*Vector3(0,0,.19)
		actor.feet_world[i].y=.105
		actor.feet_yaw[i]=actor.rotation.y

func pose(actor) -> Dictionary:
	var t=clampf(actor.action_time/maxf(.01,duration),0,1) if actor.action=="held_fake" else 0.0
	var wave=sin(t*PI)
	var center=Vector3(0,1.19,.34)
	var twist=0.0;var pitch=.10;var drop=.10
	match kind if actor.action=="held_fake" else "":
		"pump":center.y+=.47*wave;drop-=.06*wave
		"upunder":
			var lift=sin(clampf(t/.55,0,1)*PI)
			center+=Vector3(sign_side*.23*sin(t*TAU),.43*lift-.13*sin(t*PI),.14*wave)
			twist=sign_side*.28*sin(t*TAU);drop+=.07*wave
		"through":center+=Vector3(sign_side*.20*sin(t*TAU),-.49*wave,-.13*wave);drop+=.08*wave;pitch+=.12*wave
		"turn":center+=Vector3(-sign_side*.21*wave,.02,-.08*wave);twist=-sign_side*.25*wave
		"jab":center+=Vector3(sign_side*.10*wave,-.09*wave,.08*wave);pitch+=.12*wave
		"pivot":center.x+=sign_side*.18*sin(t*TAU);twist=sign_side*.18*wave
	var world=actor.to_global(Vector3(center.x*actor.height_ratio,center.y*actor.height_ratio,center.z*actor.height_ratio))
	world=entry_ball.lerp(world,smoothstep(0,.18,entry_time))
	return {"center":world,"twist":twist,"pitch":pitch,"drop":drop}
