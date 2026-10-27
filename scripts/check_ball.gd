extends RefCounted

# An out-of-bounds whistle is a visible stoppage, never a possession teleport.
var elapsed = 0.0
var returning = false
var return_time = 0.0
var return_from = Vector3.ZERO
var next_side = 0
var carrier = 0

static func spot(index: int, side: int, team_mode: bool) -> Vector3:
	if team_mode:
		var spots = [Vector3(0,0,1.9),Vector3(-4.3,0,-1.8),Vector3(2.7,0,-3.8)]
		return spots[index%3]+(Vector3.ZERO if (index<3)==(side==0) else Vector3(.45,0,-1.05))
	return (Vector3(-1.3,0,1.9) if index==0 else Vector3(-.5,0,-.1)) if side==0 else (Vector3(.4,0,-.3) if index==0 else Vector3(-1.1,0,2.5))

func begin(game, side: int, title: String, subtitle: String) -> void:
	elapsed = 0
	returning = false
	return_time = 0
	next_side = side
	carrier = side*3 if game.mode=="team" else side
	game.phase = "check"
	game.ball_owner = -1
	game.last_event = "turnover"
	game.trail_positions.clear()
	for player in game.players:
		player.has_ball = false
		player.dribble_ended = false
		player.boxing_out = false
		player.defending = false
	game.announce(title,("우리 팀 체크볼 · 자리로 돌아와 공을 받습니다." if side==0 else "상대 팀 체크볼 · 자리로 돌아와 수비를 준비합니다.") if title=="OUT OF BOUNDS" else subtitle,6)
	game.play_sound("whistle",-16)

func tick(game, delta: float) -> void:
	elapsed += delta
	game.time += delta
	game.feedback_timer = maxf(0,game.feedback_timer-delta)
	game.update_actions(delta)
	var ready = elapsed>.55
	for i in game.players.size():
		var player = game.players[i]
		if not player.visible: continue
		if player.defensive_jump(): player.position=game.Rules.clamp_to_court(player.defense_position())
		elif player.action in ["layup","dunk"] and player.finish_target_valid and player.action_time<=.82: player.position=game.Rules.clamp_to_court(player.finish_position())
		var offset = spot(i,next_side,game.mode=="team")-player.position
		offset.y = 0
		var desired = Vector2(offset.x,offset.z).limit_length()*minf(3.1,offset.length()*3)
		if elapsed<.45 or player.action!="idle": desired = Vector2.ZERO
		elif desired.length()>.2:
			# Opposing formations swap sides after a block-out. Give the walk
			# back a passing lane instead of pushing two bodies head-on forever.
			var direction=desired.normalized()
			for other in game.players:
				if other==player or not other.visible:continue
				var gap=Vector2(other.position.x-player.position.x,other.position.z-player.position.z)
				if gap.length()<1.05 and gap.dot(direction)>.18:
					desired+=Vector2(direction.y,-direction.x)*1.7*(1-smoothstep(.70,1.05,gap.length()))
		player.steer_motion(desired,12,delta)
		if desired.length()>.15: player.facing = atan2(desired.x,desired.y)
		elif player.action=="idle": game.face_target(i,game.HOOP if i==carrier else game.players[carrier].position)
		game.move_player(i,delta)
		if offset.length()>.16 or player.motion.length()>.2 or player.action!="idle": ready = false
		player.animate(delta,game.time)
	if game.mode=="team": game.team_match.separate()
	elif game.opponent_enabled(): game.separate_players()
	if game.mode=="team": game.team_match.update_labels()
	if not returning:
		game.ball_velocity.y -= 9.8*delta
		game.ball.position += game.ball_velocity*delta
		# Retain the visible exit, then settle the dead ball outside the line.
		game.ball_velocity.x = move_toward(game.ball_velocity.x,0,delta*9)
		game.ball_velocity.z = move_toward(game.ball_velocity.z,0,delta*9)
		if game.ball.position.y<game.Actor.DRIBBLE_FLOOR:
			game.ball.position.y=game.Actor.DRIBBLE_FLOOR
			game.ball_velocity.y=absf(game.ball_velocity.y)*.36 if absf(game.ball_velocity.y)>.5 else 0.0
		if ready:
			returning = true
			return_from = game.ball.position
			var receiver = game.players[carrier]
			receiver.action="receive";receiver.action_time=0;receiver.transfer_caught=false
			receiver.transfer_target=receiver.to_global(Vector3(0,1.18*receiver.height_ratio,.32))
	else:
		return_time += delta
		var receiver = game.players[carrier]
		var progress = clampf(return_time/.70,0,1)
		game.ball.position=return_from.lerp(receiver.transfer_target,smoothstep(0,1,progress))+Vector3.UP*sin(progress*PI)*.85
		if progress>=1:
			receiver.begin_pickup(game.ball.position)
			if game.mode=="team": game.team_match.reset(next_side,true)
			else: game.reset_positions(next_side,true)
			game.announce("CHECK BALL", "자리로 돌아와 체크볼을 이어갑니다.",1.3)
	game.previous_ball_position=game.ball.position
