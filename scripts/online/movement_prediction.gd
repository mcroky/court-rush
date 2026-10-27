extends RefCounted
const Rules=preload("res://scripts/rules.gd")
## Predict only unobstructed running. Hands, shots and contacts remain authoritative.
static func target(x: float,z: float,speed: float) -> Vector2:
	return Vector2(x,z).limit_length()*speed

static func replay(state: Dictionary,slot: int,commands: Array) -> Vector3:
	var player: Dictionary=state.players[slot]
	var position=Vector3(player.position[0],player.position[1],player.position[2])
	if state.phase!="live" or not player.get("predictable",false): return position
	if position.distance_to(Vector3(state.players[1-slot].position[0],0,state.players[1-slot].position[2]))<1.6: return position
	var velocity=Vector2(player.motion[0],player.motion[1])
	var original=position
	var ack=int(state.acks[slot]) if state.get("acks",[]).size()==2 else -1
	var elapsed=0.0
	for i in commands.size():
		var command: Dictionary=commands[i]
		if int(command.seq)<=ack: continue
		if command.get("action",false): break
		var age=clampf(float(command.age),0,.2)
		var next_age=clampf(float(commands[i+1].age),0,.2) if i+1<commands.size() else 0.0
		var duration=minf(age-next_age,.2-elapsed)
		var desired=target(float(command.x),float(command.z),float(player.get("speed",Rules.role_profile("forward").speed)))
		while duration>.00001:
			var step=minf(duration,1.0/60)
			velocity=velocity.move_toward(desired,(24.0 if desired.length()>.01 else 35.0)*step)
			position=Rules.clamp_to_court(position+Vector3(velocity.x,0,velocity.y)*step)
			duration-=step; elapsed+=step
	return original+(position-original).limit_length(.5)
