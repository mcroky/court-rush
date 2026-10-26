class_name StreetPlayer
extends Node3D

const VISUAL_SCALE = .82
const THIGH_LENGTH = .51
const SHIN_LENGTH = .49
const UPPER_ARM_LENGTH = .42
const FOREARM_LENGTH = .40
const ANKLE_OFFSET = Vector3(0, .15, -.03)
const CrossClip = preload("res://scripts/crossover_clip.gd")
const RunClip = preload("res://scripts/run_clip.gd")
const RigVisual = preload("res://scripts/rigged_visual.gd")
const HeldBall=preload("res://scripts/held_ball.gd")
var held=HeldBall.new()
const DRIBBLE_FLOOR = CourtArt.BALL_RADIUS+.003
const DRIBBLE_PALM = CourtArt.BALL_RADIUS+.015
var use_skinned = true
var skinned: Node3D
const CROSS_TIME = .38
var court_role = "guard"
var growth: Dictionary={}
var height_ratio=1.0
var appearance: Dictionary={}
func apply_appearance(ids: Dictionary) -> void:
	appearance=CourtWardrobe.appearance(ids)
	if skinned!=null:CourtWardrobe.apply(skinned.human_mesh,appearance)
var transfer_target = Vector3.ZERO
var transfer_from = Vector3.ZERO
var transfer_caught = false

func transfer_pose(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	if action == "receive":
		var center = transfer_target
		if transfer_caught:
			center = center.lerp(global_position+global_basis*Vector3(0,1.20*height_ratio,.28),smoothstep(0,.24,action_time))
		return center+global_basis.x*side*.12
	var pocket = global_position+global_basis*Vector3(0,1.25*height_ratio,.28)
	var center = transfer_from.lerp(pocket,smoothstep(0,.11,action_time))
	center += global_basis.z*.32*smoothstep(.10,.23,action_time)
	return center+global_basis.x*side*.12

func apply_athlete(data: Dictionary) -> void:
	growth=data.duplicate(true)
	if data.get("appearance",null) is Dictionary:apply_appearance(data.appearance)
	if not data.is_empty():court_role=str(data.get("role","guard")) if BasketballRules.ROLE_PROFILES.has(str(data.get("role","guard"))) else "guard"
	height_ratio=1.0
	if skinned!=null:
		if not data.is_empty():height_ratio=clampf(float(data.get("height",185))/100.0/(skinned.human_mesh.mesh.get_aabb().size.y*skinned.SCALE),.85,1.15)
		skinned.render_scale=skinned.SCALE*height_ratio
		skinned.model.scale=Vector3.ONE*skinned.render_scale
		skinned.reset_contacts()
	if body!=null:body.scale=Vector3.ONE*VISUAL_SCALE*height_ratio

func skill_rank(key: String) -> int:
	var skills=growth.get("skills",{})
	return clampi(int(skills.get(key,0)),0,5) if skills is Dictionary else 0

func athletic_profile() -> Dictionary:
	var profile=BasketballRules.role_profile(court_role).duplicate()
	if growth.is_empty():return profile
	var training=growth.get("training",{})
	if not training is Dictionary:training={}
	profile.speed+=clampf(float(training.get("speed",0)),0,20)*.018
	profile.rebound_jump+=clampf(float(training.get("rebound",0)),0,20)*.003+skill_rank("rebound")*.012
	profile.box_strength+=clampf(float(training.get("defense",0)),0,20)*.008
	return profile

func guard_contact_extra(opponent) -> float:
	if not defending or boxing_out or chase_recovery or action!="idle" or jump>.05 or not opponent.has_ball:return 0.0
	return BasketballRules.guard_contact_extra(position,opponent.position,rotation.y,defense_weight)

func defense_jump_peak() -> float:
	return athletic_profile().rebound_jump if action == "rebound" else .62

var body: Node3D
var upper: Node3D
var head: Node3D
var arms: Array = []
var legs: Array = []
var shorts: Array = []
var hands: Array = []
var shoes: Array = []
var cuffs: Array = []
var elbows: Array = []
var shoulder_caps: Array = []
var thumbs: Array = []
var shadow: MeshInstance3D
var marker: Node3D
var hand_world = Vector3.ZERO
var previous_hand_world = Vector3.ZERO
var previous_rebound_anchor = Vector3.ZERO
var motion = Vector2.ZERO
var facing: float = PI
var stride: float = 0
var dribble_phase: float = 0
var dribble_hand: float = 1
var ball_side: float = 1
var jump: float = 0
var action: String = "idle"
var action_time: float = 0
var has_ball: bool = false
var dribble_ended: bool = false
var is_opponent: bool = false
var defending = false
var boxing_out = false
var defense_weight = 0.0
var boxout_weight = 0.0
var contact_pressure = 0.0
var pressure_weight = 0.0
var contact_direction = Vector3.ZERO
var watch_direction = Vector3.ZERO
var contesting_boxout = false
var contest_weight = 0.0

func stance_width() -> float:
	return .20 + defense_weight*.075 + boxout_weight*.035

func stance_rest(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var rest = global_position + global_basis.x*side*stance_width()*VISUAL_SCALE
	if restart_left > 0: rest = global_position+Basis(Vector3.UP,restart_placement_yaw()).x*side*stance_width()*VISUAL_SCALE
	rest += global_basis.z*side*.075*boxout_weight*VISUAL_SCALE
	rest.y = .105
	return rest

func reset_stance() -> void:
	held.reset()
	if skinned != null: skinned.reset_contacts()
	shot_recovery_left=0.0
	shot_exit_intent=Vector2.ZERO
	defending = false
	boxing_out = false
	defense_weight = 0
	boxout_weight = 0
	contact_pressure = 0
	pressure_weight = 0
	contact_direction = Vector3.ZERO
	watch_direction = Vector3.ZERO
	contesting_boxout = false
	contest_weight = 0
	guard_plant_time = 0
	guard_travel_direction = Vector3.ZERO
	defense_target_valid = false
	defense_caught = false
	block_contact = false
	rebound_release_left = 0
	landing_recovery_left = 0
	landing_support_drop = 0
	landing_pose_left = 0
	landing_push_left = 0
	landing_push_pitch = [0.0,0.0]
	run_entry_left = 0
	run_swing_weight = 0
	run_twist = 0
	cut_twist = 0
	redirect_left = 0
	redirect_angle = 0
	last_move_input = Vector2.ZERO
	brake_state = ""
	brake_weight = 0
	chase_recovery = false
	chase_recovery_time = 0
	restart_left = 0
	brake_balance_offset = Vector3.ZERO
	steal_valid = false
	steal_success = false
	cross_valid = false
	cross_exit_left = 0
	cross_drive_left = 0
	cross_received = false
	gather_ball_valid=false
	finish_ball_valid=false
var skin: String = "c88e66"
var finish_kind = "shot"
var approach_velocity = Vector2.ZERO
var previous_position = Vector3.ZERO
var feet_world: Array = []
var swing_from: Array = []
var swing_to: Array = []
var swinging: Array = [false, false]
var gait_weight = 0.0
var last_visual_velocity = Vector3.ZERO
var elbow_pose: Array = [Vector3.ZERO, Vector3.ZERO]
var elbow_pole_pose: Array = [Vector3.ZERO, Vector3.ZERO]
var pose_ready = false
var cross_valid = false
var cross_wait = 0.0
var cross_from = 1.0
var cross_to = -1.0
var cross_start_phase = 0.0
var cross_rate = 10.0
var cross_yaw = 0.0
var cross_start_ball = Vector3.ZERO
var cross_start_hands: Array = []
var cross_start_palms: Array = []
var cross_received = false
var cross_exit_left = 0.0
const CROSS_DRIVE_TIME=.28
var cross_drive_left=0.0
var cross_exit_ball = Vector3.ZERO
var cross_exit_hands: Array = []
var cross_exit_palms: Array = []
var gait_length = 2.15
var swing_progress: Array = [1.0, 1.0]
var swing_duration: Array = [.22, .22]
var previous_cycle: Array = [0.0, .5]
var feet_yaw: Array = [0.0, 0.0]
var joint_hips: Array = [Vector3.ZERO, Vector3.ZERO]
var joint_knees: Array = [Vector3.ZERO, Vector3.ZERO]
var joint_ankles: Array = [Vector3.ZERO, Vector3.ZERO]
var next_step = 0
var step_serial = 0
var last_step = -1
var guard_plant_time = 0.0
var guard_travel_direction = Vector3.ZERO
var turn_origin = 0.0
var turn_sign = 1.0
var finish_running = false
var gather_step_start = 0
var shot_gather_turn = false
var shot_gather_yaw = 0.0
var shot_exit_intent = Vector2.ZERO
var shot_recovery_left=0.0

func shot_aim_yaw() -> float:
	return rotation.y+clampf(angle_difference(rotation.y,facing),-.32,.32)*smoothstep(.08,.22,action_time) if action=="shot" else rotation.y

func finish_shot() -> void:
	landing_recovery_left=LANDING_RECOVERY_TIME
	landing_pose_left=.32
	landing_from_height=body.position.y
	landing_from_velocity=body_vertical_velocity
	landing_from_offset=body.position
	landing_from_upper=upper.rotation
	var intent=shot_exit_intent if shot_exit_intent.length()>.1 else motion
	landing_push_left=.52 if intent.length()>.1 else 0.0
	shot_recovery_left=.52 if intent.length()>.1 else .24
	landing_push_serial=step_serial
	landing_push_support=1 if dribble_hand>0 else 0
	landing_push_pitch=[0.0,0.0]
	run_entry_left=1.1 if intent.length()>.1 else 0.0
	run_entry_serial=step_serial
	run_swing_weight=0
	for i in 2:
		var offset=skinned.toe_world[i]-shoes[i].to_global(LAYUP_TOE) if skinned!=null and skinned.initialized else Vector3.ZERO
		feet_world[i]=shoes[i].global_position+offset
		feet_world[i].y=.105
		feet_yaw[i]=rotation.y
	swinging=[false,false]
	swing_progress=[1.0,1.0]
	next_step=1-landing_push_support
	stride=float(next_step)*PI
	motion=intent*.18
	if not has_ball:dribble_ended=false
	action="idle"
	action_time=0
	jump=0
	shot_exit_intent=Vector2.ZERO
var gather_ball_valid=false
var gather_ball_from=Vector3.ZERO
var finish_ball_valid=false
var finish_ball_from=Vector3.ZERO
var finish_rim_world = Vector3.ZERO
var finish_target_valid = false
var air_start = Vector3.ZERO
var air_release = Vector3.ZERO
var air_end = Vector3.ZERO
var air_release_time = .32
const LAYUP_PLANT_TIME = .12
const LAYUP_DURATION = .82
const LAYUP_JUMP_HEIGHT = .78
const LAYUP_TOE = Vector3(0, 0, .19)
const SHOT_PLANT_TIME = .09
const SHOT_LAND_TIME = .72
const SHOT_JUMP_HEIGHT = .62
var layup_plant_index = 0
var layup_plant_anchor = Vector3.ZERO
var layup_start_feet: Array = []
var layup_load = .18
var layup_plant_yaw = 0.0
var layup_entry_velocity = Vector3.ZERO
const DEFENSE_PLANT_TIME = .10
var defense_target_valid = false
var defense_target = Vector3.ZERO
var defense_start = Vector3.ZERO
var defense_end = Vector3.ZERO
var defense_start_feet: Array = []
var defense_start_hands: Array = []
var defense_load = .15
var defense_yaw = 0.0
var defense_landing_yaw = 0.0
var defense_caught = false
var defense_catch_time = 0.0
var defense_catch_hands: Array = []
var defense_catch_velocity = Vector3.ZERO
var defense_ball_offset = Vector3.ZERO
var block_contact = false
var block_contact_time = 0.0
var block_contact_hand = Vector3.ZERO
var block_contact_velocity = Vector3.ZERO
var block_contact_stroke = Vector3.ZERO
var block_contact_upper = Vector3.ZERO
var pose_delta = 1.0/60
var defense_land_first = 0
var rebound_release_left = 0.0
var rebound_release_from = Vector3.ZERO
const LANDING_RECOVERY_TIME = .24
var landing_recovery_left = 0.0
var landing_from_height = 0.0
var landing_from_velocity = 0.0
var body_vertical_velocity = 0.0
var landing_from_offset = Vector3.ZERO
var landing_from_upper = Vector3.ZERO
var landing_support_drop = 0.0
var landing_pose_left = 0.0
var landing_push_left = 0.0
var landing_push_serial = 0
var landing_push_support = 0
var landing_push_pitch: Array = [0.0,0.0]
var run_entry_left = 0.0
var run_entry_serial = 0
var run_swing_weight = 0.0
var run_twist = 0.0
var cut_twist = 0.0
var redirect_left = 0.0
var redirect_angle = 0.0
var last_move_input = Vector2.ZERO
var redirect_support = 0
var brake_state = ""
var brake_time = 0.0
var brake_foot = 0
var brake_direction = Vector3.ZERO
var brake_yaw = 0.0
var brake_weight = 0.0
var restart_left = 0.0
var restart_serial = 0
var restart_direction = Vector3.ZERO
var brake_balance_foot = 0
var brake_balance_offset = Vector3.ZERO
var chase_recovery = false
var chase_recovery_time = 0.0
var chase_turn_step = false

func prepare_chase_recovery(false_velocity: Vector2) -> void:
	if feet_world.size() != 2 or action != "idle" or jump > .05 or chase_recovery: return
	if skinned != null: skinned.sync_cut_contacts(self)
	chase_recovery = true
	chase_recovery_time = 0
	chase_turn_step = false
	defending = false
	brake_state = "plant"
	brake_time = 0
	brake_yaw = rotation.y
	brake_direction = Vector3(false_velocity.x,0,false_velocity.y).normalized()
	motion = false_velocity
	brake_foot = last_step if swinging[0] or swinging[1] else (1 if false_velocity.dot(Vector2(global_basis.x.x,global_basis.x.z))>0 else 0)
	brake_balance_foot = brake_foot
	restart_left = 0
	if not swinging[0] and not swinging[1]:
		begin_step(brake_foot,stance_rest(brake_foot),Vector3(false_velocity.x,0,false_velocity.y)*.45,.12)
	swing_duration[brake_foot] = minf(swing_duration[brake_foot],.10/maxf(.05,1-swing_progress[brake_foot]))

func update_chase_turn(delta: float) -> void:
	# Open the free foot while the loaded forefoot remains the pivot.
	var support = brake_foot
	var old_yaw: float = feet_yaw[support]
	feet_yaw[support] += clampf(angle_difference(old_yaw,rotation.y),-delta*4,delta*4)
	feet_world[support] += (Basis(Vector3.UP,old_yaw)*LAYUP_TOE-Basis(Vector3.UP,feet_yaw[support])*LAYUP_TOE)*VISUAL_SCALE
	var index = 1-support
	if not chase_turn_step:
		var target = global_position+Basis(Vector3.UP,facing).x*(.20 if index == 1 else -.20)*VISUAL_SCALE
		target.y = .105
		begin_step(index,target,Vector3.ZERO,.18)
		chase_turn_step = true
	if swinging[index]:
		swing_progress[index] = minf(1,swing_progress[index]+delta/swing_duration[index])
		var t: float = swing_progress[index]
		feet_world[index] = swing_from[index].lerp(swing_to[index],smoothstep(0,1,t))
		feet_world[index].y = .105+sin(t*PI)*.055
		feet_yaw[index] = lerp_angle(feet_yaw[index],facing,1-exp(-delta*16))
		stride = (float(index)+t)*PI
		if t>=1:
			feet_world[index] = swing_to[index]
			swinging[index] = false

const STEAL_DURATION = .60
var steal_valid = false
var steal_success = false
var steal_resolved = false
var steal_eligible = false
var steal_target = Vector3.ZERO
var steal_start = Vector3.ZERO
var steal_end = Vector3.ZERO
var steal_hand = 0
var steal_load = .16
var steal_contact_time = 0.0
var steal_contact_hand = Vector3.ZERO
var steal_ball_offset = Vector3.ZERO

func stealing() -> bool:
	return action == "steal" and steal_valid

func prepare_steal(target: Vector3,opponent_position: Vector3,eligible: bool) -> void:
	action = "steal"
	action_time = 0
	steal_valid = true
	steal_success = false
	steal_resolved = false
	steal_eligible = eligible
	steal_target = target
	steal_start = position
	var forward = Vector3(sin(facing),0,cos(facing))
	var travel = clampf(position.distance_to(opponent_position)-.78,0,.38)
	steal_end = position+forward*travel
	steal_load = clampf(-body.position.y,.035,.28)
	steal_hand = 1 if body.to_local(target).x > 0 else 0
	dribble_hand = 1 if steal_hand == 1 else -1
	if not swinging[0] and not swinging[1]: next_step = steal_hand
	defending = false
	boxing_out = false
	brake_state = ""
	brake_weight = 0
	restart_left = 0
	run_entry_left = 0
	landing_pose_left = 0
	landing_recovery_left = 0
	landing_push_left = 0
	landing_push_pitch = [0.0,0.0]

func steal_reach() -> float:
	return smoothstep(.02,.19,action_time)*(1-smoothstep(.27,STEAL_DURATION,action_time))

func steal_root_target() -> Vector3:
	return steal_start.lerp(steal_end,smoothstep(.025,.23,action_time))

func steal_hand_target(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var rest = Vector3(side*.37,1.30,.19)
	if index != steal_hand: return rest.lerp(Vector3(side*.48,1.43,-.15),steal_reach())
	if steal_success:
		var captured = body.to_local(steal_contact_hand)
		return captured.lerp(Vector3(side*.46,1.31,.30),smoothstep(0,.20,action_time-steal_contact_time))
	var target = body.to_local(steal_target)
	# A low bounce is below the old mannequin's waist. Follow the real ball;
	# shoulder/torso reach and fixed limb lengths decide whether it is reachable.
	target.y = maxf(.12,target.y)
	target.z = maxf(.18,target.z)
	return rest.lerp(target,steal_reach())

func receive_steal(ball_position: Vector3) -> void:
	steal_success = true
	steal_contact_time = action_time
	steal_contact_hand = hand_world
	steal_ball_offset = ball_position-hand_world

func restart_phase() -> float:
	return maxf(0,step_serial-restart_serial-1+(swing_progress[last_step] if last_step >= 0 else 0.0))

func restart_placement_yaw() -> float:
	var target = atan2(restart_direction.x,restart_direction.z)
	return lerp_angle(brake_yaw,target,smoothstep(0,2,restart_phase()))

func restart_speed_scale() -> float:
	var phase = restart_phase()
	if phase < 1: return lerpf(.20,.50,smoothstep(0,1,phase))
	if phase < 2: return lerpf(.50,.80,smoothstep(1,2,phase))
	return lerpf(.80,1,smoothstep(2,3,phase))

func steer_motion(desired: Vector2, acceleration: float, delta: float) -> void:
	# Stops and cuts share an actual receiving contact, compression and push.
	# Skills, held balls, air actions and defensive shuffles retain their controls.
	if chase_recovery: chase_recovery_time += delta
	var available = locomotion_pose() and jump < .05 and not defending and not boxing_out and not dribble_ended and landing_push_left <= 0 and feet_world.size() == 2
	if not available:
		chase_recovery = false
		brake_state = ""
		restart_left = 0
		motion = motion.move_toward(desired,acceleration*delta)
		last_move_input=desired
		return
	if not chase_recovery and desired.length()>.1:
		# An input cut is a moving support exchange, not a full stop and a
		# three-stride recovery. Only a stolen balance keeps the recovery gate.
		var input_turn=last_move_input.length()>.1 and last_move_input.normalized().dot(desired.normalized())<cos(deg_to_rad(25))
		if input_turn and motion.length()>1.0:
			redirect_left=.22
			redirect_angle=angle_difference(rotation.y,atan2(desired.x,desired.y))
			redirect_support=1-last_step if last_step>=0 and swinging[last_step] else next_step
			if skinned!=null:skinned.sync_cut_contacts(self)
			var receiver=1-redirect_support
			if not swinging[0] and not swinging[1]:begin_step(receiver,stance_rest(receiver),Vector3(desired.x,0,desired.y),.11)
			elif swinging[receiver]:swing_duration[receiver]=minf(swing_duration[receiver],.09/maxf(.05,1-swing_progress[receiver]))
		brake_state=""
		restart_left=0
		motion=motion.move_toward(desired,maxf(acceleration,42.0) * delta if redirect_left>0 else acceleration*delta)
		last_move_input=desired
		return
	last_move_input=desired
	if restart_left > 0 and desired.length() > .1:
		restart_direction = restart_direction.lerp(Vector3(desired.x,0,desired.y).normalized(),1-exp(-delta*14)).normalized()
	var turning = desired.length() > .1 and motion.normalized().dot(desired.normalized()) < cos(deg_to_rad(25))
	if brake_state == "" and motion.length() > 2.2 and (desired.length() < .1 or turning):
		if skinned != null: skinned.sync_cut_contacts(self)
		brake_state = "plant"
		brake_time = 0
		brake_direction = Vector3(motion.x,0,motion.y).normalized()
		brake_yaw = rotation.y
		brake_foot = last_step if swinging[0] or swinging[1] else next_step
		brake_balance_foot = brake_foot
		restart_left = 0
		if not swinging[0] and not swinging[1]:
			begin_step(brake_foot,stance_rest(brake_foot),Vector3(motion.x,0,motion.y)*.35,.075)
		# Shorten the remaining receiving step, preserving its current phase/position.
		swing_duration[brake_foot] = minf(swing_duration[brake_foot],.070/maxf(.05,1-swing_progress[brake_foot]))
	if brake_state == "":
		if restart_left > 0: desired *= restart_speed_scale()
		motion = motion.move_toward(desired,acceleration*delta)
		return
	brake_time += delta
	if brake_state == "plant":
		motion = motion.move_toward(Vector2.ZERO,12*delta)
		if not swinging[brake_foot]:
			brake_state = "load"
			brake_time = 0
	elif brake_state == "load":
		motion = motion.move_toward(Vector2.ZERO,40*delta)
		if brake_time >= (.10 if chase_recovery else .065) and motion.length() < .35:
			brake_state = "settle"
			brake_time = 0
	elif brake_state == "settle":
		motion = motion.move_toward(Vector2.ZERO,40*delta)
		var ready_to_chase = not chase_recovery or (brake_time >= .18 and chase_turn_step and not swinging[1-brake_foot] and absf(angle_difference(rotation.y,facing))<.35)
		if desired.length() > .1 and ready_to_chase:
			brake_state = "push"
			brake_time = 0
			next_step = 1-brake_foot
			run_entry_serial = step_serial
			run_entry_left = .85
			restart_left = .90
			restart_serial = step_serial
			restart_direction = Vector3(desired.x,0,desired.y).normalized()
			# A reversal needs its short receiving step down sooner; holding it
			# airborne as long as a wide cut exhausts the old support's reach.
			var cut_angle = absf(angle_difference(brake_yaw,atan2(desired.x,desired.y)))
			var receive_time = lerpf(.17,.14,smoothstep(PI*.5,PI,cut_angle))
			if skinned != null: receive_time = lerpf(.17,.10,smoothstep(PI*.5,PI,cut_angle))
			begin_step(next_step,stance_rest(next_step),restart_direction*.95,receive_time)
		elif desired.length() <= .1 and brake_time >= .14: brake_state = ""
	elif brake_state == "push":
		motion = motion.move_toward(desired*restart_speed_scale(),22*delta)
		if not swinging[1-brake_foot]:
			brake_state = "receive"
			brake_time = 0
			brake_balance_foot = 1-brake_foot
		elif brake_time >= .30: brake_state = ""
	elif brake_state == "receive":
		motion = motion.move_toward(desired*restart_speed_scale(),22*delta)
		if not swinging[brake_foot] or brake_time >= .26: brake_state = ""

func run_entry_phase() -> float:
	var steps = step_serial-run_entry_serial
	return maxf(0,steps-1+(swing_progress[last_step] if last_step >= 0 else 0.0))

func entry_placement(rest: Vector3, target: Vector3) -> Vector3:
	if run_entry_left <= 0: return target
	var reach = lerpf(.28,.64,smoothstep(0,4,run_entry_phase()))
	if restart_left > 0:
		var phase = restart_phase()
		reach = lerpf(.24,.36,smoothstep(0,1,phase)) if phase < 1 else lerpf(.36,.70,smoothstep(1,3,phase))
	var lead = target-rest
	lead.y = 0
	return rest+lead.limit_length(reach)

func landing_push_phase() -> float:
	var steps = step_serial-landing_push_serial
	if steps <= 0: return 0.0
	return minf(2,steps-1+(swing_progress[last_step] if last_step >= 0 else 0.0))

func landing_shoe_offset(index: int) -> Vector3:
	# Keep the forefoot planted as the heel rises. feet_world remains the flat
	# contact reference, so the first swing inherits the same contact without a jump.
	var pitch: float = landing_push_pitch[index]
	return Basis(Vector3.UP,feet_yaw[index])*(LAYUP_TOE-Basis(Vector3.RIGHT,pitch)*LAYUP_TOE)*VISUAL_SCALE

func update_landing_push(delta: float) -> void:
	landing_push_left = maxf(0,landing_push_left-delta) if action == "idle" else 0.0
	var phase = landing_push_phase()
	for i in range(2):
		var target = 0.0
		if locomotion_pose() and not dribble_ended and jump < .05 and defense_weight < .1 and swinging[i] and landing_push_left <= 0 and restart_left <= 0 and brake_state == "":
			# Release the previous toe push, clear the floor, then flatten for
			# receiving contact. Do not inherit the leaning torso's shoe angle.
			target = -.10*run_swing_weight*sin(swing_progress[i]*PI)
		if locomotion_pose() and not dribble_ended and jump < .05 and defense_weight < .1 and not swinging[i] and swinging[1-i] and landing_push_left <= 0 and restart_left <= 0 and brake_state == "":
			target = .25*run_swing_weight*smoothstep(.20,.90,swing_progress[1-i])
		if landing_push_left > 0 and motion.length() > .1 and i == landing_push_support:
			if phase <= 1: target = .32*smoothstep(.12,.90,phase)
			else: target = .32*(1-smoothstep(1,1.40,phase))
		if brake_state == "push" and i == brake_foot and not swinging[i]:
			target = .30*smoothstep(.10,.92,restart_phase())
		if brake_state == "receive" and i == 1-brake_foot and not swinging[i]:
			target = .24*smoothstep(1.05,1.90,restart_phase())
		if restart_left > 0 and not swinging[i] and swinging[1-i]:
			# Each new support receives, loads, then rolls into the next stride.
			target = .30*smoothstep(.10,.92,fposmod(restart_phase(),1))
		landing_push_pitch[i] = move_toward(landing_push_pitch[i],target,delta*5.5)
	if phase >= 2: landing_push_left = 0

func landing_speed_scale() -> float:
	if landing_push_left > 0:
		# Acceleration follows the supporting leg's push and the next foot's catch,
		# rather than reaching full running speed on an unrelated countdown.
		var phase = landing_push_phase()
		return lerpf(.18,.43,smoothstep(0,1,phase)) if phase < 1 else lerpf(.43,1.0,smoothstep(1,2,phase))
	return lerpf(.25,1.0,smoothstep(0,.20,LANDING_RECOVERY_TIME-landing_recovery_left)) if landing_recovery_left > 0 else 1.0

func finish_defense() -> void:
	# Continue from the rendered compression, with its velocity and real contacts.
	# The loaded first foot supports the body while the other opens the first step.
	landing_recovery_left = LANDING_RECOVERY_TIME
	landing_pose_left = .40
	landing_from_height = body.position.y
	landing_from_velocity = body_vertical_velocity
	landing_from_offset = body.position
	landing_from_upper = upper.rotation
	landing_push_left = .52 if motion.length() > .1 else 0.0
	landing_push_serial = step_serial
	landing_push_support = defense_land_first
	landing_push_pitch = [0.0,0.0]
	run_entry_left = 1.1 if motion.length() > .1 else 0.0
	run_entry_serial = step_serial
	run_swing_weight = 0
	for i in range(2):
		feet_world[i] = shoes[i].global_position
		feet_world[i].y = .105
		feet_yaw[i] = defense_landing_yaw
	swinging = [false,false]
	swing_progress = [1.0,1.0]
	next_step = 1-defense_land_first
	stride = float(next_step)*PI
	guard_plant_time = 0
	last_visual_velocity = Vector3.ZERO
	if action == "rebound" and defense_caught:
		rebound_release_from = ball_anchor(0)
		rebound_release_left = .20
		dribble_phase = 0
	action = "idle"
	jump = 0
	defense_target_valid = false

func defensive_jump() -> bool:
	return action in ["rebound", "block"] and defense_target_valid

func defense_land_time() -> float:
	return .76 if action == "rebound" else .68

func defense_duration() -> float:
	return defense_land_time()+.26

func defense_touch_time(index: int) -> float:
	return defense_land_time()+(0.0 if index == defense_land_first else .045)

func defense_landing_load() -> float:
	var t = action_time-defense_land_time()
	return smoothstep(0,.095,t)*(1-smoothstep(.095,.26,t))

func defense_shoe_pitch(index: int) -> float:
	if action_time <= DEFENSE_PLANT_TIME:
		return .28*smoothstep(.035,DEFENSE_PLANT_TIME,action_time)
	var release = 1-smoothstep(DEFENSE_PLANT_TIME,DEFENSE_PLANT_TIME+.10,action_time)
	var touchdown = .22*(1-smoothstep(defense_touch_time(index),defense_touch_time(index)+.055,action_time))
	return maxf(.28*release,touchdown)

func defense_height() -> float:
	var t = clampf((action_time-DEFENSE_PLANT_TIME)/(defense_land_time()-DEFENSE_PLANT_TIME),0,1)
	return 4*defense_jump_peak()*t*(1-t)

func prepare_defense(kind: String, target: Vector3) -> void:
	chase_recovery = false
	restart_left = 0
	brake_state = ""
	brake_weight = 0
	landing_recovery_left = 0
	landing_pose_left = 0
	landing_support_drop = 0
	landing_push_left = 0
	landing_push_pitch = [0.0,0.0]
	run_entry_left = 0
	action = kind
	action_time = 0
	jump = 0
	defense_target_valid = true
	defense_target = target
	defense_start = global_position
	var travel = target-global_position
	travel.y = 0
	var reach_travel: float = athletic_profile().rebound_travel if kind == "rebound" else .34
	defense_end = defense_start+travel.limit_length(reach_travel)+Vector3(motion.x,0,motion.y).limit_length(2)*.065
	defense_start_feet = [shoes[0].global_position,shoes[1].global_position]
	defense_start_hands = [palm_position(0),palm_position(1)]
	defense_load = clampf(-body.position.y,.045,.34)
	defense_yaw = rotation.y
	defense_landing_yaw = facing
	dribble_hand = 1.0 if (target-global_position).dot(global_basis.x) >= 0 else -1.0
	defense_caught = false
	block_contact = false
	defense_catch_hands.clear()
	defense_land_first = 0 if dribble_hand > 0 else 1
	defense_ball_offset = Vector3.ZERO
	defending = false
	boxing_out = false
	swinging = [false,false]

func defense_position() -> Vector3:
	return defense_start.lerp(defense_end,smoothstep(DEFENSE_PLANT_TIME,defense_land_time(),action_time))

func defense_body_height() -> float:
	if action_time < DEFENSE_PLANT_TIME:
		# Preserve the incoming crouch, load, then extend into the jump's velocity.
		if action_time < .035: return -defense_load-.035*smoothstep(0,.035,action_time)
		var t = (action_time-.035)/(DEFENSE_PLANT_TIME-.035)
		var push = 4*defense_jump_peak()/(defense_land_time()-DEFENSE_PLANT_TIME)
		return (2*t*t*t-3*t*t+1)*(-defense_load-.035)+(-2*t*t*t+3*t*t)*-.045+(t*t*t-t*t)*.065*push
	var land = defense_land_time()
	if action_time <= land: return jump-.045
	var elapsed = action_time-land
	if elapsed < .095:
		# Feet touch first. Continue the downward velocity into bent knees.
		var t = elapsed/.095
		var incoming = -4*defense_jump_peak()/(land-DEFENSE_PLANT_TIME)
		return (2*t*t*t-3*t*t+1)*-.045+(t*t*t-2*t*t+t)*.095*incoming+(-2*t*t*t+3*t*t)*-.22
	return lerpf(-.22,-.08 if defense_caught else -.035,smoothstep(.095,.26,elapsed))

func defense_landing_contact(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var yaw = Basis(Vector3.UP,defense_landing_yaw)
	var landing = defense_end+yaw.x*side*.23*VISUAL_SCALE
	landing += yaw.z*(.055 if index == defense_land_first else -.055)
	landing.y = .105
	return landing

func defense_foot(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var contact: Vector3 = defense_start_feet[index]
	contact.y = lerpf(contact.y,.105,smoothstep(0,.04,action_time))
	var pitch = defense_shoe_pitch(index)
	var pivot = LAYUP_TOE-Basis(Vector3.RIGHT,pitch)*LAYUP_TOE
	contact += Basis(Vector3.UP,defense_yaw)*pivot*VISUAL_SCALE
	var foot = body.to_local(contact)
	var tuck = sin(clampf((action_time-DEFENSE_PLANT_TIME)/(defense_land_time()-DEFENSE_PLANT_TIME),0,1)*PI)
	var tucked = Vector3(side*.21,.10+tuck*(.14 if index == defense_land_first else .22),-.13-tuck*.16)
	foot = foot.lerp(tucked,smoothstep(DEFENSE_PLANT_TIME,DEFENSE_PLANT_TIME+.13,action_time))
	var landing = defense_landing_contact(index)+Basis(Vector3.UP,defense_landing_yaw)*pivot*VISUAL_SCALE
	var result = body.to_global(foot.lerp(body.to_local(landing),smoothstep(defense_touch_time(index)-.14,defense_touch_time(index),action_time)))
	if action_time > DEFENSE_PLANT_TIME:
		var clearance = .035*(1-smoothstep(defense_touch_time(index)-.070,defense_touch_time(index),action_time))
		result.y = maxf(result.y,.105+pivot.y*VISUAL_SCALE+clearance)
	return body.to_local(result)

func rebound_tuck_phase() -> float:
	if not defense_caught: return 0.0
	var apex = (DEFENSE_PLANT_TIME+defense_land_time())*.5
	var begin = maxf(defense_catch_time+.11,apex)
	var end = minf(maxf(begin+.18,defense_land_time()-.07),defense_duration()-.06)
	return smoothstep(begin,end,action_time)

func block_upper_pose() -> Vector3:
	if block_contact:
		var elapsed = action_time-block_contact_time
		var finish = Vector3(.23,dribble_hand*.38,dribble_hand*.09)
		return block_contact_upper.lerp(finish,smoothstep(0,.10,elapsed))*(1-smoothstep(.10,.36,elapsed))
	var windup = Vector3(-.13,-dribble_hand*.25,-dribble_hand*.045)*smoothstep(.025,.13,action_time)
	return windup.lerp(Vector3(.23,dribble_hand*.32,dribble_hand*.075),smoothstep(.15,.28,action_time))*(1-smoothstep(.38,.60,action_time))

func defense_hand(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var lift = smoothstep(.025,.25,action_time)
	var rest = Vector3(side*.36,1.27,.20)
	if action == "rebound":
		var spread = lerpf(.29,.17,smoothstep(.08,.26,action_time))
		var target = body.to_local(defense_target)+Vector3(side*spread,-.015,-.025)
		# Keep the catch in front of the face rather than reaching through the torso.
		target.z = maxf(.16,target.z)
		if defense_caught:
			var elapsed = action_time-defense_catch_time
			# Keep the received world contact while the rising torso folds the elbows.
			var received: Vector3 = defense_catch_hands[index]+defense_catch_velocity*.035*(1-exp(-elapsed/.035))
			var give = body.to_local(received)
			# Close around the ball, show possession above the forehead, then tuck.
			var secured = give.lerp(upper.transform*Vector3(side*.24,2.53,.32),smoothstep(.035,.13,elapsed))
			return secured.lerp(upper.transform*Vector3(side*.24,1.74,.43),rebound_tuck_phase())
		else:
			target = target.lerp(rest,smoothstep(defense_land_time()-.10,defense_duration(),action_time))
		return rest.lerp(target,lift)
	if side != dribble_hand:
		return rest.lerp(Vector3(side*.46,1.58,-.065),lift).lerp(rest,smoothstep(.48,defense_duration(),action_time))
	if block_contact:
		var elapsed = action_time-block_contact_time
		var stroke = block_contact_stroke
		var t = clampf(elapsed/.16,0,1)
		# Preserve the strike velocity at contact instead of restarting from rest.
		var follow = body.to_local(block_contact_hand+stroke*(-2*t*t*t+3*t*t)+block_contact_velocity*.16*(t*t*t-2*t*t+t))
		var folded = Vector3(side*.39,1.75,.40)
		return follow.lerp(folded,smoothstep(.16,.36,elapsed)).lerp(rest,smoothstep(.36,.52,elapsed))
	var strike = smoothstep(.16,.34,action_time)
	var world = defense_target+Vector3.UP*lerpf(.43,-.17,strike)+global_basis.z*lerpf(-.08,.07,strike)
	var start = body.to_local(defense_start_hands[index]) if defense_start_hands.size() == 2 else rest
	var windup = upper.transform*Vector3(side*.26,2.60,-.08)
	var swing = windup.lerp(body.to_local(world),smoothstep(.15,.25,action_time))
	return start.lerp(swing,smoothstep(0,.13,action_time)).lerp(rest,smoothstep(.45,defense_duration(),action_time))

func capture_rebound(ball_position: Vector3,incoming_velocity: Vector3 = Vector3.ZERO) -> void:
	defense_caught = true
	defense_catch_time = action_time
	defense_catch_hands = [palm_position(0),palm_position(1)]
	defense_catch_velocity = incoming_velocity.limit_length(5)
	defense_ball_offset = ball_position-rebound_anchor()

func record_block_contact() -> void:
	block_contact = true
	block_contact_time = action_time
	block_contact_hand = palm_position(1 if dribble_hand > 0 else 0)
	block_contact_velocity = ((hand_world-previous_hand_world)/maxf(pose_delta,.0001)).limit_length(2.4)
	block_contact_upper = upper.rotation
	# The released ball and the palm follow the same outward/downward strike.
	block_contact_stroke = global_basis*Vector3(dribble_hand*.10,-.50,.36)

func palm_position(index: int) -> Vector3:
	return skinned.palm_world[index] if skinned != null and skinned.initialized else hands[index].global_position

func palm_frame(index: int) -> Basis:
	if skinned!=null and skinned.initialized:
		return skinned.bone_world(skinned.arms[index][2]).basis.orthonormalized()*skinned.palm_frames[index]
	return hands[index].global_basis.orthonormalized()

func rebound_anchor() -> Vector3:
	return (palm_position(0)+palm_position(1))*.5+global_basis.z*.045

func gather_velocity() -> Vector2:
	if finish_kind == "shot": return approach_velocity * (1-smoothstep(0,.18,action_time))
	return approach_velocity * (.86 if finish_running and finish_kind == "layup" else .65)

func moving_gather() -> bool:
	return action=="gather" and (finish_running or (finish_kind=="shot" and action_time<.18 and approach_velocity.length()>1.2))

static func shot_height(t: float) -> float:
	var u=clampf((t-SHOT_PLANT_TIME)/(SHOT_LAND_TIME-SHOT_PLANT_TIME),0,1)
	return 4*SHOT_JUMP_HEIGHT*u*(1-u)

static func layup_push_speed() -> float:
	return 4 * LAYUP_JUMP_HEIGHT / (LAYUP_DURATION - LAYUP_PLANT_TIME)

static func layup_height(t: float) -> float:
	var u = clampf((t - LAYUP_PLANT_TIME) / (LAYUP_DURATION - LAYUP_PLANT_TIME), 0, 1)
	return 4 * LAYUP_JUMP_HEIGHT * u * (1-u)

func layup_pelvis_height() -> float:
	if action_time > LAYUP_PLANT_TIME:
		return jump - .15 * smoothstep(.69, LAYUP_DURATION, action_time)
	# Continuous upward velocity from the extending leg into the airborne arc.
	var t = clampf(action_time / LAYUP_PLANT_TIME, 0, 1)
	return (2*t*t*t-3*t*t+1)*-layup_load + (t*t*t-t*t)*LAYUP_PLANT_TIME*layup_push_speed()

func layup_heel_roll() -> float:
	return .60 * smoothstep(.025, LAYUP_PLANT_TIME, action_time) * (1-smoothstep(.16, .28, action_time))

func prepare_layup() -> void:
	layup_plant_index = 0 if dribble_hand > 0 else 1
	# Finish off the foot actually carrying weight, rather than swapping legs in midair.
	if swinging[0] != swinging[1]: layup_plant_index = 1 if swinging[0] else 0
	layup_start_feet = [shoes[0].global_position, shoes[1].global_position]
	var support_offset = layup_start_feet[layup_plant_index] - global_position
	var other_offset = layup_start_feet[1-layup_plant_index] - global_position
	# If the old stance leg is trailing, complete the incoming step before pushing off.
	if Vector2(support_offset.x, support_offset.z).length() > .35 and Vector2(other_offset.x, other_offset.z).length() < Vector2(support_offset.x, support_offset.z).length() - .05:
		layup_plant_index = 1-layup_plant_index
	dribble_hand = 1.0 if layup_plant_index == 0 else -1.0
	layup_plant_anchor = layup_start_feet[layup_plant_index]
	layup_plant_anchor.y = .105
	layup_load = clampf(-body.position.y, .10, .38)
	layup_plant_yaw = feet_yaw[layup_plant_index]
	var entry = gather_velocity()
	layup_entry_velocity = Vector3(entry.x, 0, entry.y)
	swinging = [false, false]

func layup_foot(index: int) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var drive = smoothstep(0, .20, action_time)
	var tuck = Vector3(side * .20, .58, .30) if index != layup_plant_index else Vector3(side * .18, .12, -.34)
	var origin = body.to_local(layup_start_feet[index])
	var foot = origin.lerp(tuck, drive)
	if index == layup_plant_index:
		var contact = layup_start_feet[index].lerp(layup_plant_anchor, smoothstep(0, .04, action_time))
		var pivot_shift = LAYUP_TOE - Basis(Vector3.RIGHT, layup_heel_roll()) * LAYUP_TOE
		contact += Basis(Vector3.UP, layup_plant_yaw) * pivot_shift * VISUAL_SCALE
		foot = body.to_local(contact).lerp(tuck, smoothstep(LAYUP_PLANT_TIME, .20, action_time))
	var landing = air_end + global_basis.x * side * .20 * VISUAL_SCALE
	landing.y = .105
	return foot.lerp(body.to_local(landing), smoothstep(.56, LAYUP_DURATION, action_time))

func finish_position() -> Vector3:
	var release_velocity = (air_end - air_release) / (.82 - air_release_time) * (1.3 if action == "layup" else .7)
	var a = air_start if action_time <= air_release_time else air_release
	var b = air_release if action_time <= air_release_time else air_end
	var duration = air_release_time if action_time <= air_release_time else .82 - air_release_time
	var elapsed = action_time if action_time <= air_release_time else action_time - air_release_time
	var entry_velocity = layup_entry_velocity if action == "layup" else Vector3(approach_velocity.x, 0, approach_velocity.y) * .65
	var first_velocity = entry_velocity if action_time <= air_release_time else release_velocity
	var last_velocity = release_velocity if action_time <= air_release_time else Vector3.ZERO
	var t = clampf(elapsed / duration, 0, 1)
	return (2*t*t*t-3*t*t+1)*a + (t*t*t-2*t*t+t)*duration*first_velocity + (-2*t*t*t+3*t*t)*b + (t*t*t-t*t)*duration*last_velocity

func begin_step(index: int, rest: Vector3, velocity: Vector3, duration: float) -> void:
	# One shared contact scheduler owns both feet, including recovery steps.
	if swinging[0] or swinging[1]: return
	swinging[index] = true
	last_step = index
	step_serial += 1
	next_step = 1 - index
	swing_progress[index] = 0.0
	swing_duration[index] = duration
	swing_from[index] = feet_world[index]
	swing_to[index] = entry_placement(rest,rest + velocity * (duration + lerpf(.085,.035,defense_weight)))
	swing_to[index].y = .105

func start_ground_step(velocity: Vector3) -> void:
	if feet_world.size() != 2: return
	var gathering_steps = moving_gather()
	var moving = velocity.length() >= .15
	if not swinging[0] and not swinging[1] and not (gathering_steps and step_serial >= gather_step_start + 2):
		var side = -1.0 if next_step == 0 else 1.0
		var rest = stance_rest(next_step)
		if moving or feet_world[next_step].distance_to(rest) > lerpf(.07,.025,defense_weight):
			var distance = .28 if last_visual_velocity.length() < .15 else lerpf(.72,.40,defense_weight)
			# In a defensive slide, open with the foot on the movement side.
			var local = velocity.rotated(Vector3.UP,-rotation.y)
			if defense_weight > .5 and last_visual_velocity.length() < .15 and absf(local.x) > .2:
				next_step = 1 if local.x > 0 else 0
				side = -1.0 if next_step == 0 else 1.0
				rest = stance_rest(next_step)
			var duration = clampf(distance / maxf(velocity.length(), .5), .05, .26)
			if locomotion_pose() and defense_weight < .5: duration = maxf(duration,.12)
			if landing_push_left > 0:
				duration = .18 if step_serial == landing_push_serial else .16
			elif landing_recovery_left > 0: duration = .16
			if restart_left > 0 and restart_phase() >= 2: duration = .16
			if stealing(): duration = .16
			begin_step(next_step, rest, velocity, duration)

func update_footwork(delta: float, velocity: Vector3) -> void:
	if defensive_jump(): return
	if action == "layup" and finish_target_valid: return
	var gathering_steps = moving_gather()
	if jump > .05 or (has_ball and dribble_ended and not gathering_steps):
		swinging = [false, false]
		return
	if not has_ball and action == "idle" and defense_weight > .5 and not chase_recovery:
		update_guard_footwork(delta, velocity)
		return
	if brake_state in ["load","settle"]:
		if chase_recovery and brake_state == "settle": update_chase_turn(delta)
		return
	guard_plant_time = 0
	start_ground_step(velocity)
	for index in range(2):
		if not swinging[index]: continue
		var side = -1.0 if index == 0 else 1.0
		var rest = stance_rest(index)
		swing_progress[index] = minf(1, swing_progress[index] + delta / swing_duration[index])
		var t: float = swing_progress[index]
		# Retarget the airborne foot after a cut; stale pre-cut targets cause rubber legs.
		var target = rest + velocity * (swing_duration[index] * (1 - t) + lerpf(.085,.035,defense_weight))
		if restart_left > 0:
			var receiving_step = clampi(step_serial-restart_serial-1,0,2)
			target = rest+restart_direction*(motion.length()*swing_duration[index]*(1-t)+.20+.17*receiving_step)
		if defense_weight > .5:
			# The closing foot stops short of the planted foot during a lateral shuffle.
			var lateral = global_basis.x.normalized()
			var gap = (target-feet_world[1-index]).dot(lateral)
			target += lateral * (minf(0,-.16-gap) if index == 0 else maxf(0,.16-gap))
		target.y = .105
		if brake_state == "plant" and index == brake_foot:
			target = global_position+brake_direction*.19+Basis(Vector3.UP,brake_yaw).x*side*.20*VISUAL_SCALE
			target.y = .105
		target = entry_placement(rest,target)
		# The receiving foot commits before touchdown; it must not chase a root
		# that is still accelerating off the other forefoot.
		var commit_contact = landing_push_left > 0 or (locomotion_pose() and defense_weight < .5)
		if not commit_contact or t < (.85 if brake_state == "plant" else .68):
			swing_to[index] = swing_to[index].lerp(target, 1 - exp(-delta * 24))
		feet_world[index] = swing_from[index].lerp(swing_to[index], smoothstep(0, 1, t))
		var clearance = lerpf(.10 if action in ["cross", "spin", "twostep"] else .14, .035, defense_weight)
		if landing_recovery_left > 0 or landing_push_left > 0: clearance = .065
		if run_entry_left > 0 and defense_weight < .5:
			clearance = lerpf(.065,.14,smoothstep(0,4,run_entry_phase()))
		if brake_state == "plant": clearance = .075
		if stealing(): clearance = .045
		feet_world[index].y = .105 + sin(t * PI) * clearance
		var foot_yaw = restart_placement_yaw() if restart_left > 0 else rotation.y
		feet_yaw[index] = lerp_angle(feet_yaw[index], foot_yaw, 1 - exp(-delta * 16))
		if t >= 1:
			feet_world[index] = swing_to[index]
			swinging[index] = false
		# Upper-body counter-swing follows the actual alternating contact rhythm.
		stride = (float(index) + t) * PI

func update_guard_footwork(delta: float, velocity: Vector3) -> void:
	# Open with the leading foot, plant it, then bring the trailing foot in.
	# Targets stop tracking the root before touchdown; planted feet stay in world space.
	var speed = maxf(velocity.length(),motion.length()*.9)
	var placement_velocity = Vector3(motion.x,0,motion.y) if motion.length() > .15 else velocity
	guard_plant_time = maxf(0,guard_plant_time-delta)
	if not swinging[0] and not swinging[1] and guard_plant_time <= 0:
		var local = placement_velocity.rotated(Vector3.UP,-rotation.y)
		# Only pick the lead side when starting. During a reversal the newly
		# planted foot must support the other foot, not immediately lift again.
		if speed > .15 and absf(local.x) > .2 and guard_travel_direction.length_squared() < .01:
			next_step = 1 if local.x > 0 else 0
		guard_travel_direction = placement_velocity.normalized() if speed > .15 else Vector3.ZERO
		var rest = stance_rest(next_step)
		var recovery = feet_world[next_step].distance_to(rest)
		if speed > .15 or recovery > .10:
			# Give the lead foot time to open and accept weight before the trail
			# follows. Very short 55 ms steps outran the rendered contact transfer.
			begin_step(next_step,rest,placement_velocity,clampf(.32/maxf(speed,.5),.12,.16))
	for i in range(2):
		if not swinging[i]: continue
		swing_progress[i] = minf(1,swing_progress[i]+delta/swing_duration[i])
		var t: float = swing_progress[i]
		if t < .65:
			# Land ahead of the hips far enough to support the next trailing step.
			var target = stance_rest(i)+placement_velocity*(swing_duration[i]*(1-t)+.10)
			var lateral = global_basis.x.normalized()
			var gap = (target-feet_world[1-i]).dot(lateral)
			target += lateral*(minf(0,-.20-gap) if i == 0 else maxf(0,.20-gap))
			target.y = .105
			swing_to[i] = swing_to[i].lerp(target,1-exp(-delta*32))
		feet_world[i] = swing_from[i].lerp(swing_to[i],smoothstep(0,1,t))
		feet_world[i].y = .105+sin(t*PI)*.026
		feet_yaw[i] = lerp_angle(feet_yaw[i],rotation.y,1-exp(-delta*22))
		stride = (float(i)+t)*PI
		if t >= 1:
			feet_world[i] = swing_to[i]
			swinging[i] = false
			guard_plant_time = .018

func movement_step(delta: float) -> Vector3:
	var step = Vector3(motion.x,0,motion.y)*delta
	# A reset/teleport has no usable contacts until animate rebuilds the stance.
	if feet_world.size() != 2 or global_position.distance_to(previous_position) > 1.5: return step
	var run_contacts = locomotion_pose() and not dribble_ended and jump < .05 and defense_weight < .5
	if brake_state == "receive" and not swinging[0] and not swinging[1]:
		# The new foot has already accepted contact. Let the original support
		# follow through now, preserving the first receiving foot in world space.
		begin_step(next_step,stance_rest(next_step),Vector3(motion.x,0,motion.y),.16)
	elif restart_left > 0 and brake_state == "" and not swinging[0] and not swinging[1] and motion.length() > .1:
		begin_step(next_step,stance_rest(next_step),Vector3(motion.x,0,motion.y),.16)
	elif run_contacts and brake_state == "" and landing_recovery_left <= 0 and landing_push_left <= 0:
		# Release the next swing before moving the root. The other contact still
		# constrains travel, including the first normal stride after a cut.
		start_ground_step(Vector3(motion.x,0,motion.y))
	if landing_push_left > 0 and action == "idle" and motion.length() > .1 and not swinging[0] and not swinging[1] and step_serial == landing_push_serial+1:
		# The receiving foot has already landed. Release the old support before
		# moving this tick, avoiding a one-frame two-foot brake between strides.
		begin_step(next_step,stance_rest(next_step),Vector3(motion.x,0,motion.y),.16)
	if use_skinned and run_contacts and brake_state=="" and not chase_recovery and landing_push_left<=0 and landing_recovery_left<=0:
		# Ordinary match travel must not wait for the hidden prototype's longer
		# legs. The visible rig releases and receives contacts at its own reach.
		return step
	if not run_contacts and not stealing() and restart_left <= 0 and brake_state == "" and landing_recovery_left <= 0 and landing_push_left <= 0 and (has_ball or action != "idle" or jump > .05 or defense_weight < .5): return step
	# A small compression at contact separates each push without delaying input.
	var phase = 0.0
	for i in range(2):
		if swinging[i]: phase = sin(swing_progress[i]*PI)
	if not run_contacts and not stealing() and restart_left <= 0 and brake_state == "" and landing_recovery_left <= 0 and landing_push_left <= 0: step *= .78+.32*phase
	# Move only as far as the supporting leg can push. Never drag its contact
	# to rescue an overextended pose; the other foot must land first.
	for i in range(feet_world.size()):
		if swinging[i]: continue
		var side = -1.0 if i == 0 else 1.0
		var hip = body.to_global(Vector3(side*.145,1.29,0))
		var ankle = feet_world[i]+landing_shoe_offset(i)+body.global_basis*ANKLE_OFFSET
		var offset = hip-ankle
		var reserve = .003 if run_contacts or stealing() or landing_push_left > 0 or restart_left > 0 or brake_state != "" else .045
		var reach = (THIGH_LENGTH+SHIN_LENGTH-.002)*VISUAL_SCALE*height_ratio-reserve
		var a = step.length_squared()
		var b = offset.dot(step)
		var c = offset.length_squared()-reach*reach
		if a < .00000001: break
		if c > 0 and b >= 0:
			step = Vector3.ZERO
		elif b*b-a*c >= 0:
			step *= clampf((-b+sqrt(b*b-a*c))/a,0,1)
	# One controller owns locomotion. The render rig retargets contacts without
	# applying a second, differently-proportioned reach constraint to player input.
	return step

func settle_guard_support(delta: float) -> void:
	# Turning and loading the hips also consume reach. Bend the planted knee
	# slightly more instead of moving the shoe or changing either bone length.
	var planting_jump = defensive_jump() and action_time <= DEFENSE_PLANT_TIME
	var run_contacts = locomotion_pose() and not dribble_ended and jump < .05 and defense_weight < .5
	if not run_contacts and not planting_jump and not stealing() and restart_left <= 0 and brake_state == "" and landing_recovery_left <= 0 and landing_push_left <= 0 and (has_ball or action != "idle" or jump > .05 or defense_weight < .5):
		landing_support_drop = move_toward(landing_support_drop,0,delta*.9)
		body.position.y -= landing_support_drop
		return
	var lower = 0.0
	for i in range(2):
		if swinging[i] and not planting_jump: continue
		var side = -1.0 if i == 0 else 1.0
		var hip = body.to_global(Vector3(side*.145,1.29,0))
		var contact = body.to_global(defense_foot(i)) if planting_jump else feet_world[i]+landing_shoe_offset(i)
		var ankle = contact+body.global_basis*ANKLE_OFFSET
		var horizontal = Vector2(hip.x-ankle.x,hip.z-ankle.z).length_squared()
		var reach = (THIGH_LENGTH+SHIN_LENGTH-.004)*VISUAL_SCALE*height_ratio
		var height = sqrt(maxf(0,reach*reach-horizontal))
		lower = maxf(lower,hip.y-ankle.y-height)
	if stealing() or restart_left > 0 or brake_state != "" or landing_recovery_left > 0 or landing_push_left > 0 or landing_support_drop > 0:
		# Keep a little knee flexion through support exchange instead of popping
		# upright as soon as the formerly loaded foot leaves the floor.
		landing_support_drop = maxf(clampf(lower,0,.10),move_toward(landing_support_drop,0,delta*.9))
		body.position.y -= landing_support_drop
	else: body.position.y -= clampf(lower,0,.10)

func solve_knee(hip: Vector3, ankle: Vector3, pole: Vector3 = Vector3.BACK) -> Vector3:
	var offset = ankle - hip
	var distance = clampf(offset.length(), .05, THIGH_LENGTH + SHIN_LENGTH - .001)
	var direction = offset.normalized()
	var along = (THIGH_LENGTH * THIGH_LENGTH - SHIN_LENGTH * SHIN_LENGTH + distance * distance) / (2 * distance)
	var height = sqrt(maxf(0, THIGH_LENGTH * THIGH_LENGTH - along * along))
	var bend = (pole - direction * direction.dot(pole)).normalized()
	if bend.length_squared() < .01: bend = Vector3.RIGHT
	return hip + direction * along + bend * height

func solve_elbow(shoulder: Vector3, hand: Vector3, pole: Vector3) -> Vector3:
	var offset = hand - shoulder
	var distance = clampf(offset.length(), .05, UPPER_ARM_LENGTH + FOREARM_LENGTH - .001)
	var direction = offset.normalized()
	var along = (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2 * distance)
	var height = sqrt(maxf(0, UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along))
	var bend = (pole - direction * direction.dot(pole)).normalized()
	if bend.length_squared() < .01: bend = direction.cross(Vector3.RIGHT).normalized()
	return shoulder + direction * along + bend * height

func reachable_foot(hip: Vector3, foot: Vector3, grounded: bool) -> Vector3:
	var reach = THIGH_LENGTH + SHIN_LENGTH - .002
	var ankle = foot + ANKLE_OFFSET
	if hip.distance_to(ankle) <= reach: return foot
	if grounded:
		# Constrain on the ground plane so the foot never sinks into the floor.
		var hip_world = body.to_global(hip)
		var foot_world = body.to_global(foot)
		var ankle_world = foot_world + body.basis * ANKLE_OFFSET
		var dy = ankle_world.y - hip_world.y
		var horizontal = Vector2(ankle_world.x - hip_world.x, ankle_world.z - hip_world.z)
		var allowed = sqrt(maxf(0, pow(reach * VISUAL_SCALE, 2) - dy * dy))
		horizontal = horizontal.limit_length(allowed)
		ankle_world.x = hip_world.x + horizontal.x
		ankle_world.z = hip_world.z + horizontal.y
		var constrained = body.to_local(ankle_world)
		return hip + (constrained - hip).limit_length(reach) - ANKLE_OFFSET
	return hip + (ankle - hip).limit_length(reach) - ANKLE_OFFSET

func setup(opponent: bool) -> void:
	is_opponent = opponent
	skin = "ac8061" if opponent else "c7a086"
	var dark = "33342e" if opponent else "30373e"
	marker = Node3D.new()
	add_child(marker)
	CourtArt.arc(marker, Vector3(0, 0.14, 0), 0.49, 0, TAU, "f2ca52" if opponent else "9fef4f", 0.025, 32)
	shadow = CourtArt.cylinder(self, Vector3(0, 0.11, 0), 0.38, 0.38, 0.007, "3c6564")
	shadow.scale.z = 0.7
	body = Node3D.new()
	add_child(body)
	body.scale = Vector3.ONE * VISUAL_SCALE
	upper = Node3D.new()
	body.add_child(upper)
	# Reference direction: roughly seven heads tall, slim shoulders and long legs.
	StreetModel.loft(upper, [Vector3(1.20, .225, .14), Vector3(1.30, .25, .16), Vector3(1.54, .255, .16), Vector3(1.78, .285, .17), Vector3(1.90, .30, .16), Vector3(2.01, .23, .11), Vector3(2.05, .12, .09)], "ffffff", true, "stripe" if opponent else "jersey")
	CourtArt.cylinder(upper, Vector3(0, 2.07, 0), .065, .085, .13, skin).material_override = StreetModel.material(skin, "skin")
	StreetModel.loft(upper, [Vector3(2.02, .13, .095), Vector3(2.06, .12, .09)], dark)
	if not opponent:
		for z in [-.175, .18]:
			var number = CourtArt.label(upper, "07", Vector3(0, 1.64, z), 38, "353e46")
			number.pixel_size = .006
			if z < 0: number.rotation_degrees.y = 180
		var chest = CourtArt.label(upper, "RUSH", Vector3(0, 1.85, .188), 17, "353e46")
		chest.pixel_size = .005
	head = Node3D.new()
	upper.add_child(head)
	head.position = Vector3(0, 2.26, .008)
	head.scale = Vector3(1.01, .91, .96)
	# Cheekbone, narrower jaw and chin are built into one mesh.
	StreetModel.loft(head, [Vector3(-.17, .047, .061), Vector3(-.125, .092, .094), Vector3(-.045, .126, .113), Vector3(.055, .132, .12), Vector3(.13, .111, .102), Vector3(.17, .06, .06)], skin, true, "face")
	var nose = StreetModel.loft(head, [Vector3(-.045, .019, .012), Vector3(-.018, .024, .026), Vector3(.055, .010, .008)], skin, false, "skin")
	nose.position.z = .113
	for side in [-1, 1]:
		CourtArt.sphere(head, Vector3(side * .133, -.025, 0), Vector3(.045, .075, .032), skin)
	if opponent:
		StreetModel.loft(head, [Vector3(.095, .135, .125), Vector3(.145, .142, .13), Vector3(.205, .10, .10), Vector3(.23, .01, .01)], "805b34")
		for i in range(5):
			var lock = StreetModel.loft(head, [Vector3(.10, .022, .015), Vector3(.145, .035, .025), Vector3(.19, .02, .018)], "9a7140", false)
			lock.position = Vector3((i - 2) * .048, 0, .097)
			lock.rotation.z = -.18
	else:
		StreetModel.loft(head, [Vector3(.11, .139, .13), Vector3(.14, .143, .133), Vector3(.18, .132, .123), Vector3(.215, .111, .103), Vector3(.242, .075, .069), Vector3(.256, .035, .033), Vector3(.26, .005, .005)], "454d52")
		var brim = CourtArt.sphere(head, Vector3(-.015, .12, -.17), Vector3(.255, .026, .20), "454d52")
		brim.rotation.x = -.08
		CourtArt.box(head, Vector3(0, .132, .129), Vector3(.065, .018, .009), "989e95")
	CourtArt.box(body, Vector3(0, 1.25, 0), Vector3(.44, .07, .29), dark)
	for side in [-1, 1]:
		var short_leg = StreetModel.loft(body, [Vector3(-.5, .15, .14), Vector3(-.1, .17, .15), Vector3(.36, .16, .145), Vector3(.5, .135, .125)], "b8c59c" if opponent else "ffffff", true, "denim")
		shorts.append(short_leg)
		# Stitched hems follow the thigh mesh instead of floating above the knee.
		StreetModel.loft(short_leg, [Vector3(.44, .141, .131), Vector3(.50, .137, .127)], dark, false)
		var upper_arm = StreetModel.loft(body, [Vector3(-.64,.035,.040),Vector3(-.50,.082,.082),Vector3(-.28,.086,.081),Vector3(.16,.069,.067),Vector3(.50,.062,.060)], skin, false)
		var forearm = StreetModel.loft(body, [Vector3(-.50,.061,.060),Vector3(-.28,.067,.064),Vector3(.12,.058,.052),Vector3(.50,.044,.042)], skin, false)
		if opponent:
			StreetModel.loft(upper_arm, [Vector3(-.64, .055, .060), Vector3(-.50, .099, .098), Vector3(-.25, .105, .101), Vector3(.06, .092, .088)], "ffffff", true, "stripe_sleeve")
		upper_arm.material_override = StreetModel.material(skin, "skin")
		forearm.material_override = StreetModel.material(skin, "skin")
		arms.append([upper_arm, forearm])
		var elbow_joint = CourtArt.sphere(body, Vector3.ZERO, Vector3(.132, .14, .132), skin)
		elbow_joint.material_override = StreetModel.material(skin, "skin")
		elbows.append(elbow_joint)
		var deltoid = CourtArt.sphere(body, Vector3.ZERO, Vector3(.18,.23,.18), "ffffff" if opponent else skin)
		deltoid.material_override = StreetModel.material("ffffff" if opponent else skin,"stripe_sleeve" if opponent else "skin")
		shoulder_caps.append(deltoid)
		hands.append(CourtArt.sphere(body, Vector3.ZERO, Vector3(.10, .145, .075), skin))
		hands[-1].material_override = StreetModel.material(skin, "skin")
		var thumb = CourtArt.sphere(body, Vector3.ZERO, Vector3(.047, .085, .045), skin)
		thumb.material_override = StreetModel.material(skin, "skin")
		thumbs.append(thumb)
		cuffs.append(CourtArt.sphere(body, Vector3.ZERO, Vector3(.11, .065, .10), dark if opponent else "c2c4b8"))
		var thigh = CourtArt.cylinder(body, Vector3.ZERO, .095, .078, 1, skin)
		var calf = StreetModel.loft(body, [Vector3(-.5, .073, .07), Vector3(-.20, .083, .08), Vector3(.1, .072, .074), Vector3(.5, .050, .052)], skin)
		thigh.material_override = StreetModel.material(skin, "skin")
		calf.material_override = StreetModel.material(skin, "skin")
		legs.append([thigh, calf])
		var shoe = Node3D.new()
		body.add_child(shoe)
		CourtArt.sphere(shoe, Vector3(0, .04, .055), Vector3(.18, .075, .32), "b9b9aa")
		CourtArt.sphere(shoe, Vector3(0, .087, .065), Vector3(.172, .12, .30), dark)
		StreetModel.loft(shoe, [Vector3(.07, .072, .073), Vector3(.14, .074, .072), Vector3(.20, .063, .060)], "71786c" if opponent else "7e8587", false)
		StreetModel.loft(shoe, [Vector3(.17, .055, .052), Vector3(.25, .052, .049)], "a2a68d" if opponent else "c5c7bd", false)
		for lace in range(3):
			CourtArt.box(shoe, Vector3(0, .15 - lace * .014, .04 + lace * .033), Vector3(.09, .009, .013), "d7d8c8")
		CourtArt.box(shoe, Vector3(side * .083, .09, .03), Vector3(.009, .025, .12), "b4b9b0")
		shoes.append(shoe)
	if use_skinned:
		skinned = RigVisual.new()
		add_child(skinned)
		skinned.setup(opponent)
		body.visible = false

func crossing() -> bool:
	return action == "cross" and cross_valid

func locomotion_pose() -> bool:
	return action == "idle" or crossing()

func cross_phase() -> float:
	return clampf((action_time-cross_wait)/CROSS_TIME,0,1)

func cross_duration() -> float:
	return cross_wait+CROSS_TIME

func cross_body_pose() -> Dictionary:
	var pose=CrossClip.sample(cross_phase() if crossing() else 1.0)
	var weight=0.0
	if crossing():weight=smoothstep(0,.11,maxf(0,action_time-cross_wait))
	elif ordinary_dribble() and cross_drive_left>0:weight=1-smoothstep(0,CROSS_DRIVE_TIME,CROSS_DRIVE_TIME-cross_drive_left)
	pose["weight"]=weight
	return pose

func cross_contact_weight(side: float) -> float:
	if action_time<cross_wait:return 1.0 if side==cross_from else 0.0
	return 1-smoothstep(.18,.46,cross_phase()) if side==cross_from else smoothstep(.52,.85,cross_phase())

func prepare_cross(ball_position: Vector3) -> void:
	cross_from = dribble_hand
	cross_to = -cross_from
	cross_start_phase = fposmod(dribble_phase,TAU)/TAU
	cross_rate = dribble_rate(maxf(motion.length(),last_visual_velocity.length()))
	# Keep the existing bounce until the sending palm can touch it again.
	cross_wait = (.94-cross_start_phase)*TAU/cross_rate if cross_start_phase > .20 and cross_start_phase < .94 else 0.0
	cross_yaw = rotation.y
	cross_start_ball = ball_position-global_position
	cross_start_hands = [palm_position(0)-global_position,palm_position(1)-global_position]
	cross_start_palms = [hands[0].global_basis.orthonormalized(),hands[1].global_basis.orthonormalized()]
	cross_received = false
	cross_valid = true
	cross_exit_left = 0
	cross_drive_left = 0
	action = "cross"
	action_time = 0

func cross_pre_ball(at: float) -> Vector3:
	var phase = fposmod(cross_start_phase+at*cross_rate/TAU,1)
	var heading = Basis(Vector3.UP,cross_yaw)
	var result = heading*Vector3(cross_from*.44*VISUAL_SCALE,0,(.25+.04*run_swing_weight)*VISUAL_SCALE)
	result.y = bounce_height(phase)
	return cross_start_ball.lerp(result,smoothstep(0,.06,at))

func cross_ball_world() -> Vector3:
	if action_time <= cross_wait: return global_position+cross_pre_ball(action_time)
	var start = cross_pre_ball(cross_wait) if cross_wait > 0 else cross_start_ball
	var heading = Basis(Vector3.UP,cross_yaw)
	var bounce = heading*Vector3(0,0,.47*VISUAL_SCALE)
	bounce.y = DRIBBLE_FLOOR-global_position.y
	var finish = global_basis*Vector3(cross_to*.44*VISUAL_SCALE,0,(.25+.04*run_swing_weight)*VISUAL_SCALE)
	finish.y = bounce_height(0)
	var t = cross_phase()
	if t < .5:
		return global_position+start.lerp(bounce,pow(t/.5,1.5))
	var u = (t-.5)/.5
	return global_position+bounce.lerp(finish,1-pow(1-u,2))

func cross_hand_pose(index: int,balance: Vector3) -> Vector3:
	var side = -1.0 if index == 0 else 1.0
	var ball = body.to_local(cross_ball_world()+Vector3.UP*DRIBBLE_PALM)
	var ready = upper.transform*Vector3(side*.43,1.48,.28)
	var target = ready
	if action_time < cross_wait:
		if side == cross_from:
			target = ball
			var phase = fposmod(cross_start_phase+action_time*cross_rate/TAU,1)
			target.y = body.to_local(Vector3(global_position.x,dribble_hand_height(phase),global_position.z)).y
	else:
		var t = cross_phase()
		if side == cross_from:
			target = ball.lerp(balance,smoothstep(.18,.46,t))
		else:
			target = ready.lerp(ball,smoothstep(.52,.85,t))
	var start: Vector3 = body.to_local(global_position+cross_start_hands[index])
	return start.lerp(target,smoothstep(0,.11,action_time))

func finish_cross() -> void:
	cross_exit_ball = cross_ball_world()-global_position
	cross_exit_hands = [palm_position(0)-global_position,palm_position(1)-global_position]
	cross_exit_palms = [hands[0].global_basis.orthonormalized(),hands[1].global_basis.orthonormalized()]
	cross_exit_left = .16
	cross_drive_left = CROSS_DRIVE_TIME
	dribble_hand = cross_to
	ball_side = cross_to
	dribble_phase = 0
	cross_valid = false
	action = "idle"
	action_time = 0

func dribble_local() -> Vector3:
	if action == "behind":
		var t = clampf(action_time / .48, 0, 1)
		var bounce = Vector3(0, .31, -.50)
		if t < .5:
			var u = t * 2
			return Vector3(-dribble_hand * .58, 1.09, .43).lerp(Vector3(-dribble_hand * .76, .76, -.52), u).lerp(Vector3(-dribble_hand * .76, .76, -.52).lerp(bounce, u), u)
		var u = (t - .5) * 2
		return bounce.lerp(Vector3(dribble_hand * .76, .76, -.52), u).lerp(Vector3(dribble_hand * .76, .76, -.52).lerp(Vector3(dribble_hand * .58, 1.09, .43), u), u)
	if action == "hesi":
		var t = clampf(action_time / .58, 0, 1)
		return Vector3(dribble_hand * .59, .31 + absf(2 * t - 1) * .78, .43)
	if action == "spin":
		var t = clampf(action_time / .64, 0, 1)
		# Keep the ball on the outside hip, with a visible bounce during the turn.
		return Vector3(dribble_hand * .55, .31 + absf(2 * t - 1) * .78, lerpf(.43, -.20, sin(t * PI)))
	if action == "twostep":
		var t = fposmod(action_time / .32, 1)
		return Vector3(dribble_hand * (.53 + sin(t * PI) * .10), .31 + absf(2 * t - 1) * .78, .48)
	if action == "cross":
		if crossing(): return body.to_local(cross_ball_world())
		var t = clampf(action_time / 0.38, 0, 1)
		return Vector3(lerpf(-dribble_hand, dribble_hand, smoothstep(0.06, 0.88, t)) * 0.65, 0.31 + pow(absf(2 * t - 1), 1.2) * 0.78, 0.54)
	var t = fposmod(dribble_phase, TAU) / TAU
	# Lead the driving shoulder as the torso leans forward. Keeping the
	# standing pocket under a running chest forces the receiving wrist back.
	var world=global_position+global_basis*Vector3(ball_side*.44*VISUAL_SCALE,0,(.25+.34*run_swing_weight)*VISUAL_SCALE*height_ratio)
	world.y=bounce_height(t)
	return body.to_local(world)

func dribble_rate(speed: float) -> float:
	return 9.0+minf(speed,5)*.55

func bounce_height(t: float) -> float:
	var crown=lerpf(1.10,1.06,run_swing_weight)*height_ratio
	var floor_y=DRIBBLE_FLOOR
	if t<.18:return crown-.14*pow(t/.18,2)
	if t<.42:
		var u=(t-.18)/.24
		var release=crown-.14
		var initial=-.28/.18*.24
		return release+initial*u+(floor_y-release-initial)*u*u
	if t<.90:
		var u=(t-.42)/.48
		return lerpf(floor_y,crown+.025,2*u-u*u)
	return lerpf(crown+.025,crown,smoothstep(.90,1,t))

func dribble_hand_height(t: float) -> float:
	var top=bounce_height(t)+DRIBBLE_PALM
	if t<=.18 or t>=.90:return top
	var release=bounce_height(.18)+DRIBBLE_PALM
	var low=release-.11
	if t<.36:
		# Continue the downward stroke after release, then relax the elbow.
		# Match the ball's release velocity; never snap straight back to the apex.
		var u=(t-.18)/.18
		return (2*u*u*u-3*u*u+1)*release+(u*u*u-2*u*u+u)*(-.28)+(3*u*u-2*u*u*u)*low
	# Recover with the rising ball. Both ends have zero velocity, including the
	# receiving contact, so this is one continuous press/recover/cushion loop.
	return lerpf(low,bounce_height(.90)+DRIBBLE_PALM,smoothstep(.36,.90,t))

func ordinary_dribble() -> bool:
	return has_ball and action == "idle" and not dribble_ended

func dribble_palm_pitch(phase: float) -> float:
	if phase<.34:return lerpf(-.12,.52,smoothstep(0,.34,phase))
	if phase<.90:return lerpf(.52,-.12,smoothstep(.34,.90,phase))
	return -.12

func dribble_hand_pose() -> Vector3:
	var t = fposmod(dribble_phase,TAU)/TAU
	var world=ball_anchor(0)
	world.y=lerpf(world.y+DRIBBLE_PALM,dribble_hand_height(t),smoothstep(0,.16,.16-cross_exit_left)) if cross_exit_left>0 else dribble_hand_height(t)
	return body.to_local(world)

func animate(delta: float, _time: float) -> void:
	var previous_palms = hands.map(func(h): return h.global_basis.orthonormalized().get_rotation_quaternion())
	var previous_upper_frame = upper.transform
	pose_delta = delta
	shot_recovery_left=maxf(0,shot_recovery_left-delta)
	redirect_left=maxf(0,redirect_left-delta)
	cross_exit_left = maxf(0,cross_exit_left-delta)
	cross_drive_left=maxf(0,cross_drive_left-delta) if ordinary_dribble() else 0.0
	var previous_body_height = body.position.y
	landing_recovery_left = maxf(0,landing_recovery_left-delta)
	landing_pose_left = maxf(0,landing_pose_left-delta) if action == "idle" else 0.0
	rebound_release_left = maxf(0,rebound_release_left-delta)
	previous_hand_world = hand_world
	if hands.size() == 2: previous_rebound_anchor = rebound_anchor()
	var displacement = global_position - previous_position
	var visual_teleport=displacement.length()>1.5
	var teleported = displacement.length() > 1.5 or feet_world.is_empty()
	var velocity = Vector3.ZERO if delta <= 0 or teleported else displacement / delta
	velocity.y = 0
	previous_position = global_position
	var speed = minf(velocity.length(), 7)
	var ground_stance = not has_ball and action == "idle" and jump < .05
	defense_weight = lerpf(defense_weight, 1.0 if (defending or boxing_out) and ground_stance else 0.0, 1-exp(-delta*12))
	boxout_weight = lerpf(boxout_weight, 1.0 if boxing_out and ground_stance else 0.0, 1-exp(-delta*10))
	pressure_weight = lerpf(pressure_weight, contact_pressure if boxing_out else 0.0, 1-exp(-delta*11))
	contest_weight = lerpf(contest_weight,1.0 if contesting_boxout and ground_stance else 0.0,1-exp(-delta*10))
	if teleported:
		feet_world.clear()
		swing_from.clear()
		swing_to.clear()
		for side in [-1.0, 1.0]:
			var foot = global_position + global_basis.x * side * .20 * VISUAL_SCALE
			foot.y = .105
			feet_world.append(foot)
			swing_from.append(foot)
			swing_to.append(foot)
		swinging = [false, false]
		swing_progress = [1.0, 1.0]
		feet_yaw = [rotation.y, rotation.y]
		previous_cycle = [fposmod(stride / TAU, 1), fposmod(stride / TAU + .5, 1)]
		next_step = 0
		last_step = -1
		guard_plant_time = 0
		guard_travel_direction = Vector3.ZERO
	gait_weight = move_toward(gait_weight, clampf(speed / 3.2, 0, 1), delta * 6)
	gait_length = lerpf(1.25, 2.15, clampf(speed / 4.7, 0, 1))
	if crossing(): dribble_phase = (cross_start_phase+minf(action_time,cross_wait)*cross_rate/TAU)*TAU
	elif not dribble_ended and not (action == "rebound" and defense_caught) and not (stealing() and steal_success):
		var resume_bounce = smoothstep(0,.16,.16-cross_exit_left) if cross_exit_left > 0 and ordinary_dribble() else 1.0
		dribble_phase += delta*dribble_rate(speed)*resume_bounce
	ball_side = move_toward(ball_side, dribble_hand, delta * 12)
	var turn_target = brake_yaw if brake_state in ["plant","load"] else facing
	if crossing(): turn_target = lerp_angle(cross_yaw,turn_target,smoothstep(.35,.95,cross_phase()))
	var turn_rate = 10.0 if brake_state != "" or brake_weight > .05 else lerpf(18,10,defense_weight)
	var yaw_step = angle_difference(rotation.y,turn_target)*(1-exp(-delta*turn_rate))
	if redirect_left>0 or (locomotion_pose() and not chase_recovery):yaw_step=clampf(yaw_step,-delta*7,delta*7)
	if brake_state != "" or brake_weight > .05: yaw_step = clampf(yaw_step,-delta*7,delta*7)
	if crossing() or cross_exit_left > 0: yaw_step = clampf(yaw_step,-delta*6,delta*6)
	if not held.owns(self):rotation.y += yaw_step
	# A running pull-up plants in its approach heading. Turning the hips to the
	# rim over the old sprint contacts winds the two legs across one another.
	if shot_gather_turn and action in ["gather","shot"]:
		rotation.y = shot_gather_yaw if action=="gather" else lerp_angle(shot_gather_yaw,facing,smoothstep(SHOT_PLANT_TIME+.008,.25,action_time))
	elif action not in ["gather","shot"]:
		shot_gather_turn = false
	if held.owns(self):held.tick(self,delta)
	elif not has_ball or not dribble_ended:held.reset()
	if action == "spin": rotation.y = turn_origin + turn_sign * TAU * smoothstep(0, 1, action_time / .64)
	update_footwork(delta, velocity)
	update_landing_push(delta)
	restart_left = maxf(0,restart_left-delta) if locomotion_pose() else 0.0
	if restart_phase() >= 3: restart_left = 0
	if chase_recovery and brake_state == "" and restart_left <= 0 and chase_recovery_time > .3: chase_recovery = false
	var brake_target = 1.0 if brake_state in ["load","settle"] else (.5 if brake_state in ["plant","receive"] else (.25 if restart_left > 0 else 0.0))
	brake_weight = lerpf(brake_weight,brake_target,1-exp(-delta*(18 if brake_target > brake_weight else 8)))
	run_entry_left = maxf(0,run_entry_left-delta) if locomotion_pose() else 0.0
	if run_entry_phase() >= 4: run_entry_left = 0
	var swing_target = clampf((speed-.25)/4.0,0,1) if locomotion_pose() and jump < .05 else 0.0
	swing_target *= 1-defense_weight
	swing_target *= 1-brake_weight*.55
	if run_entry_left > 0: swing_target *= lerpf(.35,1,smoothstep(0,3,run_entry_phase()))
	run_swing_weight = lerpf(run_swing_weight,swing_target,1-exp(-delta*10))
	# At foot plant the opposite arm is forward; at leg passing the arms pass.
	# Use the contact cycle for torso and both arms, never a separate time clock.
	var run_pose = RunClip.sample(stride)
	var run_wave: float = run_pose.arm
	run_twist = lerpf(run_twist,run_wave*(.16 if has_ball else .18)*run_swing_weight,1-exp(-delta*24))
	var athletic_weight = run_swing_weight*(1-defense_weight)*(1-boxout_weight)
	var athletic_stance = gait_weight*(1-defense_weight)*(1-boxout_weight) if locomotion_pose() and not dribble_ended and jump < .05 else 0.0
	var cut_target = clampf(angle_difference(rotation.y,facing),-.55,.55) if brake_state in ["settle","push","receive"] or restart_left > 0 else 0.0
	if redirect_left>0:cut_target=clampf(angle_difference(rotation.y,facing),-.55,.55)
	cut_twist = lerpf(cut_twist,cut_target,1-exp(-delta*14))
	var crouch = (0.08 if has_ball else 0.035) + gait_weight * lerpf(.11,.035,defense_weight)
	crouch += athletic_stance*(.075+run_pose.load)
	crouch += defense_weight*.18 + boxout_weight*(.035 + pressure_weight*.045)
	crouch += contest_weight*.08
	crouch += brake_weight*.14
	if action == "showcase": crouch = .025
	if action == "gather": crouch += sin(clampf(action_time / 0.62, 0, 1) * PI) * 0.20
	if action == "gather" and finish_running and finish_kind == "layup":
		crouch = .08 + gait_weight * .11 + sin(clampf(action_time / .20, 0, 1) * PI) * .035
	var cross_pose = cross_body_pose()
	if crossing() or cross_drive_left>0: crouch += cross_pose.drop*cross_pose.weight
	elif action == "cross": crouch += sin(clampf(action_time / .38,0,1)*PI)*.17
	if action in ["spin", "twostep"]: crouch += sin(clampf(action_time / .64, 0, 1) * PI) * .10
	if action == "hesi": crouch -= sin(clampf(action_time / .58, 0, 1) * PI) * .07
	if action in ["shot", "layup", "dunk", "block"]:
		crouch = maxf(0, 1 - absf(action_time - 0.78) / 0.16) * 0.18
	if action == "layup" and finish_target_valid:
		crouch = layup_load * (1 - smoothstep(.02, .16, action_time)) + .15 * smoothstep(.69, .82, action_time)
	body.position.y = jump - crouch - cos(stride * 2) * gait_weight * lerpf(.018,.004,defense_weight) + sin(_time * 2.2) * (1 - gait_weight) * .009
	if locomotion_pose(): body.position.y = lerpf(body.position.y,minf(body.position.y,-.34),brake_weight)
	if action == "layup" and finish_target_valid: body.position.y = layup_pelvis_height()
	if defensive_jump(): body.position.y = defense_body_height()
	if stealing(): body.position.y = lerpf(-steal_load-(.32-steal_load)*steal_reach(),body.position.y,smoothstep(.38,STEAL_DURATION,action_time))
	if landing_push_left > 0:
		var phase = landing_push_phase()
		var push_height = -.22+.10*sin(clampf(phase/2,0,1)*PI)
		body.position.y = lerpf(push_height,body.position.y,smoothstep(1.45,2,phase))
	if landing_pose_left > 0:
		# Analytic critically damped recovery keeps vertical velocity continuous even
		# when stopping or reversing changes the next stride's target crouch.
		var offset = landing_from_height-body.position.y
		var spring = (landing_from_velocity+22*offset)*delta
		var decay = exp(-22*delta)
		landing_from_height = body.position.y+(offset+spring)*decay
		landing_from_velocity = (landing_from_velocity-22*spring)*decay
		body.position.y = landing_from_height
	if locomotion_pose() and jump<.05 and not teleported and landing_pose_left<=0 and landing_push_left<=0:
		body.position.y=move_toward(previous_body_height,body.position.y,delta*2.0)
	var local_velocity = velocity.rotated(Vector3.UP, -rotation.y)
	var local_contact = contact_direction.rotated(Vector3.UP,-rotation.y)
	var brace = pressure_weight * boxout_weight
	body.position.x = local_contact.x*.025*brace
	body.position.z = local_contact.z*.045*brace
	if crossing() or cross_drive_left>0: body.position.x += cross_pose.shift*cross_from*cross_pose.weight
	if brake_weight > .001 and feet_world.size() == 2:
		if swinging[brake_balance_foot] and not swinging[1-brake_balance_foot]: brake_balance_foot = 1-brake_balance_foot
		var support = body.to_local(feet_world[brake_balance_foot])
		var shift = Vector3(clampf(support.x*VISUAL_SCALE,-.045,.045),0,clampf(support.z*VISUAL_SCALE,-.035,.035))
		brake_balance_offset = brake_balance_offset.lerp(shift,1-exp(-delta*14))
		body.position += brake_balance_offset*brake_weight
	if defensive_jump(): body.position.x += (-.022 if defense_land_first == 0 else .022)*sin(clampf((action_time-defense_land_time())/.18,0,1)*PI)
	if landing_recovery_left > 0:
		var weight = 1-smoothstep(0,LANDING_RECOVERY_TIME,LANDING_RECOVERY_TIME-landing_recovery_left)
		body.position.x = lerpf(body.position.x,landing_from_offset.x,weight)
		body.position.z = lerpf(body.position.z,landing_from_offset.z,weight)
	if landing_push_left > 0:
		# Transfer the pelvis over the loaded leg, then follow the push direction.
		var push_phase = landing_push_phase()
		var transfer = sin(clampf(push_phase/.90,0,1)*PI)
		var support = body.to_local(feet_world[landing_push_support])
		body.position.x += clampf(support.x*VISUAL_SCALE,-.055,.055)*transfer
		body.position.z += clampf(local_velocity.z*.012,-.035,.035)*sin(clampf(push_phase/2,0,1)*PI)
	var acceleration = ((velocity - last_visual_velocity) / maxf(delta, .016)).rotated(Vector3.UP, -rotation.y)
	last_visual_velocity = velocity
	var drive_load = sin(clampf(restart_phase(),0,3)*PI/3)*brake_weight if restart_left > 0 else 0.0
	var cut_brace = brake_weight*(1-smoothstep(.2,1.6,restart_phase())) if restart_left > 0 else brake_weight
	var lean = lerpf(clampf(acceleration.z * .003, -.08, .10)+clampf(local_velocity.z*.014,-.055,.065)*run_swing_weight+athletic_weight*(.025+run_pose.drive*.35)+drive_load*.075, .025 - pressure_weight*.035, defense_weight)
	body.rotation.x = lerpf(body.rotation.x, lean, 1 - exp(-delta * 8))
	if action == "layup": body.rotation.x = lerpf(body.rotation.x, .07 * (1-smoothstep(.08, .34, action_time)), 1-exp(-delta*18))
	if defensive_jump():
		var strike_lean = block_upper_pose().x*.28 if action == "block" else 0.0
		body.rotation.x = lerpf(body.rotation.x,.025+.075*defense_landing_load()+strike_lean,1-exp(-delta*16))
	if landing_push_left > 0:
		body.rotation.x = lerpf(body.rotation.x,clampf(local_velocity.z*.025,-.08,.12),1-exp(-delta*14))
	if stealing(): body.rotation.x = lerpf(body.rotation.x,.18*steal_reach(),1-exp(-delta*20))
	body.rotation.z = lerpf(body.rotation.z,-local_velocity.x*.026-run_wave*.022*run_swing_weight-cut_twist*.12+cross_pose.lean*cross_from*cross_pose.weight,1-exp(-delta*18))
	body.rotation.z += local_contact.x*.018*brace*delta*8
	body.rotation.y = lerpf(body.rotation.y,-run_twist*.28,1-exp(-delta*18))
	upper.rotation.x = (.035+speed*.014 if has_ball else .04+speed*.012)+athletic_weight*(.085+run_pose.drive)+drive_load*.07
	upper.rotation.x = lerpf(upper.rotation.x,.14,defense_weight)
	upper.rotation.x = lerpf(upper.rotation.x,.14,contest_weight)
	upper.rotation.y = run_twist + cut_twist*.55 + (sin(dribble_phase)*.018 if has_ball else 0.0)
	if crossing() or cross_drive_left>0:
		upper.rotation.y += cross_pose.twist*cross_from*cross_pose.weight
		upper.rotation.x += cross_pose.pitch*cross_pose.weight
	if action == "behind": upper.rotation.y = -dribble_hand * sin(action_time / .48 * TAU) * .18
	if stealing():
		upper.rotation.x = .10*steal_reach()
		upper.rotation.y = -dribble_hand*.10*steal_reach()
	if action in ["shot", "layup", "dunk", "block"]: upper.rotation.x = -0.015
	if action == "layup": upper.rotation.x = .08 * (1-smoothstep(.08, .34, action_time))
	if defensive_jump():
		upper.rotation.x = -.055*smoothstep(.05,.24,action_time)*(1-smoothstep(.46,.80,action_time))+.12*defense_landing_load()
		upper.rotation.y = 0
		if defense_caught:
			var receive = sin(clampf((action_time-defense_catch_time)/.13,0,1)*PI)
			upper.rotation.x += receive*.055+.085*rebound_tuck_phase()
		elif action == "block": upper.rotation = block_upper_pose()+Vector3(.12*defense_landing_load(),0,0)
	upper.rotation.x = lerpf(upper.rotation.x,.10+pressure_weight*.045,boxout_weight)
	upper.rotation.z = -local_contact.x*.07*brace+run_wave*.038*run_swing_weight-cut_twist*.06
	if defensive_jump() and action == "block": upper.rotation.z = block_upper_pose().z
	if crossing() or cross_drive_left>0: upper.rotation.z += cross_pose.roll*cross_from*cross_pose.weight
	if landing_recovery_left > 0:
		upper.rotation = landing_from_upper.lerp(upper.rotation,smoothstep(0,LANDING_RECOVERY_TIME,LANDING_RECOVERY_TIME-landing_recovery_left))
	if action == "dunk": upper.rotation.x = lerpf(-.10, .13, smoothstep(.28, .55, action_time))
	upper.position = Vector3(0, 1.55, 0) - upper.basis * Vector3(0, 1.55, 0)
	head.rotation.z = -body.rotation.z * 0.5
	var look_up = -.16 if defensive_jump() else 0.0
	if defense_caught: look_up *= 1-rebound_tuck_phase()
	head.rotation.x = lerpf(head.rotation.x,look_up,1-exp(-delta*14))
	var look_yaw = facing
	if watch_direction.length_squared() > .01 and defense_weight > .1: look_yaw = atan2(watch_direction.x,watch_direction.z)
	head.rotation.y = lerpf(head.rotation.y, clampf(angle_difference(rotation.y, look_yaw), -.65, .65) - upper.rotation.y * .55, 1 - exp(-delta * 9))
	shadow.scale = Vector3(1 + jump * 0.12, 1, 0.7 + jump * 0.1)
	settle_guard_support(delta)
	body_vertical_velocity = (body.position.y-previous_body_height)/maxf(delta,.0001)
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var shoe_offset = landing_shoe_offset(i)
		var foot = body.to_local(feet_world[i]+shoe_offset)
		var hip = Vector3(side * 0.145, 1.29, 0)
		var knee_pole = Vector3.BACK
		if action == "showcase":
			foot = Vector3(side * (.24 if side < 0 else .17), (.105 - body.position.y) / VISUAL_SCALE, .14 if side < 0 else -.10)
		if action == "layup" and finish_target_valid and layup_start_feet.size() == 2:
			foot = layup_foot(i)
		elif defensive_jump():
			foot = defense_foot(i)
		elif jump > 0.05:
			var contact_foot = foot
			foot = Vector3(side * 0.19, 0.07, -0.14 - side * 0.12)
			if action == "layup":
				var knee_lift = sin(clampf(action_time / .72, 0, 1) * PI)
				var raised_knee = Vector3(side * .19, .73 + (.40 * knee_lift if side == dribble_hand else -.08), .46 * knee_lift if side == dribble_hand else -.16)
				foot = raised_knee + Vector3(0, -.42, -.18)
				knee_pole = raised_knee - hip
			elif action == "dunk":
				# Both legs trail the rise, then extend to land; no layup knee pose.
				var fold = sin(clampf(action_time / .76, 0, 1) * PI)
				foot = Vector3(side * .22, .10 + .32 * fold, -.12 - .40 * fold)
				knee_pole = Vector3(side * .10, -.40, .30)
			if action in ["layup", "dunk"]:
				foot = contact_foot.lerp(foot, smoothstep(.01, .13 if side != dribble_hand else .09, action_time))
				foot = foot.lerp(Vector3(side * .20, .10, 0), smoothstep(.62, .82, action_time))
		var safe_foot = reachable_foot(hip, foot, jump <= .05)
		if jump <= .05 and action != "showcase":
			if safe_foot.distance_to(foot) > .001 and not (has_ball and dribble_ended and i == 0):
				# Release an overextended planted foot; never scale the bones to compensate.
				feet_world[i] = body.to_global(safe_foot)-shoe_offset
				# Reach correction cannot independently launch the second leg.
			if safe_foot.distance_to(foot) > .00001: feet_world[i] = body.to_global(safe_foot)-shoe_offset
		foot = safe_foot
		if defensive_jump() and action_time >= defense_touch_time(i):
			feet_world[i] = body.to_global(foot)
			feet_yaw[i] = defense_landing_yaw
		var ankle = foot + ANKLE_OFFSET
		var knee = solve_knee(hip, ankle, knee_pole)
		joint_hips[i] = hip
		joint_knees[i] = knee
		joint_ankles[i] = ankle
		shoes[i].position = foot
		shoes[i].rotation.y = angle_difference(rotation.y, feet_yaw[i]) if jump < .05 else 0.0
		shoes[i].rotation.x = -.12 * sin(swing_progress[i] * PI) if swinging[i] and jump < .05 else (.28 if jump > .05 else 0.0)
		shoes[i].rotation.z = 0
		if (athletic_stance > .01 or stealing() or defense_weight > .5 or brake_state != "" or brake_weight > .01 or landing_recovery_left > 0 or landing_push_left > 0 or landing_push_pitch[i] > 0) and jump < .05:
			shoes[i].basis = body.global_basis.inverse() * Basis(Vector3.UP,feet_yaw[i]) * Basis(Vector3.RIGHT,landing_push_pitch[i]) * VISUAL_SCALE
		if defensive_jump():
			var shoe_yaw = lerp_angle(defense_yaw,defense_landing_yaw,smoothstep(DEFENSE_PLANT_TIME,DEFENSE_PLANT_TIME+.20,action_time))
			shoes[i].basis = body.global_basis.inverse()*Basis(Vector3.UP,shoe_yaw)*Basis(Vector3.RIGHT,defense_shoe_pitch(i))*VISUAL_SCALE
		if action == "layup" and finish_target_valid and i == layup_plant_index:
			# Roll about the forefoot in world space, including the body's forward lean.
			var shoe_basis = Basis(Vector3.UP, layup_plant_yaw) * Basis(Vector3.RIGHT, layup_heel_roll())
			shoes[i].basis = body.global_basis.inverse() * shoe_basis * VISUAL_SCALE
		CourtArt.align(shorts[i], hip, hip.lerp(knee, 0.92))
		CourtArt.align(legs[i][0], hip.lerp(knee, 0.82), knee)
		CourtArt.align(legs[i][1], knee, ankle)
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var arm_wave = run_wave if i == 0 else -run_wave
		var natural_run = locomotion_pose() and run_swing_weight > .02 and defense_weight < .1 and boxout_weight < .1 and not dribble_ended
		var shoulder = upper.transform * Vector3(side*.29,1.95+arm_wave*.006*run_swing_weight,arm_wave*.012*run_swing_weight)
		var shoulder_angle = -.38+.48*arm_wave-drive_load*.12
		var elbow_flex = 1.16+.16*arm_wave
		var humerus = Vector3(side*.025,-cos(shoulder_angle),sin(shoulder_angle)).normalized()
		var forearm_direction = Vector3(side*.015,-cos(shoulder_angle+elbow_flex),sin(shoulder_angle+elbow_flex)).normalized()
		var run_elbow = shoulder+upper.basis*humerus*UPPER_ARM_LENGTH
		var run_hand = run_elbow+upper.basis*forearm_direction*FOREARM_LENGTH
		var elbow = Vector3(side*.36,1.53,-.06).lerp(run_elbow,run_swing_weight)
		var hand = Vector3(side*.35,1.20,.08).lerp(run_hand,run_swing_weight)
		if action == "showcase":
			hand = Vector3(side * .34, 1.24 if side < 0 else 1.18, .15 if side < 0 else .07)
			elbow = Vector3(side * .40, 1.59, -.04)
		if has_ball and action in ["idle", "cross", "spin", "twostep", "behind", "hesi"]:
			var ball_pos = dribble_local()
			if side == dribble_hand or action == "cross":
				hand = Vector3(ball_pos.x if side == dribble_hand else side * 0.50, maxf(1.17, ball_pos.y + 0.23), ball_pos.z)
				elbow = Vector3(side * 0.41, 1.50, 0.10)
				if ordinary_dribble():
					hand = dribble_hand_pose()
					elbow = upper.transform*Vector3(side*.20,1.55,-.12)
			if crossing():
				var balance_hand = Vector3(side*.35,1.20,.08).lerp(run_hand,run_swing_weight)
				hand = cross_hand_pose(i,balance_hand)
				elbow = upper.transform*Vector3(side*.22,1.53,-.12)
			if dribble_ended:
				hand = Vector3(side * .13, 1.52, .36)
				elbow = Vector3(side * .34, 1.60, .12)
			elif action == "behind":
				var t = clampf(action_time / .48, 0, 1)
				if side == -dribble_hand:
					hand = Vector3(side * .55, 1.34, .40).lerp(Vector3(side * .47, 1.27, -.30), smoothstep(0, .42, t))
					hand = hand.lerp(Vector3(side * .36, 1.38, .04), smoothstep(.48, 1, t))
				else:
					hand = Vector3(side * .42, 1.34, -.24).lerp(Vector3(side * .58, 1.32, .43), smoothstep(.52, 1, t))
				elbow = Vector3(side * .44, 1.59, -.16)
		elif not has_ball and speed < 0.3 and action != "showcase":
			hand = Vector3(side * 0.67, 1.38, 0.30)
			elbow = Vector3(side * 0.55, 1.72, 0.07)
		var turning_arm = locomotion_pose() and not crossing() and not dribble_ended and jump < .05 and defense_weight < .1 and boxout_weight < .1 and (brake_state != "" or restart_left > 0 or brake_weight > .01)
		if turning_arm and (not has_ball or side != dribble_hand):
			# Brace the free arm during the load, then open its running swing as
			# the planted foot pushes and the opposite foot receives.
			hand = hand.lerp(upper.transform*Vector3(side*.34,1.37,.18),cut_brace)
			elbow = elbow.lerp(upper.transform*Vector3(side*.32,1.61,-.03),cut_brace)
		# Blend guard/brace poses after the relaxed idle arms, before action poses.
		hand = hand.lerp(Vector3(side*.50,1.52 if side > 0 else 1.28,.38),defense_weight)
		elbow = elbow.lerp(Vector3(side*.43,1.64,.16),defense_weight)
		var contact_arm = clampf(.5+side*local_contact.x*.5,0,1)
		hand = hand.lerp(Vector3(side*.40,1.33,.37),contest_weight)
		elbow = elbow.lerp(Vector3(side*.36,1.60,.15),contest_weight)
		hand = hand.lerp(Vector3(side*(.50+.06*contact_arm),1.28+.08*contact_arm,-.10-.12*pressure_weight*contact_arm),boxout_weight)
		elbow = elbow.lerp(Vector3(side*.44,1.56,-.04),boxout_weight)
		if action in ["gather", "shot", "fake"] or (action == "block" and not defense_target_valid):
			var lift = clampf(action_time * 4, 0, 1)
			if action == "gather" and finish_running: lift = .18 + .12 * clampf(action_time / .20, 0, 1)
			if action in ["shot", "block"]: lift = 1
			elbow = Vector3(side * 0.29, lerpf(1.4, 2.02, lift), 0.24)
			hand = Vector3(side * 0.13, lerpf(1.25, 2.49, lift), 0.37)
			if action == "shot" and action_time > 0.22:
				var follow = smoothstep(0.22, 0.38, action_time)
				hand += Vector3(side * 0.06, -0.09, 0.15) * follow
				if side != dribble_hand: hand.y -= 0.42 * follow
		elif action == "layup":
			var lift = smoothstep(.08, .34, action_time)
			if side == dribble_hand:
				elbow = Vector3(side * .30, lerpf(1.65, 2.16, lift), .32)
				hand = Vector3(side * .21, lerpf(1.6, 2.60, lift), lerpf(.34, .46, lift))
			else:
				elbow = Vector3(side * .43, 1.65, -.04)
				hand = Vector3(side * .54, 1.48, .14)
			if action_time > .43: hand.y -= smoothstep(.43, .78, action_time) * .90
		elif action == "dunk":
			if side == dribble_hand:
				var lift = smoothstep(0, .23, action_time)
				hand = Vector3(side * .18, 1.62, .30).lerp(Vector3(side * .16, 2.68, .16), lift)
				elbow = Vector3(side * .36, 2.15, -.03)
				if finish_target_valid:
					var press = smoothstep(.38, .53, action_time)
					var rim_hand = body.to_local(finish_rim_world + Vector3(0, lerpf(.15, -.22, press), .02))
					hand = hand.lerp(rim_hand, smoothstep(.22, .36, action_time))
				hand = hand.lerp(Vector3(side * .40, 1.38, .30), smoothstep(.56, .84, action_time))
			else:
				elbow = Vector3(side * .40, 1.7, -.04)
				hand = Vector3(side * .50, 1.50, .05)
		elif action == "steal":
			hand = steal_hand_target(i) if stealing() else Vector3(side*.36,1.30,.19)
			elbow = Vector3(side*.40,1.44,.32 if i == steal_hand else -.12)
		if defensive_jump():
			hand = defense_hand(i)
			elbow = Vector3(side*.48,1.91,.05)
			if action == "block":
				elbow = upper.transform*Vector3(side*.42,2.08,-.10).lerp(Vector3(side*.34,1.91,.22),smoothstep(.15,.34,action_time))
			if action == "block" and block_contact and side == dribble_hand:
				elbow = elbow.lerp(upper.transform*Vector3(side*.34,1.52,.35),smoothstep(0,.18,action_time-block_contact_time))
			if action == "rebound" and defense_caught:
				elbow = elbow.lerp(upper.transform*Vector3(side*.35,1.47,.17),rebound_tuck_phase())
		var blend = 1 - exp(-delta * 24) if pose_ready else 1.0
		var arm_transport = upper.transform*previous_upper_frame.affine_inverse()
		var carried_hand = hands[i].position
		if turning_arm and pose_ready:
			# Smooth the arm's swing inside the moving chest frame. Smoothing
			# in body space leaves the elbow/hand behind when the chest turns.
			elbow_pole_pose[i] = arm_transport*elbow_pole_pose[i]
			if not has_ball or side != dribble_hand: carried_hand = arm_transport*carried_hand
		# A bend guide is not a solved joint: feeding the joint back as its own
		# guide makes the elbow swivel outwards and lag behind each arm cycle.
		elbow_pole_pose[i] = elbow_pole_pose[i].lerp(elbow,blend)
		if defensive_jump() and action == "block": elbow_pole_pose[i] = elbow
		elbow_pose[i] = elbow_pose[i].lerp(elbow,blend)
		# Contact curves already ease through the real hand position. A second
		# low-pass filter would delay the palm stroke and the chest tuck.
		var contact_curve = defensive_jump() and (action == "block" or defense_caught)
		var dribble_contact = ordinary_dribble() and side == dribble_hand and rebound_release_left <= 0
		if cross_exit_left > 0 and ordinary_dribble() and side != dribble_hand:
			hand = body.to_local(global_position+cross_exit_hands[i]).lerp(hand,smoothstep(0,.16,.16-cross_exit_left))
		var cross_contact = crossing() and side == cross_from and (action_time < cross_wait or cross_phase() < .18)
		if crossing() and not cross_contact:
			var receive_rate = lerpf(32,122,smoothstep(.65,.95,cross_phase())) if side == cross_to else 32.0
			hand = hands[i].position.lerp(hand,1-exp(-delta*receive_rate))
		elif not contact_curve and not dribble_contact and not crossing():
			hand = carried_hand.lerp(hand,1-exp(-delta*42) if natural_run else blend)
		var arm_offset=hand-shoulder
		hand=shoulder+arm_offset.normalized()*clampf(arm_offset.length(),.05,UPPER_ARM_LENGTH+FOREARM_LENGTH-.002)
		var bend_guide: Vector3 = elbow_pole_pose[i] if natural_run or ordinary_dribble() or crossing() or (defensive_jump() and action == "block") else elbow_pose[i]
		elbow_pose[i] = solve_elbow(shoulder,hand,bend_guide-shoulder)
		CourtArt.align(arms[i][0], shoulder, elbow_pose[i])
		CourtArt.align(arms[i][1], elbow_pose[i], hand)
		elbows[i].position = elbow_pose[i]
		shoulder_caps[i].position = shoulder+(elbow_pose[i]-shoulder).normalized()*.025
		shoulder_caps[i].basis = arms[i][0].basis.orthonormalized().scaled(Vector3(.18,.23,.18))
		hands[i].position = hand
		hands[i].rotation.x = 1.0 if action == "shot" and action_time > 0.22 else -0.15
		hands[i].rotation.z = 0
		if ordinary_dribble() and side == dribble_hand:
			var bounce_t = fposmod(dribble_phase,TAU)/TAU
			hands[i].rotation.x = dribble_palm_pitch(bounce_t)
		if action == "layup" and side == dribble_hand: hands[i].rotation.x = lerpf(-.8, .65, smoothstep(.25, .40, action_time))
		if action == "dunk" and side == dribble_hand: hands[i].rotation.x = lerpf(-.1, 1.2, smoothstep(.30, .53, action_time))
		if action == "block" and defense_target_valid and side == dribble_hand:
			var elapsed = action_time-block_contact_time if block_contact else 0.0
			hands[i].rotation.x = lerpf(-.65,.65,smoothstep(.16,.34,action_time)) if not block_contact else lerpf(.45,1.20,smoothstep(0,.10,elapsed))
			hands[i].rotation.x = lerpf(hands[i].rotation.x,-.15,smoothstep(.20,.48,elapsed))
			hands[i].rotation.z = -side*.18
		if action == "rebound" and defense_target_valid:
			hands[i].rotation.z = side*lerpf(.52,.28,smoothstep(.08,.26,action_time))
			hands[i].rotation.y = -side*.50
			if defense_caught: hands[i].rotation.x = lerpf(-.35,.20,rebound_tuck_phase())
		else: hands[i].rotation.y = 0
		var ground_wrist = locomotion_pose() and jump < .05 and defense_weight < .1 and boxout_weight < .1 and not dribble_ended
		var flowing_wrist = ground_wrist or (ordinary_dribble() and side == dribble_hand)
		if flowing_wrist:
			var palm_basis: Basis = arms[i][1].basis.orthonormalized()
			var wrist_pitch = lerpf(-.15,-.08,run_swing_weight)
			var desired_palm = palm_basis*Basis(Vector3.RIGHT,wrist_pitch)
			var touch_weight = 1.0 if ordinary_dribble() and side == dribble_hand else 0.0
			var press_pitch = hands[i].rotation.x
			if crossing():
				touch_weight = 1-smoothstep(.18,.48,cross_phase()) if side == cross_from else smoothstep(.50,.85,cross_phase())
				press_pitch = lerpf(.65,-.25,smoothstep(.18,.85,cross_phase()))
				if action_time < cross_wait: press_pitch = dribble_palm_pitch(fposmod(cross_start_phase+action_time*cross_rate/TAU,1))
			# The chest may lean into a cut while the palm still presses down.
			var ball_palm = body.global_basis.orthonormalized().inverse()*Basis(Vector3.UP,rotation.y+upper.rotation.y)*Basis(Vector3.RIGHT,PI*.5+press_pitch)
			desired_palm = desired_palm.slerp(ball_palm,touch_weight)
			if crossing(): desired_palm = (body.global_basis.orthonormalized().inverse()*cross_start_palms[i]).slerp(desired_palm,smoothstep(0,.10,action_time))
			if cross_exit_left > 0 and ordinary_dribble(): desired_palm = (body.global_basis.orthonormalized().inverse()*cross_exit_palms[i]).slerp(desired_palm,smoothstep(0,.16,.16-cross_exit_left))
			# IK segment frames can change their roll near a straight elbow. Carry
			# the actual world wrist orientation through that change instead of
			# making the palm instantly inherit the new frame or hand role.
			if pose_ready and not teleported and delta > 0:
				var desired_world = (body.global_basis.orthonormalized()*desired_palm).get_rotation_quaternion()
				var wrist_angle = previous_palms[i].angle_to(desired_world)
				var wrist_blend = minf(1.0,20.0*delta/maxf(wrist_angle,.00001))
				desired_palm = body.global_basis.orthonormalized().inverse()*Basis(previous_palms[i].slerp(desired_world,wrist_blend))
			hands[i].basis = desired_palm.scaled_local(Vector3(.10,.145,.075))
		if action == "block" and defense_target_valid and side == dribble_hand:
			var palm_pitch = lerpf(.40,1.55,smoothstep(.14,.29,action_time))
			if block_contact:
				var elapsed = action_time-block_contact_time
				palm_pitch = lerpf(1.55,2.05,smoothstep(0,.10,elapsed))
				palm_pitch = lerpf(palm_pitch,.40,smoothstep(.20,.42,elapsed))
			var palm_frame = body.global_basis.orthonormalized().inverse()*Basis(Vector3.UP,defense_yaw)*Basis(Vector3.RIGHT,palm_pitch)*Basis(Vector3.FORWARD,-side*.08)
			hands[i].basis = palm_frame.scaled_local(Vector3(.10,.145,.075))
		thumbs[i].position = hand + Vector3(-side * .045, .015, .015)
		thumbs[i].rotation = Vector3(0,0,side*.4)
		cuffs[i].position = hand.lerp(elbow_pose[i], 0.22)
		cuffs[i].rotation = Vector3.ZERO
		if flowing_wrist or (action == "block" and defense_target_valid):
			var palm = hands[i].basis.orthonormalized()
			thumbs[i].position = hand+palm*Vector3(-side*.045,.015,.015)
			thumbs[i].basis = (palm*Basis(Vector3.FORWARD,side*.4)).scaled_local(Vector3(.047,.085,.045))
			cuffs[i].basis = arms[i][1].basis.orthonormalized().scaled(Vector3(.11,.065,.10))
		if side == dribble_hand: hand_world = body.to_global(hand)
	pose_ready = true
	# Rebuilding a ground stance at touchdown is not a world teleport. Keep
	# the visible wrists, shoulders and pose history through that contact.
	if skinned != null: skinned.update_pose(self,delta,speed,visual_teleport)
	if crossing() and cross_phase() >= .85 and not cross_received:
		var receiver=palm_position(1 if cross_to>0 else 0)
		if receiver.distance_to(cross_ball_world()+Vector3.UP*DRIBBLE_PALM)<.045:
			cross_received=true
			dribble_hand=cross_to
			hand_world=receiver

func ball_anchor(_time: float) -> Vector3:
	if held.owns(self):return (palm_position(0)+palm_position(1))*.5
	if action in ["pass","receive"]:
		var center = (palm_position(0)+palm_position(1))*.5
		return transfer_from.lerp(center,smoothstep(0,.10,action_time)) if action == "pass" else center
	if crossing(): return cross_ball_world()
	if stealing() and steal_success:
		return hand_world+steal_ball_offset*(1-smoothstep(0,.12,action_time-steal_contact_time))
	if action == "rebound" and defense_caught:
		return rebound_anchor()+defense_ball_offset*(1-smoothstep(0,.16,action_time-defense_catch_time))
	if action=="layup" and finish_ball_valid:
		return to_global(finish_ball_from).lerp(hand_world+Vector3.UP*.125,smoothstep(0,.10,action_time))
	if action in ["layup", "dunk"]: return hand_world + Vector3.UP * 0.12
	if action=="idle" and has_ball and dribble_ended:
		return (palm_position(0)+palm_position(1))*.5
	if action in ["gather","fake","shot"] and finish_kind in ["shot","layup"]:
		var pocket=palm_position(1 if dribble_hand>0 else 0)+Vector3.UP*.125
		if action=="gather" and gather_ball_valid:return to_global(gather_ball_from).lerp(pocket,smoothstep(0,.18,action_time))
		return pocket
	if action in ["gather", "fake", "shot"] or (has_ball and dribble_ended):
		return (palm_position(0)+palm_position(1))*.5+body.global_basis*Vector3(0,.04,.08)
	var local = dribble_local()
	var world = body.to_global(local)
	world.y = maxf(DRIBBLE_FLOOR, world.y)
	if cross_exit_left > 0 and ordinary_dribble(): world = (global_position+cross_exit_ball).lerp(world,smoothstep(0,.16,.16-cross_exit_left))
	if rebound_release_left > 0 and has_ball:
		world = rebound_release_from.lerp(world,smoothstep(0,.20,.20-rebound_release_left))
	return world
