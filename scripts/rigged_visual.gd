class_name RiggedStreetVisual
extends Node3D
## Imported full-body locomotion, layered contact IK, no gameplay ownership.
const Source = preload("res://assets/experiments/mannequiny/mannequiny.glb")
const HumanPlayer = preload("res://assets/characters/rush_player.res")
const HumanRival = preload("res://assets/characters/rush_rival.res")
const SCALE = 1.08
var render_scale=SCALE
const RUN_SPEED = 7.0
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var phase = .28
var clip = ""
var locomotion = 0.0
var run_start_serial=-1
var idle_step=-1
var idle_step_basis=Basis.IDENTITY
var initialized = false
var feet: Array = []
var arms: Array = []
var palm_frames: Array = []
var palm_offsets: Array = []
var foot_rest_basis: Array = []
var arm_weight: Array = [0.0,0.0]
var palm_world: Array = [Vector3.ZERO,Vector3.ZERO]
var toe_world: Array = [Vector3.ZERO,Vector3.ZERO]
var locked: Array = [false,false]
var anchors: Array = [Vector3.ZERO,Vector3.ZERO]
var last_root = Vector3.ZERO
var source_poses: Array = []
var base_local: Array = []
var arm_errors: Array = [0.0,0.0]
var contact_mode = false
var cut_weight = 0.0
var root_height = 0.0
var ground_drop = 0.0
var previous_palms_local: Array = [Vector3.ZERO,Vector3.ZERO]
var previous_elbows_local: Array = [Vector3.ZERO,Vector3.ZERO]
var shot_posture_time=0.0
var previous_contact_mode = false
var final_poses: Array = []
var return_poses: Array = []
var return_blend = 0.0
var return_window=.12
var human_mesh: MeshInstance3D
var visual_swing: Array = [false,false]
var visual_swing_from: Array = [Vector3.ZERO,Vector3.ZERO]
var visual_swing_to: Array = [Vector3.ZERO,Vector3.ZERO]
var visual_swing_time: Array = [0.0,0.0]
var visual_swing_duration: Array = [.16,.16]
var physics_swing: Array = [false,false]
var contact_spent: Array = [false,false]
var leg_return_poses: Array = [[],[]]
var leg_return_time: Array = [0.0,0.0]
var leg_return_pending: Array = [false,false]
var basketball_weight=0.0
var torso_layer=Vector3.ZERO
var pelvis_world_height=0.0
var stop_height=0.0
var was_stopping=false
var last_hand_basis: Array=[Basis.IDENTITY,Basis.IDENTITY]
var previous_root_basis = Basis.IDENTITY
var last_action=""
var action_entry_time=0.0
var finish_entry_height=0.0
var finish_entry_head=Vector3.ZERO
var finish_entry_toes: Array=[Vector3.ZERO,Vector3.ZERO]
var finish_entry_world: Array=[Vector3.ZERO,Vector3.ZERO]
var gather_entry_height=0.0
var shot_gather_steps=false
var shot_gather_first=0
var shot_gather_from: Array=[Vector3.ZERO,Vector3.ZERO]
var shot_gather_to: Array=[Vector3.ZERO,Vector3.ZERO]
var shot_gather_bases: Array=[Basis.IDENTITY,Basis.IDENTITY]
var shot_gather_clock=0.0
var shot_gather_exit=0.0
var shot_gather_released=false
var shot_gather_closing=false
var shot_gather_release_origin=Vector3.ZERO
var shot_gather_release_toe=Vector3.ZERO
var shot_gather_release_time=0.0
const SHOT_GATHER_STEP_END=.26
const SHOT_GATHER_FIRST_END=.12

func begin_shot_gather(actor) -> void:
	shot_gather_steps=initialized and actor.finish_kind=="shot" and actor.approach_velocity.length()>1.2 and not actor.turnaround_shot
	if not shot_gather_steps:return
	shot_gather_released=false
	shot_gather_closing=false
	# Recover the airborne foot, then close the supporting foot. The rendered
	# toes own this transfer; the hidden prototype has a different stride.
	shot_gather_first=0 if toe_world[0].y>toe_world[1].y else 1
	if locked[0]!=locked[1]:shot_gather_first=1 if locked[0] else 0
	var heading=Basis(Vector3.UP,actor.rotation.y)
	var center=actor.global_position+Vector3(actor.approach_velocity.x,0,actor.approach_velocity.y)*.09
	for i in 2:
		shot_gather_from[i]=toe_world[i]
		shot_gather_to[i]=center+heading*Vector3((-1 if i==0 else 1)*.17*actor.height_ratio,.026,.08+(.025 if (i==1)==(actor.dribble_hand>0) else -.025))
		shot_gather_to[i].y=.026
		shot_gather_bases[i]=bone_world(feet[i][2]).basis.orthonormalized()
		visual_swing[i]=false
	# Do not send the receiving foot through the old support on an oblique
	# stride. Accept a wider pull-up plant and narrow it only after toe-off.
	var other=1-shot_gather_first
	var gap=(shot_gather_to[shot_gather_first]-shot_gather_from[other]).dot(heading.x)
	var side=-1.0 if shot_gather_first==0 else 1.0
	shot_gather_to[shot_gather_first]+=heading.x*side*maxf(0,.16*actor.height_ratio-gap*side)

func shot_gather_toe(actor,index: int,elapsed: float=-1.0) -> Vector3:
	var t=actor.action_time if elapsed<0 else elapsed
	if index!=shot_gather_first and shot_gather_released and t<SHOT_GATHER_FIRST_END:
		return shot_gather_release_toe+actor.global_position-shot_gather_release_origin+Vector3.UP*.035*smoothstep(shot_gather_release_time,SHOT_GATHER_FIRST_END,t)
	var start=0.0 if index==shot_gather_first else SHOT_GATHER_FIRST_END
	var duration=SHOT_GATHER_FIRST_END if index==shot_gather_first else SHOT_GATHER_STEP_END-SHOT_GATHER_FIRST_END
	var progress=clampf((t-start)/duration,0,1)
	var goal: Vector3=shot_gather_from[index].lerp(shot_gather_to[index],smoothstep(0,1,progress))
	goal.y+=sin(progress*PI)*.055
	return goal

var entry_palms: Array=[Vector3.ZERO,Vector3.ZERO]
var entry_frames: Array=[Basis.IDENTITY,Basis.IDENTITY]
var cross_entry_frames: Array=[Basis.IDENTITY,Basis.IDENTITY]
var cross_return_frames: Array=[Basis.IDENTITY,Basis.IDENTITY]
var was_crossing=false
var head_forward_local=Vector3.BACK
var gaze_target=Vector2.ZERO
var unlayered_poses: Array=[]
var action_entry_height=0.0
var finger_cups: Array=[0.0,0.0]
var guard_step_from: Array=[Vector3.ZERO,Vector3.ZERO]
var guard_step_serial: Array=[-1,-1]
var guard_step_phase: Array=[0.0,0.0]
var guard_landing_targets: Array=[Vector3.ZERO,Vector3.ZERO]
var guard_entry_bases: Array=[Basis.IDENTITY,Basis.IDENTITY]
var guard_entry_time=0.0
var guard_was_active=false

func transition_pose() -> Array:
	var result=final_poses.duplicate()
	# Contact limbs retain their last pose. Additive torso/neck/collar layers
	# must start from the authored pose, otherwise each transition applies them twice.
	if unlayered_poses.size()==result.size():
		for name in ["spine_01","spine_02","neck_01","head"]:
			var bone=skeleton.find_bone(name)
			result[bone]=unlayered_poses[bone]
		for chain in arms:
			var collar=skeleton.get_bone_parent(chain[0])
			result[collar]=unlayered_poses[collar]
	return result

# The visible rig owns these contacts. The hidden prototype's shoe is larger
# and cannot supply a reliable toe-off or landing anchor for the human mesh.
func finish_times(actor) -> Vector2:
	return Vector2(actor.SHOT_PLANT_TIME,actor.SHOT_LAND_TIME) if actor.action=="shot" else Vector2(actor.LAYUP_PLANT_TIME,actor.LAYUP_DURATION)

func finish_root(actor) -> float:
	var times=finish_times(actor)
	var base=-.055 if actor.action=="shot" else -.025
	var peak=actor.SHOT_JUMP_HEIGHT if actor.action=="shot" else actor.LAYUP_JUMP_HEIGHT
	var push_speed=4*peak/(times.y-times.x)
	var t: float=actor.action_time
	if t<=times.x:
		var u=clampf(t/times.x,0,1)
		return (2*u*u*u-3*u*u+1)*finish_entry_height+(-2*u*u*u+3*u*u)*base+(u*u*u-u*u)*times.x*push_speed
	if t<times.y:return actor.jump+base
	# Contact first, compression second. The downward speed continues into a
	# damped knee load instead of stopping dead or crouching before touchdown.
	var elapsed=t-times.y
	var knee_load=.045*pow(sin(clampf(elapsed/.16,0,1)*PI),2.0) if actor.action=="shot" else 0.0
	return base-push_speed*elapsed*exp(-elapsed/.055)-knee_load

func finish_toe(actor, index: int) -> Vector3:
	if actor.action=="shot":return jumper_toe(actor,index)
	var times=finish_times(actor)
	var t: float=actor.action_time
	var side=-1.0 if index==0 else 1.0
	var start: Vector3=finish_entry_toes[index]
	var plant=actor.action=="shot" or index==actor.layup_plant_index
	if plant and t<=times.x:
		var contact: Vector3=finish_entry_world[index]
		contact.y=.026
		return contact
	var raised=actor.action=="layup" and not plant
	var tuck=sin(clampf((t-times.x)/(times.y-times.x),0,1)*PI)
	if raised:tuck=sin(clampf(t/times.y,0,1)*PI)
	var air=Vector3(side*.17,.026+actor.jump+(.20 if raised else .025)*tuck,.22 if raised else -.12)
	if actor.action=="shot":air=Vector3(start.x,.026+actor.jump+.025*tuck,start.z)
	var origin: Vector3=finish_entry_world[index] if plant else actor.to_global(start)
	var goal=origin.lerp(actor.to_global(air),smoothstep(0 if raised else times.x,.22 if raised else times.x+.10,t))
	var landing=actor.to_global(Vector3(start.x,.026,start.z)) if actor.action=="shot" else actor.air_end+actor.global_basis*Vector3(side*.17,.026,.12 if raised else -.06)
	goal=goal.lerp(landing,smoothstep(times.y-.22,times.y,t))
	return goal

func jumper_times(actor,index: int) -> Vector2:
	var shooting_side=1 if actor.dribble_hand>0 else 0
	# A tiny left/right support exchange keeps the two legs from behaving as
	# one rigid elevator. Ball release and the gameplay jump clock are unchanged.
	return Vector2(actor.SHOT_PLANT_TIME+(.008 if index!=shooting_side else 0.0),actor.SHOT_LAND_TIME+(.018 if index!=shooting_side else 0.0))

func jumper_pitch(actor,index: int) -> float:
	var times=jumper_times(actor,index)
	var t: float=actor.action_time
	var contact=maxf(.008,SHOT_GATHER_STEP_END-shot_gather_exit) if shot_gather_steps and index!=shot_gather_first else .008
	if t<=times.x:return .58*smoothstep(contact,times.x,t)
	if t>=times.y:return .203*(1-smoothstep(0,.065,t-times.y))
	var u=clampf((t-times.x)/(times.y-times.x),0,1)
	return (.58+.12*sin(u*PI))*(1-.65*smoothstep(.25,.94,u))

func jumper_toe(actor,index: int) -> Vector3:
	var times=jumper_times(actor,index)
	var t: float=actor.action_time
	var plant: Vector3=finish_entry_world[index]
	plant.y=.026
	if shot_gather_steps and t+shot_gather_exit<SHOT_GATHER_STEP_END:
		return shot_gather_toe(actor,index,t+shot_gather_exit)
	if t<=times.x:return plant
	var start: Vector3=finish_entry_toes[index]
	var side=-1 if index==0 else 1
	var landing_width=side*.17*actor.height_ratio if shot_gather_steps else start.x
	var landing=actor.to_global(Vector3(landing_width,.026,start.z+.045))
	if t>=times.y:return landing
	var u=clampf((t-times.x)/(times.y-times.x),0,1)
	var fold=pow(sin(u*PI),2.0)
	var width=lerpf(start.x,side*.17*actor.height_ratio,smoothstep(0,.55,u)) if shot_gather_steps else start.x
	var local=Vector3(width+side*.012*fold,.026+4*actor.SHOT_JUMP_HEIGHT*u*(1-u)+(.105 if index==0 else .125)*fold,start.z-.09*sin(u*PI)+.045*smoothstep(.4,.95,u))
	# Continue the takeoff speed at toe-off. The former smoothstep from a
	# stationary shoe delayed the feet while the pelvis was already airborne.
	return actor.to_global(local)

func setup(opponent: bool) -> void:
	model = Source.instantiate()
	add_child(model)
	model.scale = Vector3.ONE*render_scale
	skeleton = model.find_children("*","Skeleton3D")[0]
	player = model.find_child("AnimationPlayer",true,false)
	var library = player.get_animation_library("").duplicate(true)
	player.remove_animation_library("")
	player.add_animation_library("",library)
	for name in ["idle","run"]: player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("idle")
	player.advance(0)
	for index in range(skeleton.get_bone_count()): base_local.append(skeleton.get_bone_pose(index))
	head_forward_local=skeleton.get_bone_global_rest(skeleton.find_bone("head")).basis.inverse()*Vector3.BACK
	for suffix in [".r",".l"]:
		feet.append([skeleton.find_bone("thigh"+suffix),skeleton.find_bone("calf"+suffix),skeleton.find_bone("foot"+suffix),skeleton.find_bone("ball"+suffix)])
		foot_rest_basis.append(skeleton.get_bone_global_pose(feet[-1][2]).basis.orthonormalized())
		arms.append([skeleton.find_bone("upperarm"+suffix),skeleton.find_bone("lowerarm"+suffix),skeleton.find_bone("hand"+suffix)])
		var hand = skeleton.get_bone_global_pose(arms[-1][2])
		var middle = skeleton.get_bone_global_pose(skeleton.find_bone("middle_01"+suffix)).origin
		var index = skeleton.get_bone_global_pose(skeleton.find_bone("index_01"+suffix)).origin
		var ring = skeleton.get_bone_global_pose(skeleton.find_bone("ring_01"+suffix)).origin
		var along = (middle-hand.origin).normalized()
		var normal = (index-ring).cross(along).normalized()*(-1 if suffix==".r" else 1)
		var frame = Basis(along.cross(normal).normalized(),along,normal).orthonormalized()
		palm_frames.append(hand.basis.orthonormalized().inverse()*frame)
		palm_offsets.append(hand.affine_inverse()*(hand.origin+(middle-hand.origin)*.62))
	# Keep the imported 45-bone rig, clips, bind matrices and contact frames intact.
	# Replace geometry only; garments, skin and details all use the same named skin.
	var source_mesh: MeshInstance3D = model.find_children("*","MeshInstance3D")[0]
	source_mesh.visible = false
	human_mesh = MeshInstance3D.new()
	human_mesh.name = "CourtRushHuman"
	human_mesh.mesh = HumanRival if opponent else HumanPlayer
	human_mesh.skin = source_mesh.skin
	skeleton.add_child(human_mesh)
	human_mesh.skeleton = NodePath("..")
	human_mesh.extra_cull_margin = .6
	last_root = global_position

func bone_world(index: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(index)

func set_bone_rotation(index: int, rotation: Basis) -> void:
	var parent = skeleton.get_bone_parent(index)
	var local = skeleton.get_bone_global_pose(parent).basis.inverse()*rotation if parent>=0 else rotation
	skeleton.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())

func aim(index: int, child: int, target: Vector3) -> void:
	var pose = skeleton.get_bone_global_pose(index)
	var before = skeleton.get_bone_global_pose(child).origin-pose.origin
	var after = target-pose.origin
	if before.length_squared()<.00001 or after.length_squared()<.00001: return
	set_bone_rotation(index,Basis(Quaternion(before.normalized(),after.normalized()))*pose.basis)

func solve(chain: Array, world_target: Vector3, pole: Vector3, rear_axis: Vector3 = Vector3.ZERO, rear_limit: float = 0.0, previous_joint: Vector3 = Vector3.ZERO, max_bend_turn: float = 0.0) -> void:
	var root = skeleton.get_bone_global_pose(chain[0]).origin
	var joint = skeleton.get_bone_global_pose(chain[1]).origin
	var end = skeleton.get_bone_global_pose(chain[2]).origin
	var target = skeleton.to_local(world_target)
	var a = root.distance_to(joint)
	var b = joint.distance_to(end)
	var direction = (target-root).normalized()
	var distance = clampf(target.distance_to(root),absf(a-b)+.002,a+b-.002)
	var along = (a*a-b*b+distance*distance)/(2*distance)
	var bend = skeleton.to_local(pole)-root
	bend = (bend-direction*bend.dot(direction)).normalized()
	if bend.length_squared()<.01: bend = direction.cross(Vector3.RIGHT).normalized()
	var radius = sqrt(maxf(0,a*a-along*along))
	if rear_axis.length_squared() > .5 and radius > .001:
		# Choose a point on the same two-bone circle: the wrist and both
		# segment lengths stay fixed while shoulder extension is bounded.
		var forward = (skeleton.global_basis.inverse()*rear_axis).normalized()
		var cap = -rear_limit/maxf(render_scale,.01)
		if (direction*along+bend*radius).dot(forward) < cap:
			var plane = forward-direction*forward.dot(direction)
			if plane.length() > .001:
				var projected = plane.normalized()
				var cosine = clampf((cap-direction.dot(forward)*along)/(radius*plane.length()),-1,1)
				var across = direction.cross(projected).normalized()*sqrt(maxf(0,1-cosine*cosine))
				var first = projected*cosine+across
				var second = projected*cosine-across
				var up = (skeleton.global_basis.inverse()*Vector3.UP).normalized()
				var first_score = first.dot(bend)-(4 if (direction*along+first*radius).dot(up)>-.04/render_scale else 0)
				var second_score = second.dot(bend)-(4 if (direction*along+second*radius).dot(up)>-.04/render_scale else 0)
				bend = first if first_score >= second_score else second
	if max_bend_turn>0:
		var previous=skeleton.to_local(previous_joint)-root
		previous-=direction*previous.dot(direction)
		if previous.length_squared()>.0001:
			previous=previous.normalized()
			var angle=atan2(direction.dot(previous.cross(bend)),previous.dot(bend))
			bend=previous.rotated(direction,clampf(angle,-max_bend_turn,max_bend_turn))
	var knee = root+direction*along+bend*radius
	aim(chain[0],chain[1],knee)
	aim(chain[1],chain[2],root+direction*distance)

func knee_guide(chain: Array, side: int) -> Vector3:
	# A source knee is nearly collinear at toe-off. Using its position as a pole
	# lets a changed ankle target flip the bend plane behind the leg.
	# Use an anatomical forward/outward plane, independent of leg extension.
	var hip=bone_world(chain[0]).origin
	var outward=global_basis.x*(-1.0 if side==0 else 1.0)
	return hip+(global_basis.z+outward*.16).normalized()*.7

func chest_motion_frame() -> Basis:
	# A bone's rest axes are not anatomical chest axes (the imported spine
	# points diagonally forward). Build motion directions from visible joints.
	# Shoulders carry the lean; arm swing uses their heading and gravity.
	# Tilting "down" with a bone's bind axes can lift a recovering elbow.
	var up=Vector3.UP
	var right=bone_world(arms[1][0]).origin-bone_world(arms[0][0]).origin
	right=(right-up*right.dot(up)).normalized()
	var forward=right.cross(up).normalized()
	return Basis(right,forward.cross(right).normalized(),forward).orthonormalized()

func ball_balance_pose(index: int, shoulder: Vector3, chest_frame: Basis, speed: float) -> Dictionary:
	# The ball handler's free hand protects the front of the body. A sprint
	# backswing pulls the upper arm behind the ribs when seen from the side.
	var side = -1.0 if index == 0 else 1.0
	var step = (bone_world(feet[index][2]).origin-bone_world(feet[1-index][2]).origin).dot(global_basis.z)
	var swing = -clampf(step/.60,-1,1)*clampf(speed/3.0,0,1)
	return {
		"target":shoulder+chest_frame*Vector3(side*.045,-.27,.26+swing*.09),
		"guide":shoulder+chest_frame*Vector3(side*.09,-.30,-.09)
	}

func relaxed_hand_basis(index: int, target: Vector3, pole: Vector3) -> Basis:
	# Solve to the palm as an extended forearm. Iterating wrist IK with a
	# new wrist offset can alternate elbow branches near a folded arm.
	var chain: Array=arms[index]
	var shoulder=bone_world(chain[0]).origin
	var elbow=bone_world(chain[1]).origin
	var wrist=bone_world(chain[2]).origin
	var a=shoulder.distance_to(elbow)
	var b=elbow.distance_to(wrist)+(palm_frames[index].inverse()*palm_offsets[index]).y*render_scale
	var direction=(target-shoulder).normalized()
	var distance=clampf(target.distance_to(shoulder),absf(a-b)+.004,a+b-.004)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var bend=pole-shoulder
	bend=(bend-direction*bend.dot(direction)).normalized()
	if bend.length_squared()<.01:bend=global_basis.z
	var joint=shoulder+direction*along+bend*sqrt(maxf(0,a*a-along*along))
	var fingers=(target-joint).normalized()
	var normal=global_basis.x*(1.0 if index==0 else -1.0)
	normal=(normal-fingers*normal.dot(fingers)).normalized()
	var frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
	return frame*palm_frames[index].inverse()

func update_gaze(actor,delta: float) -> void:
	var head_index=skeleton.find_bone("head")
	var neck_index=skeleton.find_bone("neck_01")
	var yaw=clampf(angle_difference(actor.rotation.y,actor.facing)*.55,-.35,.35)
	if actor.action=="shot":yaw=angle_difference(actor.rotation.y,actor.shot_aim_yaw())
	if actor.held.owns(actor):yaw+=actor.held.pose(actor).gaze
	var up=0.0
	if actor.defense_weight>.1 and actor.watch_direction.length_squared()>.01:
		yaw=clampf(angle_difference(actor.rotation.y,atan2(actor.watch_direction.x,actor.watch_direction.z)),-.45,.45)
	if actor.defensive_jump():
		var focus=actor.ball_anchor(0) if actor.defense_caught else actor.defense_target
		var offset=focus-bone_world(head_index).origin
		up=clampf(atan2(offset.y,Vector2(offset.x,offset.z).length()),-.14,.26)
	elif actor.action in ["gather","shot","layup","dunk"]:
		up=.10*(1-smoothstep(.48,.82,actor.action_time))
	elif actor.stealing():up=-.12*actor.steal_reach()
	gaze_target.x=move_toward(gaze_target.x,yaw,delta*2.8)
	gaze_target.y=move_toward(gaze_target.y,up,delta*1.8)
	var forward=(bone_world(head_index).basis*head_forward_local).normalized()
	var correction=clampf(angle_difference(atan2(forward.x,forward.z),actor.rotation.y+gaze_target.x),-.65,.65)
	var pitch=clampf(atan2(forward.y,Vector2(forward.x,forward.z).length())-gaze_target.y,-.55,.55)
	var right=Basis(Vector3.UP,actor.rotation.y+gaze_target.x).x
	for pair in [[neck_index,.30],[head_index,.70]]:
		var rotation=Basis(Vector3.UP,correction*pair[1])*Basis(right,pitch*pair[1])*bone_world(pair[0]).basis.orthonormalized()
		set_bone_rotation(pair[0],skeleton.global_basis.orthonormalized().inverse()*rotation)

func sample_visual_swing(side: int, delta: float) -> Vector3:
	visual_swing_time[side]+=delta
	var progress=clampf(visual_swing_time[side]/visual_swing_duration[side],0,1)
	var goal=visual_swing_from[side].lerp(visual_swing_to[side],smoothstep(0,1,progress))
	goal.y+=sin(progress*PI)*(.10 if not contact_mode else .055)
	if progress>=1:
		visual_swing[side]=false
		leg_return_pending[side]=true
	return goal

func reset_contacts() -> void:
	locked = [false,false]
	run_start_serial=-1
	idle_step=-1
	initialized = false
	arm_weight = [0.0,0.0]
	previous_contact_mode = false
	return_blend = 0
	return_window=.12
	cut_weight = 0
	root_height = 0
	shot_posture_time=0.0
	ground_drop = 0
	locomotion = 0
	basketball_weight=0
	torso_layer=Vector3.ZERO
	was_stopping=false
	clip = ""
	last_action=""
	shot_gather_steps=false
	was_crossing=false
	gaze_target=Vector2.ZERO
	finger_cups=[0.0,0.0]
	guard_step_serial=[-1,-1]
	guard_was_active=false
	guard_entry_time=0.0
	player.stop()
	visual_swing = [false,false]
	physics_swing = [false,false]
	contact_spent = [false,false]
	leg_return_time=[0.0,0.0]
	leg_return_pending=[false,false]

func shift_world_contacts(offset: Vector3) -> void:
	last_root+=offset
	shot_gather_release_origin+=offset
	shot_gather_release_toe+=offset
	for i in range(2):
		anchors[i] += offset
		toe_world[i] += offset
		palm_world[i] += offset
		visual_swing_from[i] += offset
		visual_swing_to[i] += offset
		finish_entry_world[i] += offset
		shot_gather_from[i] += offset
		shot_gather_to[i] += offset
		guard_step_from[i] += offset
		guard_landing_targets[i] += offset

func sync_cut_contacts(_actor) -> void:
	if not initialized: return
	for i in range(2):
		# Preserve the real source contact without teleporting the physics stance.
		# The two rigs have different limb lengths and must not share raw offsets.
		if toe_world[i].y<.08:
			locked[i] = true
			anchors[i] = toe_world[i]
			anchors[i].y = .026

func prepare_idle_stance(actor, speed: float) -> void:
	# Skills may finish on a long or crossed plant. Finish the transfer one
	# shoe at a time instead of locking that last skill frame forever.
	var resting=initialized and clip=="idle" and not contact_mode and actor.action=="idle" and speed<.15 and actor.motion.length()<.15 and not actor.dribble_ended
	if not resting:
		idle_step=-1
		return
	if idle_step>=0 or visual_swing[0] or visual_swing[1]:return
	var worst=.075*actor.height_ratio
	var selected=-1
	var target=Vector3.ZERO
	for i in 2:
		var side=-1.0 if i==0 else 1.0
		var rest=actor.to_global(Vector3(side*.21*actor.height_ratio,.026,0.06))
		rest.y=.026
		var distance=toe_world[i].distance_to(rest)
		if distance>worst:
			worst=distance;selected=i;target=rest
	if selected<0:return
	idle_step=selected
	idle_step_basis=bone_world(feet[selected][2]).basis.orthonormalized()
	visual_swing_from[selected]=toe_world[selected]
	visual_swing_to[selected]=target
	visual_swing_time[selected]=0
	visual_swing_duration[selected]=maxf(.20,worst/3.5)
	visual_swing[selected]=true
	locked[selected]=false

func sample_base(delta: float, speed: float, airborne: bool, contact_phase: float=-1.0) -> void:
	for index in range(base_local.size()): skeleton.set_bone_pose(index,base_local[index])
	var desired = clampf((speed-.12)/2.5,0,1) if not airborne else 0.0
	locomotion = move_toward(locomotion,desired,delta*7)
	var wanted = "run" if locomotion>.08 else "idle"
	if wanted != clip:
		if initialized and final_poses.size()==skeleton.get_bone_count():
			return_poses=transition_pose()
			return_window=.12
			return_blend=.12
		clip = wanted
		player.play(clip,.18 if initialized else 0.0)
	player.speed_scale = clampf(speed/RUN_SPEED,.16,1.15) if clip=="run" else 1.0
	player.advance(delta)
	if clip=="run" and contact_phase>=0:player.seek(fposmod(contact_phase,1)*player.current_animation_length,true)
	# The source bakes stretch into some chains. Gameplay contacts keep rigid lengths.
	for index in range(skeleton.get_bone_count()): skeleton.set_bone_pose_scale(index,Vector3.ONE)
	phase = fposmod(player.current_animation_position/maxf(player.current_animation_length,.01),1) if clip=="run" else .28
	source_poses.clear()
	for index in range(skeleton.get_bone_count()): source_poses.append(skeleton.get_bone_global_pose(index))

func open_fingers(side: int, world_frame: Basis, cup: float = 0.0) -> void:
	var suffix = ".r" if side==0 else ".l"
	var sign_side = -1 if side==0 else 1
	for name in ["index","middle","ring","thumb"]:
		var spread = (0.12 if name=="index" else (-.08 if name=="ring" else (-.65 if name=="thumb" else 0.0)))*sign_side
		var forward = (world_frame.y+world_frame.x*spread).normalized()
		for segment in [1,2]:
			var curl=cup*(.6 if name=="thumb" else float(segment))
			var curved=(forward*cos(curl)+world_frame.z*sin(curl)).normalized()
			var index = skeleton.find_bone(name+"_0"+str(segment)+suffix)
			var next = skeleton.find_bone(name+"_0"+str(segment+1)+suffix)
			var target = skeleton.get_bone_global_pose(index).origin+skeleton.global_basis.inverse()*curved
			aim(index,next,target)

func athlete_target(actor, local: Vector3) -> Vector3:
	local.x*=actor.height_ratio
	local.z*=actor.height_ratio
	local.y=actor.jump+(local.y-actor.jump)*actor.height_ratio
	return actor.to_global(local)

func shot_elbow_guide(actor,chain: Array,wrist: Vector3,palm: Vector3) -> Vector3:
	var shoulder=bone_world(chain[0]).origin
	var elbow=bone_world(chain[1]).origin
	var end=bone_world(chain[2]).origin
	var a=shoulder.distance_to(elbow)
	var b=elbow.distance_to(end)
	var direction=(wrist-shoulder).normalized()
	var distance=clampf(wrist.distance_to(shoulder),absf(a-b)+.002*render_scale,a+b-.002*render_scale)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var center=shoulder+direction*along
	var radius=sqrt(maxf(0,a*a-along*along))
	var right=actor.global_basis.x
	var plane=right-direction*right.dot(direction)
	if radius<.001 or plane.length()<.001:return center+actor.global_basis.z*.1
	# Select an elbow on the fixed-length IK circle directly under its palm.
	# A shoulder-relative pole alone can flare out or cross the face mid-lift.
	var cosine=clampf((palm-center).dot(right)/(radius*plane.length()),-1,1)
	var projected=plane.normalized()*cosine
	var across=direction.cross(plane.normalized())*sqrt(maxf(0,1-cosine*cosine))
	var first=center+(projected+across)*radius
	var second=center+(projected-across)*radius
	var forward=actor.global_basis.z
	var first_score=(first-shoulder).dot(forward)-(1.0 if first.y>wrist.y-.04 else 0.0)
	var second_score=(second-shoulder).dot(forward)-(1.0 if second.y>wrist.y-.04 else 0.0)
	return first if first_score>second_score else second

func shot_pose(actor, side: float, shoulder: Vector3) -> Dictionary:
	if actor.shot_style=="hook":return hook_pose(actor,side,shoulder)
	var clock=actor.shot_arm_time()
	var aim=Basis(Vector3.UP,actor.shot_aim_yaw())
	var shooting=side==actor.dribble_hand
	var rise=smoothstep(0,.22,clock) if actor.action=="shot" else 0.0
	var lift=smoothstep(0,.30,clock) if actor.action in ["gather","fake"] else 1.0
	var head_root=actor.to_local(bone_world(skeleton.find_bone("head")).origin)
	var head=aim.inverse()*(bone_world(skeleton.find_bone("head")).origin-actor.global_position)
	var head_height=(head.y-actor.jump)/actor.height_ratio
	var center=Vector3(head.x/actor.height_ratio+actor.dribble_hand*.065,lerpf(1.12,head_height+.18,lift)+actor.jump,.34)
	center.z=maxf(center.z,head.z/actor.height_ratio+.22)
	if actor.action=="shot":center.y=head_height+lerpf(.18,.50,rise)+actor.jump
	var normal=Vector3.UP if shooting else aim.x*-side
	var fingers=aim.z if shooting else (Vector3.UP*.65+aim.z*.76).normalized()
	var target=shot_target(actor,center,aim)+(-Vector3.UP*.125 if shooting else aim.x*side*.125)
	# Stack the forearm in front of the face. A pole offset from the shoulder
	# leaves the elbow flared beside the head even when the palm holds the ball.
	var elbow_x=center.x+(0.0 if shooting else side*.04)
	var guide=shot_target(actor,Vector3(elbow_x,center.y-(.42 if shooting else .30),center.z+.14),aim)
	if actor.action=="shot":
		var index=0 if side<0 else 1
		var extension=smoothstep(.015,.22,clock)
		var carried=actor.to_global(entry_palms[index]+head_root-finish_entry_head)
		target=carried.lerp(target,extension)
		var ready=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
		var support=entry_frames[index].slerp(ready,extension)
		normal=support.z;fingers=support.y
		var follow=smoothstep(.22,.34,clock)
		if shooting:
			var angle=follow*1.25
			normal=Vector3.UP*cos(angle)+aim.z*sin(angle)
			fingers=aim.z*cos(angle)-Vector3.UP*sin(angle)
			target+=aim.z*.08*follow+Vector3.UP*.025*follow
		else:
			# The guide hand peels down from the ball after release; it must not
			# remain beside the head as if both arms threw the shot together.
			var peel=smoothstep(.22,.40,clock)
			target=target.lerp(shot_target(actor,Vector3(side*.27,head_height-.26+actor.jump,.30),aim),peel)
			guide=guide.lerp(shoulder+aim*Vector3(side*.16,-.24,.17),peel)
			var relaxed_fingers=(Vector3.DOWN*.25+aim.z*.97).normalized()
			var relaxed_normal=(aim.x*-side+Vector3.UP*.15).normalized()
			var relaxed=Basis(relaxed_fingers.cross(relaxed_normal).normalized(),relaxed_fingers,relaxed_normal).orthonormalized()
			var present=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized().slerp(relaxed,peel)
			normal=present.z;fingers=present.y
		var recover=smoothstep(.44 if shooting else .40,.84 if shooting else .72,clock)
		target=target.lerp(athlete_target(actor,Vector3(side*.24,1.24+root_height+.055,.18)),recover)
		guide=guide.lerp(shoulder+aim*Vector3(side*.12,-.28,.10),recover)
	var frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
	return {"target":target,"frame":frame,"guide":guide}

# Side-on jump hook: two hands gather, the guide hand peels to protect the
# chest, and the shooting elbow leads a high one-handed arc over the shoulder.
func hook_pose(actor,side: float,shoulder: Vector3) -> Dictionary:
	var clock=actor.shot_arm_time()
	var shooting=side==actor.dribble_hand
	var gather=actor.action=="gather"
	var lift=smoothstep(0,.34,actor.action_time) if gather else 1.0
	var extend=smoothstep(0,.22,clock) if not gather else 0.0
	var head=actor.to_local(bone_world(skeleton.find_bone("head")).origin)
	var center=Vector3(actor.dribble_hand*lerpf(.22,.34,lift),lerpf(1.15,head.y-actor.jump+.10,lift)+actor.jump,.28)
	center.y+=.27*extend
	var target=actor.to_global(center)+(-Vector3.UP*.125 if shooting else global_basis.z*.125)
	var normal=Vector3.UP if shooting else -global_basis.z
	var fingers=global_basis.x*actor.dribble_hand if shooting else Vector3.UP
	var guide=actor.to_global(Vector3(actor.dribble_hand*.39,center.y-.36,.19))
	if not gather:
		var carried=actor.to_global(entry_palms[0 if side<0 else 1]+head-finish_entry_head)
		target=carried.lerp(target,smoothstep(0,.22,clock))
		if shooting:
			var follow=smoothstep(.22,.36,clock)*1.2
			normal=Vector3.UP*cos(follow)+global_basis.x*side*sin(follow)
			fingers=global_basis.x*side*cos(follow)-Vector3.UP*sin(follow)
		else:
			target=target.lerp(actor.to_global(Vector3(-actor.dribble_hand*.24,1.35+actor.jump,.25)),smoothstep(.08,.21,clock))
			guide=shoulder+global_basis*Vector3(side*.14,-.27,.12)
		var recover=smoothstep(.44,.84,clock)
		target=target.lerp(athlete_target(actor,Vector3(side*.24,1.24+root_height+.055,.18)),recover)
		guide=guide.lerp(shoulder+global_basis*Vector3(side*.12,-.28,.05),recover)
	var frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
	return {"target":target,"frame":frame,"guide":guide}

func shot_target(actor,local: Vector3,aim: Basis) -> Vector3:
	return actor.global_position+aim*Vector3(local.x*actor.height_ratio,actor.jump+(local.y-actor.jump)*actor.height_ratio,local.z*actor.height_ratio)

func layup_pose(actor, side: float, shoulder: Vector3) -> Dictionary:
	var shooting=side==actor.dribble_hand
	var gathering=actor.action=="gather"
	var lift=smoothstep(.045,.34,actor.action_time) if not gathering else 0.0
	var pocket=smoothstep(0,.18,actor.action_time) if gathering else 1.0
	var center=Vector3(actor.dribble_hand*.14,lerpf(1.12,1.30,pocket)+actor.jump,.29)
	if not gathering:center=Vector3(actor.dribble_hand*.14,lerpf(1.30,2.13,lift)+actor.jump,lerpf(.29,.38,lift))
	var target=athlete_target(actor,center)+(-Vector3.UP*.125 if shooting else global_basis.x*side*.125)
	var normal=Vector3.UP if shooting else global_basis.x*-side
	var fingers=global_basis.z if shooting else (Vector3.UP*.65+global_basis.z*.76).normalized()
	var guide=shoulder+global_basis*Vector3(side*.025,lerpf(-.28,.08,lift),.24)
	if not gathering:
		var index=0 if side<0 else 1
		var carried=actor.to_global(entry_palms[index]+Vector3.UP*(root_height-finish_entry_height))
		target=carried.lerp(target,lift)
		var ready=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
		var support=entry_frames[index].slerp(ready,lift)
		normal=support.z;fingers=support.y
		if shooting:
			var roll=smoothstep(.34,.46,actor.action_time)*1.05
			normal=Vector3.UP*cos(roll)+global_basis.z*sin(roll)
			fingers=global_basis.z*cos(roll)-Vector3.UP*sin(roll)
		else:
			target=target.lerp(athlete_target(actor,Vector3(side*.31,1.29+actor.jump,.17)),smoothstep(.07,.25,actor.action_time))
			guide=shoulder+global_basis*Vector3(side*.08,-.30,.02)
		var recover=smoothstep(.48,.82,actor.action_time)
		target=target.lerp(athlete_target(actor,Vector3(side*.27,1.18+root_height+.025,.17)),recover)
		guide=guide.lerp(shoulder+global_basis*Vector3(side*.06,-.34,.02),recover)
	var frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
	return {"target":target,"frame":frame,"guide":guide}

func rebound_pose(actor, index: int, shoulder: Vector3) -> Dictionary:
	var side=-1.0 if index==0 else 1.0
	var rest=athlete_target(actor,Vector3(side*.30,1.12,.22))
	var target=actor.defense_target+global_basis.x*side*.135-global_basis.z*.02
	var local=actor.to_local(target)
	local.z=maxf(.16,local.z)
	target=actor.to_global(local)
	if actor.defense_caught:
		var elapsed=actor.action_time-actor.defense_catch_time
		var received: Vector3=actor.defense_catch_hands[index]+actor.defense_catch_velocity*.035*(1-exp(-elapsed/.035))
		var secure=athlete_target(actor,Vector3(side*.125,1.94+actor.jump,.27))
		var chest=athlete_target(actor,Vector3(side*.125,1.38+actor.jump-.06*actor.defense_landing_load(),.26))
		target=received.lerp(secure,smoothstep(.035,.13,elapsed)).lerp(chest,actor.rebound_tuck_phase())
	else:
		target=actor.defense_start_hands[index].lerp(target,smoothstep(.025,.25,actor.action_time))
		target=target.lerp(rest,smoothstep(actor.defense_land_time()-.10,actor.defense_duration(),actor.action_time))
	var fingers=(Vector3.UP*.80+global_basis.z*.60).normalized()
	var normal=global_basis.x*-side
	var frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
	var guide=shoulder+global_basis*Vector3(side*.055,-.25,.18)
	return {"target":target,"frame":frame,"guide":guide}

func update_pose(actor, delta: float, speed: float, teleported: bool) -> void:
	if teleported: reset_contacts()
	var hands_before_turn = last_hand_basis.duplicate()
	if initialized and actor.ordinary_dribble():
		# A free wrist turns with the athlete before its local swing is eased.
		# Easing only in world space lets the chest turn past the hand during
		# a cut, leaving the fingers pointing backwards along the forearm.
		var free_hand = 0 if actor.dribble_hand > 0 else 1
		var transport = global_basis.orthonormalized()*previous_root_basis.inverse()
		last_hand_basis[free_hand] = transport*last_hand_basis[free_hand]
	previous_root_basis = global_basis.orthonormalized()
	if actor.action!=last_action:
		action_entry_time=0
		action_entry_height=root_height
		if actor.action=="gather":
			gather_entry_height=root_height
			begin_shot_gather(actor)
		if actor.action in ["shot","layup"]:
			finish_entry_height=root_height
			finish_entry_head=actor.to_local(bone_world(skeleton.find_bone("head")).origin)
			if actor.action=="shot" and shot_gather_steps:shot_gather_exit=shot_gather_clock+delta
			for i in 2:
				finish_entry_toes[i]=actor.to_local(toe_world[i])
				finish_entry_world[i]=toe_world[i]
				if actor.action=="shot" and shot_gather_steps:
					finish_entry_world[i]=shot_gather_to[i]
					finish_entry_toes[i]=actor.to_local(shot_gather_to[i])
		for i in 2:
			entry_palms[i]=actor.to_local(palm_world[i])
			entry_frames[i]=last_hand_basis[i]*palm_frames[i]
			if actor.crossing():cross_entry_frames[i]=entry_frames[i]
			if was_crossing:cross_return_frames[i]=entry_frames[i]
		last_action=actor.action
	action_entry_time+=delta
	if actor.action=="gather":shot_gather_clock=actor.action_time
	was_crossing=actor.crossing()
	var action_pose = actor.action not in ["idle","cross","spin","twostep","behind","hesi","showcase"] or actor.jump>.05
	var guard_weight: float=actor.defense_weight if not actor.has_ball and actor.action=="idle" and not actor.chase_recovery else 0.0
	var guard_active=guard_weight>.5
	if guard_active and not guard_was_active and initialized:
		# Finish the pursuit stride before adopting the short shuffle contacts.
		# A foot still far behind the hips cannot become a defensive plant: it
		# would pull the entire torso down to satisfy an unreachable old anchor.
		for i in 2:
			var offset=actor.to_local(toe_world[i])
			if Vector2(offset.x,offset.z).length()>.60 or toe_world[i].y>.12:guard_active=false
	if guard_active and not guard_was_active:
		guard_entry_time=0.0
		for i in 2:
			guard_step_from[i]=toe_world[i]
			guard_step_serial[i]=-1
			guard_landing_targets[i]=toe_world[i]
			guard_landing_targets[i].y=.026
			guard_entry_bases[i]=bone_world(feet[i][2]).basis.orthonormalized()
			visual_swing[i]=false
	if guard_active:guard_entry_time+=delta
	guard_was_active=guard_active
	var transition = actor.brake_state!="" or actor.restart_left>0 or actor.chase_recovery or actor.shot_recovery_left>0
	contact_mode = action_pose or actor.defense_weight>.35 or actor.boxout_weight>.2 or transition or actor.held.owns(actor)
	if contact_mode and not previous_contact_mode and initialized:
		# Free running can lag the authored recovery target to keep shoe speed
		# bounded. Rebase an in-flight step on the shoe actually rendered before
		# handing it to the contact layer; its old trajectory may be far ahead.
		for i in 2:
			if visual_swing[i]:
				visual_swing_from[i]=toe_world[i]
				visual_swing_duration[i]=maxf(.08,visual_swing_duration[i]-visual_swing_time[i])
				visual_swing_time[i]=0
	# A shuffle has its own alternating contacts. Do not retain sprint pelvis
	# rotation and shoulder bob underneath a planted defensive stance.
	var was_run_clip=clip=="run"
	sample_base(delta,speed,(action_pose and not actor.moving_gather()) or actor.brake_state in ["load","settle"] or guard_active or actor.held.owns(actor),actor.stride/TAU+.21)
	if clip=="run" and not was_run_clip:run_start_serial=actor.step_serial
	var first_run_step=clip=="run" and not contact_mode and actor.step_serial==run_start_serial and actor.last_step>=0 and actor.swing_progress[actor.last_step]<.55
	if previous_contact_mode and not contact_mode and clip=="run":
		# The authored clip already follows the same alternating contact phase.
		# Do not seek to a second guessed foot at the first free running frame.
		return_poses = transition_pose()
		return_window=.20 if actor.run_entry_left>0 and not actor.has_ball else .12
		return_blend = return_window
	if return_blend>0 and return_poses.size()==skeleton.get_bone_count():
		return_blend = maxf(0,return_blend-delta)
		var weight = smoothstep(0,return_window,return_window-return_blend)
		for index in range(return_poses.size()):
			skeleton.set_bone_pose(index,return_poses[index].interpolate_with(skeleton.get_bone_pose(index),weight))
	previous_contact_mode = contact_mode
	for i in range(2):
		if leg_return_time[i]<=0 or leg_return_poses[i].size()!=feet[i].size():continue
		leg_return_time[i]=maxf(0,leg_return_time[i]-delta)
		var weight=smoothstep(0,.10,.10-leg_return_time[i])
		for j in range(feet[i].size()):
			var bone=feet[i][j]
			skeleton.set_bone_pose(bone,leg_return_poses[i][j].interpolate_with(skeleton.get_bone_pose(bone),weight))
	# Center the imported root on the player's hips, keeping the authored sway.
	var athletic=not action_pose and actor.defense_weight<.1 and actor.boxout_weight<.1 and not actor.dribble_ended
	var free_grounded=not action_pose and not contact_mode and not actor.dribble_ended
	basketball_weight=move_toward(basketball_weight,clampf(speed/3.0,0,1) if athletic else 0.0,delta*7)
	var stance_drop=.045*basketball_weight
	var cross_pose=actor.cross_body_pose()
	var cross_weight: float=cross_pose.weight
	var height_target = (-.055 if actor.has_ball else -.025)-stance_drop
	height_target-=cross_pose.drop*.55*cross_weight
	if action_pose: height_target = actor.body.position.y+.08
	elif contact_mode: height_target = minf(0,actor.body.position.y+.16)
	if guard_weight>0:height_target=lerpf(height_target,-.20-.035*actor.boxout_weight-.025*actor.pressure_weight,guard_weight)
	var shooting_pose=actor.action in ["gather","fake","shot"] and actor.finish_kind=="shot"
	if shooting_pose:
		height_target=actor.jump-.055
		if actor.action in ["gather","fake"]:height_target-=.08*sin(clampf(actor.action_time/.60,0,1)*PI)
		else:height_target-=.04*(1-smoothstep(0,.12,actor.action_time))+.045*sin(smoothstep(.62,.86,actor.action_time)*PI)
	if actor.action=="gather" and actor.finish_kind in ["shot","layup"]:
		height_target=lerpf(gather_entry_height,-.21 if actor.finish_kind=="shot" else -.16,smoothstep(0,.18,actor.action_time))
	if actor.action=="fake" and actor.finish_kind=="shot":
		height_target=lerpf(action_entry_height,height_target,smoothstep(0,.12,actor.action_time))
	if actor.action in ["shot","layup"]:height_target=finish_root(actor)
	if actor.held.owns(actor):height_target=lerpf(action_entry_height,-actor.held.pose(actor).drop,smoothstep(0,.16,actor.held.entry_time))
	if actor.action=="pickup":height_target-=.30*sin(clampf(actor.action_time/.28,0,1)*PI)*(1-smoothstep(.35,.8,actor.pickup_from.y))
	if actor.defensive_jump():height_target=lerpf(action_entry_height,height_target,smoothstep(0,actor.defense_plant_time(),action_entry_time))
	root_height = move_toward(root_height,height_target,delta*1.8) if initialized and not action_pose else height_target
	model.position = Vector3(0,root_height,-.255*render_scale)
	model.position.x=cross_pose.shift*actor.cross_from*cross_weight
	if guard_weight>0:
		var support=0.0
		for i in 2:
			if actor.swinging[i]:support=(-1.0 if i==1 else 1.0)*sin(actor.swing_progress[i]*PI)
		model.position.x+=support*.025*guard_weight
		model.position+=actor.body.position*Vector3(1,0,1)*guard_weight
	var pelvis=skeleton.find_bone("pelvis")
	var stopping=actor.brake_state!="" and not actor.chase_recovery and not action_pose
	if stopping and not was_stopping:stop_height=pelvis_world_height if initialized else bone_world(pelvis).origin.y
	was_stopping=stopping
	# A small torso layer carries basketball intent; free running arms retain the clip.
	var spine = skeleton.find_bone("spine_01")
	var chest = skeleton.find_bone("spine_02")
	var turn = clampf(actor.cut_twist,-.55,.55)
	var foot_separation=(bone_world(feet[1][2]).origin-bone_world(feet[0][2]).origin).dot(global_basis.z)
	var gait_sway=clampf(foot_separation/.65,-1,1)
	var layer = Vector3((.055 if actor.has_ball else 0.0)+(.10 if actor.has_ball else .12)*basketball_weight,turn*.65+gait_sway*.055*basketball_weight,actor.body.rotation.z*.45)
	if actor.redirect_left>0:layer.x+=.055*sin(actor.redirect_left/.22*PI)
	if contact_mode: layer = Vector3(actor.upper.rotation.x*.45,actor.upper.rotation.y*.6,actor.upper.rotation.z*.5)
	if guard_weight>0:
		var travel=actor.global_basis.inverse()*Vector3(actor.motion.x,0,actor.motion.y)
		var load=0.0
		for i in 2:
			if actor.swinging[i]:load=(-1.0 if i==0 else 1.0)*sin(actor.swing_progress[i]*PI)
		var torso_axis=(bone_world(arms[0][0]).origin+bone_world(arms[1][0]).origin-bone_world(feet[0][0]).origin-bone_world(feet[1][0]).origin)*.5
		var source_pitch=atan2(torso_axis.dot(global_basis.z),torso_axis.y)
		var guard_layer=Vector3(lerpf(.24,.15,actor.boxout_weight)-source_pitch,clampf(travel.x*.016,-.07,.07),clampf(-travel.x*.022,-.08,.08)+load*.018)
		layer=layer.lerp(guard_layer,guard_weight)
	if cross_weight>0:
		# The sprint clip has its own torso yaw. Replace that yaw during the
		# transfer instead of adding an unrelated second shoulder rhythm.
		var line=actor.global_basis.inverse()*(bone_world(arms[1][0]).origin-bone_world(arms[0][0]).origin)
		var source_yaw=atan2(-line.z,line.x)
		var receiving_yaw=cross_pose.twist*actor.cross_from+turn*.35
		layer.y=lerpf(layer.y,angle_difference(source_yaw,receiving_yaw),cross_weight)
		layer.x+=cross_pose.pitch*cross_weight
		layer.z+=cross_pose.roll*actor.cross_from*cross_weight
	if actor.action=="gather" and actor.finish_kind in ["shot","layup"]:
		layer.x=lerpf(layer.x,.11,smoothstep(0,.18,actor.action_time))
	if actor.action in ["shot","layup"]:
		var times=finish_times(actor)
		var extend=smoothstep(times.x*.5,.22 if actor.action=="shot" else .34,actor.action_time)
		var absorb=clampf((actor.jump+(-.055 if actor.action=="shot" else -.025))-height_target,0,.14)/.14
		layer.x=lerpf(.11,-.035,extend)+.14*absorb
		if actor.action=="shot" and actor.shot_style=="fadeaway":layer.x-=.22*sin(clampf((actor.action_time-.09)/.63,0,1)*PI)
		if actor.action=="layup":
			layer.y=actor.dribble_hand*.08*sin(clampf(actor.action_time/.82,0,1)*PI)
			layer.z=-actor.dribble_hand*.035*sin(clampf(actor.action_time/.82,0,1)*PI)
	if actor.stealing():layer.x+=.55*actor.steal_reach()+actor.body.rotation.x
	if actor.action=="pickup":layer.x+=.38*sin(clampf(actor.action_time/.28,0,1)*PI)*(1-smoothstep(.35,.8,actor.pickup_from.y))
	shot_posture_time=shot_posture_time+delta if shooting_pose else 0.0
	if shooting_pose:
		var axis=actor.global_basis.inverse()*(bone_world(arms[0][0]).origin+bone_world(arms[1][0]).origin-bone_world(feet[0][0]).origin-bone_world(feet[1][0]).origin)*.5
		var line=actor.global_basis.inverse()*(bone_world(arms[1][0]).origin-bone_world(arms[0][0]).origin)
		var settle=smoothstep(0,.18,shot_posture_time)
		layer.x=lerpf(layer.x,.08-atan2(axis.z,axis.y),settle)
		if actor.shot_style=="fadeaway" and actor.action=="shot":layer.x-=.20*sin(clampf((actor.action_time-.09)/.63,0,1)*PI)
		layer.y=lerpf(layer.y,angle_difference(actor.rotation.y,actor.shot_aim_yaw())-atan2(-line.z,line.x),settle)
	torso_layer=torso_layer.lerp(layer,1-exp(-delta*18)) if initialized else layer
	# Cancellation of an authored yaw must use this frame's source pose;
	# filtering that cancellation would leave yesterday's sprint twist behind.
	if cross_weight>0:torso_layer.y=layer.y
	if shooting_pose:torso_layer=layer
	if actor.held.owns(actor):
		var held_pose=actor.held.pose(actor)
		var line=actor.global_basis.inverse()*(bone_world(arms[1][0]).origin-bone_world(arms[0][0]).origin)
		torso_layer=Vector3(held_pose.pitch,held_pose.twist-atan2(-line.z,line.x),held_pose.roll)
	unlayered_poses.clear()
	for bone in range(skeleton.get_bone_count()):unlayered_poses.append(skeleton.get_bone_pose(bone))
	for bone in [spine,chest]:
		var rotation=skeleton.get_bone_global_pose(bone).basis
		set_bone_rotation(bone,Basis.from_euler(torso_layer*.5)*rotation)
	if not action_pose:
		var neck=skeleton.find_bone("neck_01")
		set_bone_rotation(neck,Basis(Vector3.RIGHT,-torso_layer.x*.45)*skeleton.get_bone_global_pose(neck).basis)
	cut_weight = move_toward(cut_weight,1.0 if contact_mode else 0.0,delta*12)
	var goals: Array = []
	var foot_bases: Array = []
	var ankle_goals: Array = []
	var free_foot_ik: Array = []
	var support_drop = 0.0
	prepare_idle_stance(actor,speed)
	for i in range(2):
		var chain: Array = feet[i]
		var foot = bone_world(chain[2])
		var toe = bone_world(chain[3]).origin
		var desired_basis = foot.basis.orthonormalized()
		var source_contact = fposmod(phase-(.21 if i==1 else .71),1)<.33
		var was_locked: bool = locked[i]
		# Imported .l is the right side in this model's +Z facing convention.
		if clip=="idle": source_contact = true
		if contact_mode: source_contact = not actor.swinging[i] and not visual_swing[i] and actor.jump<.05 and (was_locked or not initialized or toe_world[i].y<.045)
		if guard_active:source_contact=not actor.swinging[i] and was_locked
		if first_run_step and i!=actor.last_step:
			source_contact=true
			visual_swing[i]=false
		if visual_swing[i]:source_contact=false
		if not source_contact:contact_spent[i]=false
		if not contact_mode and source_contact and not locked[i] and initialized:
			# A reach-expired plant cannot re-capture on the next frame of the
			# same stance window. Wait for the next swing/contact cycle.
			source_contact=(clip=="idle" or not contact_spent[i]) and toe_world[i].y<.075
		if source_contact and not locked[i]:
			anchors[i] = toe_world[i] if initialized else toe
			anchors[i].y = .026
			contact_spent[i]=true
		locked[i] = source_contact
		# Keep the authored heel-to-toe roll. Flattening this ankle to a small
		# generic heel lift cuts off the long trailing push even with a wide stride.
		# Preserve the authored foot trajectory while lowering the pelvis. Both
		# knees flex; lowering the whole source alone would sink free feet.
		var authored_toe=skeleton.global_transform*source_poses[chain[3]].origin
		if return_blend>0:authored_toe=toe
		var free_goal=authored_toe+Vector3.UP*maxf(0,-root_height) if athletic or free_grounded else toe
		if free_grounded:free_goal.y=maxf(.026,free_goal.y)
		if athletic:
			var step_local=actor.to_local(free_goal)
			# Keep the source runner's reaching stride and heel recovery. Crushing
			# these arcs into short, low steps reads as shuffling at running speed.
			step_local.z*=lerpf(1,.98,basketball_weight)
			step_local.y=lerpf(step_local.y,.026+maxf(0,step_local.y-.026)*.92,basketball_weight)
			step_local.y=maxf(.026,step_local.y)
			free_goal=actor.to_global(step_local)
		var goal = anchors[i] if locked[i] else free_goal
		var settling=not contact_mode and clip=="idle" and not locked[i] and initialized
		if settling:
			var rest_goal=Vector3(toe.x,.026,toe.z)
			goal=toe_world[i].move_toward(rest_goal,delta*2)
		free_foot_ik.append(settling or free_grounded or (athletic and basketball_weight>.001))
		if not contact_mode and visual_swing[i]:
			goal=sample_visual_swing(i,delta)
			free_foot_ik[i]=true
			if idle_step==i:
				var progress=clampf(visual_swing_time[i]/visual_swing_duration[i],0,1)
				desired_basis=idle_step_basis.slerp((global_basis*foot_rest_basis[i]).orthonormalized(),smoothstep(0,1,progress))
				if not visual_swing[i]:
					anchors[i]=goal;locked[i]=true;idle_step=-1
		if contact_mode:
			goal = actor.shoes[i].to_global(actor.LAYUP_TOE)
			goal.y -= .105
			goal.y = maxf(.026,goal.y)
			if actor.jump>.05: goal.y += .06
			# A newly planted foot is already captured from the visible rig above.
			# Do not replace that first contact with the old rig's different-size shoe.
			if locked[i]: goal = anchors[i]
			if initialized and not locked[i] and not guard_active:
				if actor.swinging[i] and not physics_swing[i] and not visual_swing[i]:
						visual_swing_from[i]=toe_world[i]
						visual_swing_to[i]=goal+actor.swing_to[i]-actor.shoes[i].global_position
						visual_swing_to[i].y=.026
						visual_swing_time[i]=0.0
						visual_swing_duration[i]=maxf(.15,visual_swing_from[i].distance_to(visual_swing_to[i])/5.0)
						visual_swing[i]=true
				if visual_swing[i]:
					goal=sample_visual_swing(i,delta)
				else:
					# Entering a contact layer must not teleport an airborne source foot.
					goal=toe_world[i].move_toward(goal,delta*6.0)
			var contact_basis = Basis(Vector3.UP,actor.feet_yaw[i])*Basis(Vector3.RIGHT,actor.landing_push_pitch[i])*foot_rest_basis[i]
			desired_basis = desired_basis.slerp(contact_basis,cut_weight)
			if locked[i]:
				anchors[i] = goal
		if guard_active:
			# One clock owns both rigs. Rebuilding a .15s visual swing for a
			# shorter gameplay step leaves the trailing foot airborne at the
			# next lead step. Use the same progress, starting at the visible toe.
			visual_swing[i]=false
			if actor.swinging[i]:
				if guard_step_serial[i]!=actor.step_serial:
					guard_step_from[i]=toe_world[i]
					guard_step_serial[i]=actor.step_serial
					guard_step_phase[i]=maxf(0,actor.swing_progress[i]-delta/actor.swing_duration[i])
				var landing: Vector3=actor.swing_to[i]+Basis(Vector3.UP,actor.feet_yaw[i])*Vector3(0,0,.10*actor.height_ratio)
				landing.y=.026
				guard_landing_targets[i]=landing
				var t=clampf((actor.swing_progress[i]-guard_step_phase[i])/maxf(.01,1-guard_step_phase[i]),0,1)
				goal=guard_step_from[i].lerp(landing,smoothstep(0,1,t))
				goal.y+=sin(t*PI)*.026
				locked[i]=false
			else:
				if physics_swing[i]:
					guard_landing_targets[i]=actor.swing_to[i]+Basis(Vector3.UP,actor.feet_yaw[i])*Vector3(0,0,.10*actor.height_ratio)
					guard_landing_targets[i].y=.026
				goal=anchors[i] if locked[i] else guard_landing_targets[i]
			if not locked[i]:
				goal=toe_world[i].move_toward(goal,delta*6.5)
				if not actor.swinging[i] and goal.distance_to(guard_landing_targets[i])<.002:
					anchors[i]=goal
					locked[i]=true
			desired_basis=guard_entry_bases[i].slerp(Basis(Vector3.UP,actor.feet_yaw[i])*foot_rest_basis[i],smoothstep(0,.14,guard_entry_time))
		physics_swing[i]=actor.swinging[i]
		if actor.action=="gather" and shot_gather_steps:
			if i!=shot_gather_first and actor.action_time>=SHOT_GATHER_FIRST_END and not shot_gather_closing:
				shot_gather_closing=true
				if shot_gather_released:shot_gather_from[i]=toe_world[i]
			var start=0.0 if i==shot_gather_first else SHOT_GATHER_FIRST_END
			var duration=SHOT_GATHER_FIRST_END if i==shot_gather_first else SHOT_GATHER_STEP_END-SHOT_GATHER_FIRST_END
			var progress=clampf((actor.action_time-start)/duration,0,1)
			goal=shot_gather_toe(actor,i)
			locked[i]=progress>=1 or (actor.action_time<=start and shot_gather_from[i].y<.045)
			if locked[i]:anchors[i]=goal
			visual_swing[i]=false
			var heel=.40*smoothstep(0,SHOT_GATHER_FIRST_END,actor.action_time)*(1-smoothstep(SHOT_GATHER_FIRST_END,.15,actor.action_time)) if i!=shot_gather_first else 0.0
			desired_basis=shot_gather_bases[i].orthonormalized().slerp((global_basis*Basis(Vector3.RIGHT,heel)*foot_rest_basis[i]).orthonormalized(),smoothstep(0,.04,actor.action_time))
			if i!=shot_gather_first and actor.action_time<SHOT_GATHER_FIRST_END:
				var hip=bone_world(chain[0]).origin
				var reach=hip.distance_to(bone_world(chain[1]).origin)+bone_world(chain[1]).origin.distance_to(foot.origin)-.004
				var offset=foot.affine_inverse()*bone_world(chain[3]).origin
				var ankle=goal-desired_basis*offset*render_scale
				if not shot_gather_released and (hip-Vector3.UP*.18).distance_to(ankle)>reach:
					# The old sprint support has already pushed off. Carry that shoe
					# into its closing step instead of dragging it or crushing the hips.
					shot_gather_released=true
					shot_gather_release_origin=actor.global_position
					shot_gather_release_toe=toe_world[i]
					shot_gather_release_time=actor.action_time
				if shot_gather_released:
					goal=shot_gather_toe(actor,i)
					locked[i]=false
		if actor.action in ["shot","layup"]:
			var times=finish_times(actor)
			if actor.action=="shot":times=jumper_times(actor,i)
			var planted=(actor.action=="shot" or i==actor.layup_plant_index) and actor.action_time<=times.x
			if actor.action=="shot" and shot_gather_steps and i!=shot_gather_first and actor.action_time+shot_gather_exit<SHOT_GATHER_STEP_END:planted=false
			goal=finish_toe(actor,i)
			locked[i]=planted or actor.action_time>=times.y
			visual_swing[i]=false
			if locked[i]:anchors[i]=goal
			var heel=.34*smoothstep(.02,times.x,actor.action_time)*(1-smoothstep(times.x,times.x+.14,actor.action_time))
			var pitch=jumper_pitch(actor,i) if actor.action=="shot" else heel if planted or actor.action_time<times.x+.14 else 0.0
			desired_basis=global_basis*Basis(Vector3.RIGHT,pitch)*foot_rest_basis[i]
		if (athletic or free_grounded) and initialized and not locked[i] and not contact_mode:
			# Completing a recovery step must not jump straight to a distant
			# authored stride sample. Carry the actual foot through that handoff.
			# A free running shoe travels with the hips before its local swing.
			# Capping that entire motion in world space spends the swing budget
			# on root travel and leaves the knee/foot behind the advancing body.
			var carried=toe_world[i]+(global_position-last_root) if clip=="run" else toe_world[i]
			goal=carried.move_toward(goal,delta*8.0)
		if actor.held.owns(actor):
			goal=actor.held.toes[i]
			locked[i]=(i==actor.held.support and actor.held.entry_time>=.12) or (i!=actor.held.support and actor.action=="idle" and absf(angle_difference(actor.rotation.y,actor.held.yaw_target))<.001 and actor.held.toes[i].distance_to(actor.held.free_goal)<.002)
			anchors[i]=goal
			visual_swing[i]=false
			desired_basis=actor.held.foot_bases[i].slerp((global_basis*foot_rest_basis[i]).orthonormalized(),smoothstep(0,.14,actor.held.entry_time))
		if clip=="run" and not contact_mode and actor.step_serial==run_start_serial and actor.last_step==i and actor.swinging[i]:
			# The first authored swing must remain airborne through its receiving
			# arc; the idle/run blend must not add an extra early heel tap.
			goal.y=maxf(goal.y,.026+.10*sin(actor.swing_progress[i]*PI))
		goals.append(goal)
		foot_bases.append(desired_basis)
		var toe_offset = foot.affine_inverse()*bone_world(chain[3]).origin
		var ankle_goal = goal-desired_basis*toe_offset*render_scale
		ankle_goals.append(ankle_goal)
		if locked[i]:
			var hip = bone_world(chain[0]).origin
			var knee = bone_world(chain[1]).origin
			var reach = hip.distance_to(knee)+knee.distance_to(foot.origin)-.004
			var horizontal = Vector2(hip.x-ankle_goal.x,hip.z-ankle_goal.z).length_squared()
			var vertical = sqrt(maxf(.01,reach*reach-horizontal))
			support_drop = maxf(support_drop,hip.y-ankle_goal.y-vertical)
	# Let the supporting knee absorb the source pelvis bob; never pull the shoe.
	ground_drop=move_toward(ground_drop,clampf(support_drop,0,.18),delta*2.0) if initialized else clampf(support_drop,0,.18)
	var standing_contact=clip=="idle" and speed<.15 and not action_pose and actor.jump<.05
	if guard_active or standing_contact or first_run_step or (actor.action=="gather" and shot_gather_steps):
		# Contact is a hard reach limit. A height filter may delay standing up,
		# but must not keep the hips above a planted leg's reachable height.
		ground_drop=maxf(clampf(support_drop,0,.28),move_toward(ground_drop,0,delta*.9))
	model.position.y -= ground_drop
	if not action_pose: model.position.y = maxf(-.32,model.position.y)
	# Filter the final supported height, after support-drop correction. Doing
	# it before that correction applies a second vertical impulse on contact.
	var target_pelvis=bone_world(pelvis).origin.y
	if stopping:target_pelvis=minf(target_pelvis,stop_height-actor.brake_weight*.08)
	if initialized and not action_pose:
		var filtered=move_toward(pelvis_world_height,target_pelvis,delta*1.6)
		target_pelvis=minf(filtered,target_pelvis) if guard_active and support_drop>0 else filtered
	var pelvis_shift=(target_pelvis-bone_world(pelvis).origin.y)/render_scale
	var pelvis_parent=skeleton.get_bone_parent(pelvis)
	var parent_basis=skeleton.get_bone_global_pose(pelvis_parent).basis if pelvis_parent>=0 else Basis.IDENTITY
	skeleton.set_bone_pose_position(pelvis,skeleton.get_bone_pose_position(pelvis)+parent_basis.inverse()*Vector3.UP*pelvis_shift)
	for i in range(2):
		var chain: Array = feet[i]
		if locked[i] and initialized:
			var hip=bone_world(chain[0]).origin
			var knee=bone_world(chain[1]).origin
			var ankle=bone_world(chain[2]).origin
			var reach=hip.distance_to(knee)+knee.distance_to(ankle)-.004
			if hip.distance_to(ankle_goals[i])>reach and not guard_active and not standing_contact and not (first_run_step and i!=actor.last_step) and not (actor.action=="gather" and shot_gather_steps):
				# The input controller already scheduled this transfer. The shorter
				# render rig must toe off, not drag the sole or stop the player again.
				locked[i]=false
				contact_spent[i]=true
				if clip=="run" and not contact_mode:
					# Toe off into the same running swing. The old safety step landed
					# again after .16s, creating a second short step inside one stride.
					visual_swing[i]=false
				else:
					visual_swing_from[i]=toe_world[i]
					var side=-1.0 if i==0 else 1.0
					visual_swing_to[i]=actor.global_position+actor.global_basis.x*side*.16+Vector3(actor.motion.x,0,actor.motion.y)*.16+actor.global_basis.z*.12
					visual_swing_to[i].y=.026
					visual_swing_duration[i]=.16
					visual_swing_time[i]=0
					visual_swing[i]=true
				free_foot_ik[i]=true
				var toe_offset=bone_world(chain[2]).affine_inverse()*bone_world(chain[3]).origin
				var lift=toe_world[i]+(global_position-last_root)+Vector3.UP*minf(.035,delta*2)
				ankle_goals[i]=lift-foot_bases[i]*toe_offset*render_scale
		if locked[i] or contact_mode or free_foot_ik[i]:
			var pole = knee_guide(chain,i)
			solve(chain,ankle_goals[i],pole)
			set_bone_rotation(chain[2],skeleton.global_basis.orthonormalized().inverse()*foot_bases[i])
		toe_world[i] = bone_world(chain[3]).origin
		if leg_return_pending[i]:
			leg_return_pending[i]=false
			leg_return_poses[i]=[]
			for bone in chain:leg_return_poses[i].append(skeleton.get_bone_pose(bone))
			leg_return_time[i]=.10
		# Expired reach must release for the next source step, never drag a planted sole.
		var contact_tolerance=.006 if clip=="run" and not contact_mode else .055
		if locked[i] and toe_world[i].distance_to(anchors[i])>contact_tolerance: locked[i] = false
	var anatomical_chest=chest_motion_frame()
	for i in range(2):
		var side = -1.0 if i==0 else 1.0
		var free_dribble_arm = actor.ordinary_dribble() and side!=actor.dribble_hand
		var athletic_arm=(athletic and basketball_weight>.01) or (not action_pose and not actor.has_ball and speed>.15)
		var source_run_arm=athletic_arm and not contact_mode and clip=="run" and not actor.crossing() and (not actor.has_ball or side!=actor.dribble_hand)
		var stationary_guard=actor.ordinary_dribble() and speed<.3
		var holding=actor.has_ball and actor.dribble_ended and actor.action=="idle"
		# Both arms retain their basketball pose through the gap between a
		# running swing and the standing guard; never drop the free arm back
		# to an unrelated source-clip wrist while the player brakes.
		var driven = actor.has_ball
		driven = driven or contact_mode or actor.crossing() or athletic_arm or stationary_guard or actor.action in ["pass","receive"]
		arm_weight[i] = move_toward(arm_weight[i],1.0 if driven else 0.0,delta*10)
		var chain: Array = arms[i]
		var source_palm=bone_world(chain[2])*palm_offsets[i]
		var free_arm_ready=not initialized or previous_palms_local[i].distance_to(to_local(source_palm))<=delta*6.5
		if initialized:
			var source_angle=last_hand_basis[i].get_rotation_quaternion().angle_to(bone_world(chain[2]).basis.orthonormalized().get_rotation_quaternion())
			free_arm_ready=free_arm_ready and source_angle<=delta*12
		if not driven and arm_weight[i]<.001 and free_arm_ready:
			# The free arm belongs to the authored full-body clip. Re-solving its
			# almost-straight elbow can flip the same way as an extended knee.
			palm_world[i]=source_palm
			previous_palms_local[i]=to_local(palm_world[i])
			last_hand_basis[i]=bone_world(chain[2]).basis.orthonormalized()
			arm_errors[i]=0
			continue
		var target: Vector3 = actor.hands[i].global_position
		if actor.ordinary_dribble() and side==actor.dribble_hand:
			# The old prototype's taller shoulder clamps low strokes out of reach.
			# Retarget the actual ball/palm path on this skeleton instead.
			target=actor.body.to_global(actor.dribble_hand_pose())
		elif actor.crossing():
			# Releasing the sender returns to the basketball counter-swing,
			# not the imported sprint's high wrist near the face.
			var foot_delta=(bone_world(feet[i][2]).origin-bone_world(feet[1-i][2]).origin).dot(global_basis.z)
			var swing=-clampf(foot_delta/.60,-1,1)
			var chest_frame=anatomical_chest
			var balance=actor.body.to_local(bone_world(chain[0]).origin+chest_frame*Vector3(side*.035,-.33,.17+swing*.16))
			target=actor.body.to_global(actor.cross_hand_pose(i,balance))
		if actor.crossing() and side==actor.cross_to and actor.cross_phase()>=.85:
			target=actor.cross_ball_world()+Vector3.UP*actor.DRIBBLE_PALM
		var frame = actor.hands[i].global_basis.orthonormalized()
		var guide=actor.body.to_global(actor.elbow_pose[i]) if driven else bone_world(chain[1]).origin
		if actor.ordinary_dribble() and side==actor.dribble_hand:
			# The running chest can overtake the low dribble pocket. A pole in
			# front of that shoulder folds the forearm backwards to reach it.
			# Keep the elbow below/beside the ribs, behind the receiving wrist,
			# in the visible chest frame rather than the root's old heading.
			guide=bone_world(chain[0]).origin+anatomical_chest*Vector3(side*.06,-.30,-.15)
		if actor.crossing() or cross_weight>0:
			var chest_frame=anatomical_chest
			var low_pole=bone_world(chain[0]).origin+Vector3.DOWN*.50+chest_frame.x*side*.015-chest_frame.z*.15
			guide=guide.lerp(low_pole,1.0 if actor.crossing() else cross_weight)
		if holding:
			target=actor.global_position+actor.global_basis*Vector3(side*.125,1.25*actor.height_ratio,.28*actor.height_ratio)
			var normal=global_basis.x*-side
			var fingers=(Vector3.UP*.55+global_basis.z*.83).normalized()
			frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
			guide=bone_world(chain[0]).origin+anatomical_chest*Vector3(side*.13,-.30,-.05)
		if actor.held.owns(actor):
			var held_pose=actor.held.pose(actor)
			target=held_pose.center+actor.global_basis.x*side*.125
			if initialized:target=palm_world[i].move_toward(target,delta*9.0)
			var normal=actor.global_basis.x*-side
			var fingers=(Vector3.UP*.55+actor.global_basis.z*.83).normalized()
			frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
			guide=bone_world(chain[0]).origin+anatomical_chest*Vector3(side*.16,-.29,.08)
		elif stationary_guard and side!=actor.dribble_hand:
			var shoulder=bone_world(chain[0]).origin
			target=shoulder+global_basis*Vector3(side*.04,-.32,.18)
			guide=shoulder+global_basis*Vector3(side*.15,-.27,-.07)
		if shooting_pose:
			var pose=shot_pose(actor,side,bone_world(chain[0]).origin)
			target=pose.target
			frame=pose.frame
			guide=pose.guide
			if initialized:target=palm_world[i].move_toward(target,delta*7.5)
		if actor.action=="layup" or (actor.action=="gather" and actor.finish_kind=="layup"):
			var pose=layup_pose(actor,side,bone_world(chain[0]).origin)
			target=pose.target;frame=pose.frame;guide=pose.guide
		if actor.action=="rebound" and actor.defense_target_valid:
			var pose=rebound_pose(actor,i,bone_world(chain[0]).origin)
			target=pose.target;frame=pose.frame;guide=pose.guide
		if actor.action=="block" and actor.defense_target_valid:
			# Solve the visible skeleton against the authored contact curve itself.
			# The hidden prototype arm has already clamped that curve to a different
			# shoulder/limb length; retargeting its wrist clamps the reach twice.
			target=actor.body.to_global(actor.defense_hand(i))
			guide=bone_world(chain[0]).origin+global_basis*Vector3(side*.18,.20,.08)
		if initialized and actor.action in ["gather","rebound","block","dunk","steal"]:
			var entry=smoothstep(0,.10,action_entry_time)
			target=actor.to_global(entry_palms[i]).lerp(target,entry)
			frame=entry_frames[i].slerp(frame,entry)
		if athletic_arm and (not contact_mode or guard_weight>0 or actor.shot_recovery_left>0) and not actor.crossing() and (not actor.has_ball or side!=actor.dribble_hand):
			# Counter-swing comes from the visible legs, so a planted cut carries
			# shoulder, elbow and hand together rather than using a second clock.
			var foot_delta=(bone_world(feet[i][2]).origin-bone_world(feet[1-i][2]).origin).dot(global_basis.z)
			var swing=-clampf(foot_delta/.60,-1,1)
			var shoulder=bone_world(chain[0]).origin
			var chest_frame=anatomical_chest
			var run_target=shoulder+chest_frame*Vector3(side*.035,-.33,.17+swing*(.16 if actor.has_ball else .22))
			if source_run_arm:run_target=source_palm
			if actor.cross_exit_left>0:run_target=(actor.global_position+actor.cross_exit_hands[i]).lerp(run_target,smoothstep(0,.16,.16-actor.cross_exit_left))
			var run_weight=basketball_weight if actor.has_ball else clampf(speed/3.0,0,1)
			target=target.lerp(run_target,run_weight)
			guide=shoulder+Vector3.DOWN*.50+chest_frame.x*side*.015-chest_frame.z*.15
			frame=frame.slerp(chest_frame*Basis(Vector3.RIGHT,-.25),run_weight)
			if source_run_arm:
				# This limb belongs to the running clip. Preserve the large opposite
				# arm and its elbow plane; only the ball hand owns the dribble stroke.
				guide=bone_world(chain[1]).origin
				frame=bone_world(chain[2]).basis.orthonormalized()*palm_frames[i]
		if actor.action in ["pass","receive"]:
			target = actor.transfer_pose(i)
			var entry = smoothstep(0,.12,action_entry_time)
			target = actor.to_global(entry_palms[i]).lerp(target,entry)
			var normal = global_basis.x*-side
			var fingers = (Vector3.UP*.85+global_basis.z*.25).normalized()
			frame = Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
			guide = bone_world(chain[0]).origin+global_basis*Vector3(side*.12,-.32,-.12)
		if free_dribble_arm and not source_run_arm:
			var pose = ball_balance_pose(i,bone_world(chain[0]).origin,anatomical_chest,speed)
			target=pose.target
			guide=pose.guide
		if guard_weight>0:
			# Blend the guard after the running layer so releasing a stance never
			# replaces the shoulder and palm frame at an arbitrary weight threshold.
			var shoulder=bone_world(chain[0]).origin
			var travel=actor.global_basis.inverse()*Vector3(actor.motion.x,0,actor.motion.y)
			var counter=clampf(travel.x*side*.018,-.045,.045)
			var guard_target=shoulder+anatomical_chest*Vector3(side*(.23+counter),-.12 if i==1 else -.27,.27)
			var brace_target=shoulder+anatomical_chest*Vector3(side*.29,-.27,-.05-.035*actor.pressure_weight)
			target=target.lerp(guard_target.lerp(brace_target,actor.boxout_weight),guard_weight)
			guide=guide.lerp(shoulder+anatomical_chest*Vector3(side*.20,-.23,-.05),guard_weight)
			var fingers=(Vector3.UP*.90+anatomical_chest.x*side*.25).normalized()
			var normal=anatomical_chest.z
			frame=frame.slerp(Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized(),guard_weight)
		if actor.action=="pickup":
			target=actor.pickup_center()+actor.global_basis.x*side*.125
			var normal=actor.global_basis.x*-side
			var fingers=(Vector3.UP*.65+actor.global_basis.z*.76).normalized()
			frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
			guide=bone_world(chain[0]).origin+actor.global_basis*Vector3(side*.18,-.30,.10)
		if (actor.ordinary_dribble() and not free_dribble_arm) or actor.crossing():
			frame = Basis(actor.global_basis.x,actor.global_basis.z,Vector3.DOWN).orthonormalized()
			if actor.ordinary_dribble() and side==actor.dribble_hand:
				var bounce_phase=fposmod(actor.dribble_phase,TAU)/TAU
				frame=Basis(actor.global_basis.x,actor.dribble_palm_pitch(bounce_phase))*frame
			if actor.crossing():
				var press=actor.dribble_palm_pitch(fposmod(actor.dribble_phase,TAU)/TAU) if actor.action_time<actor.cross_wait else .52*sin(clampf(actor.cross_phase()/.50,0,1)*PI)
				if side==actor.cross_from:frame=Basis(actor.global_basis.x,press)*frame
				frame=cross_entry_frames[i].slerp(frame,smoothstep(0,.11,actor.action_time))
			elif actor.cross_exit_left>0:
				frame=cross_return_frames[i].slerp(frame,smoothstep(0,.16,.16-actor.cross_exit_left))
		if actor.stealing() and i==actor.steal_hand:
			# Fingers lead the reach toward a low ball. An upright mannequin hand
			# frame puts the palm above the wrist and makes contact unreachable.
			var fingers=(target-bone_world(chain[0]).origin).normalized()
			var normal=global_basis.z-fingers*global_basis.z.dot(fingers)
			if normal.length_squared()>.01:
				normal=normal.normalized()
				frame=Basis(fingers.cross(normal).normalized(),fingers,normal).orthonormalized()
		if actor.rebound_release_left>0 and actor.ordinary_dribble():
			# Let the captured ball leave the chest with the hands. Resuming the
			# bounce clock must not instantly drop the receiving wrist to the hip.
			var release=smoothstep(0,.20,.20-actor.rebound_release_left)
			target=actor.to_global(entry_palms[i]).lerp(target,release)
			frame=entry_frames[i].slerp(frame,release)
		var desired_hand = frame*palm_frames[i].inverse()
		if not action_pose and not actor.has_ball and not source_run_arm:
			# Guard and pursuit use different elbow guides. Carry the bend plane
			# with the shoulder instead of swapping IK branches in a single tick.
			var shoulder=bone_world(chain[0]).origin
			guide=shoulder+global_basis*Vector3(side*.32,-.30,-.18)
		var source_hand = bone_world(chain[2])
		target = (source_hand*palm_offsets[i]).lerp(target,arm_weight[i])
		desired_hand = source_hand.basis.orthonormalized().slerp(desired_hand,arm_weight[i])
		if (shooting_pose or actor.crossing() or actor.ordinary_dribble() or actor.action in ["layup","rebound"]) and initialized:
			var angle=last_hand_basis[i].get_rotation_quaternion().angle_to(desired_hand.get_rotation_quaternion())
			desired_hand=last_hand_basis[i].slerp(desired_hand,minf(1,delta*12/maxf(.001,angle)))
		var contact_hand = actor.ordinary_dribble() and side==actor.dribble_hand
		if initialized and not action_pose and not contact_hand:
			var desired_local = to_local(target)
			target = to_global(previous_palms_local[i].move_toward(desired_local,delta*6.5))
			target=palm_world[i].move_toward(target,delta*11.0)
		var wrist_target = target-desired_hand*palm_offsets[i]*render_scale
		var rear_axis = anatomical_chest.z if actor.ordinary_dribble() else Vector3.ZERO
		var rear_limit = (.28 if source_run_arm else .105)*actor.height_ratio
		if contact_hand or actor.crossing() or actor.action in ["layup","rebound","block"] or (actor.stealing() and i==actor.steal_hand):
			# A bounded scapula reach lets the shoulder help the dribble, not a longer arm.
			var collar = skeleton.get_bone_parent(chain[0])
			var collar_pose = skeleton.get_bone_global_pose(collar)
			var arm_root = skeleton.get_bone_global_pose(chain[0]).origin
			var toward = skeleton.to_local(wrist_target)-collar_pose.origin
			var reach_rotation = Quaternion((arm_root-collar_pose.origin).normalized(),toward.normalized())
			var reach_angle = reach_rotation.get_angle()
			var reach_limit=.12 if contact_hand or actor.crossing() else .32
			reach_rotation = Quaternion.IDENTITY.slerp(reach_rotation,minf(1,reach_limit/maxf(.001,reach_angle)))
			set_bone_rotation(collar,Basis(reach_rotation)*collar_pose.basis)
		if shooting_pose and actor.shot_style!="hook":
			var stacked=shot_elbow_guide(actor,chain,wrist_target,target)
			var peel=smoothstep(.22,.40,actor.shot_arm_time()) if actor.action=="shot" else 0.0
			guide=stacked.lerp(guide,peel)
		solve(chain,wrist_target,guide,rear_axis,rear_limit,actor.to_global(previous_elbows_local[i]),delta*10 if shooting_pose and initialized else 0.0)
		if shooting_pose and actor.action=="shot" and actor.shot_arm_time()>.48:
			var relax=smoothstep(.48,.84,actor.shot_arm_time())
			desired_hand=desired_hand.slerp(relaxed_hand_basis(i,target,guide),relax)
			frame=desired_hand*palm_frames[i]
			wrist_target=target-desired_hand*palm_offsets[i]*render_scale
			solve(chain,wrist_target,guide,Vector3.ZERO,0.0,actor.to_global(previous_elbows_local[i]),delta*10)
		if contact_hand:
			# A side dribble need not point every finger straight ahead. Let
			# the hand yaw with the forearm while keeping its normal on the ball.
			for refinement in 2:
				var forearm = (bone_world(chain[2]).origin-bone_world(chain[1]).origin).normalized()
				var fingers = forearm-frame.z*forearm.dot(frame.z)
				if fingers.length_squared() > .01:
					fingers=fingers.normalized()
					frame=Basis(fingers.cross(frame.z).normalized(),fingers,frame.z).orthonormalized()
					desired_hand=frame*palm_frames[i].inverse()
					wrist_target=target-desired_hand*palm_offsets[i]*render_scale
					solve(chain,wrist_target,guide,rear_axis,rear_limit)
		if free_dribble_arm or ((athletic_arm or stationary_guard) and (not contact_mode or guard_weight>0 or actor.shot_recovery_left>0) and not actor.crossing() and not holding and (not actor.has_ball or side!=actor.dribble_hand)):
			# The relaxed hand continues the forearm. An upright chest frame here
			# leaves the wrist cocked upward for the entire running cycle.
			desired_hand=desired_hand.slerp(relaxed_hand_basis(i,target,guide),1-guard_weight)
			frame=desired_hand*palm_frames[i]
			wrist_target=target-desired_hand*palm_offsets[i]*render_scale
			solve(chain,wrist_target,guide,rear_axis,rear_limit)
		if actor.crossing():
			var relax=1-actor.cross_contact_weight(side)
			var contact_frame=frame
			var relaxed=relaxed_hand_basis(i,target,guide)*palm_frames[i]
			frame=contact_frame.slerp(relaxed,relax)
			frame=cross_entry_frames[i].slerp(frame,smoothstep(0,.11,actor.action_time))
			desired_hand=frame*palm_frames[i].inverse()
			wrist_target=target-desired_hand*palm_offsets[i]*render_scale
			solve(chain,wrist_target,guide,rear_axis,rear_limit)
		# Free-arm forearm alignment is itself a pose change. Bound it after
		# solving too, so the sending wrist cannot snap when it becomes free.
		if initialized and (actor.ordinary_dribble() or actor.crossing() or (not action_pose and not actor.has_ball)):
			var angle=last_hand_basis[i].get_rotation_quaternion().angle_to(desired_hand.get_rotation_quaternion())
			var wrist_rate=12.0 if not actor.has_ball else 20.0
			desired_hand=last_hand_basis[i].slerp(desired_hand,minf(1,delta*wrist_rate/maxf(.001,angle)))
			if actor.ordinary_dribble():
				# Root transport and local easing must also respect the final
				# visible wrist speed, including the first frame after a cross.
				var world_angle=hands_before_turn[i].get_rotation_quaternion().angle_to(desired_hand.get_rotation_quaternion())
				desired_hand=hands_before_turn[i].slerp(desired_hand,minf(1,delta*23.5/maxf(.001,world_angle)))
			frame=desired_hand*palm_frames[i]
			wrist_target=target-desired_hand*palm_offsets[i]*render_scale
			solve(chain,wrist_target,guide,rear_axis,rear_limit)
		set_bone_rotation(chain[2],skeleton.global_basis.orthonormalized().inverse()*desired_hand)
		if driven or arm_weight[i]>.001:
			var cup=.62 if source_run_arm else .32
			if guard_weight>0:cup=lerpf(cup,.08,guard_weight)
			if contact_hand or actor.crossing() or actor.action in ["block","rebound","layup","shot","gather"]:cup=.04
			if actor.action=="rebound" and actor.defense_caught:cup=.20*smoothstep(0,.08,actor.action_time-actor.defense_catch_time)
			if actor.action=="gather":cup=.12
			finger_cups[i]=move_toward(finger_cups[i],cup,delta*2.5)
			open_fingers(i,frame,finger_cups[i])
		arm_errors[i] = (bone_world(chain[2])*palm_offsets[i]).distance_to(target)
		palm_world[i] = bone_world(arms[i][2])*palm_offsets[i]
		previous_elbows_local[i]=actor.to_local(bone_world(chain[1]).origin)
		last_hand_basis[i]=bone_world(chain[2]).basis.orthonormalized()
		previous_palms_local[i] = to_local(palm_world[i])
	# Gameplay contact follows the visible skinned palm, rather than the hidden target.
	actor.hand_world = palm_world[1 if actor.dribble_hand>0 else 0]
	update_gaze(actor,delta)
	final_poses.clear()
	for index in range(skeleton.get_bone_count()): final_poses.append(skeleton.get_bone_pose(index))
	initialized = true
	pelvis_world_height=bone_world(pelvis).origin.y
	last_root = global_position

