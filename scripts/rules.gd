class_name BasketballRules
extends RefCounted

const HOOP = Vector3(0, 3.05, -5.65)
const THREE_DISTANCE = 6.75
const THREE_CORNER = 6.6
const COURT_HALF_WIDTH = 7.5
const COURT_BACK = -7.225
const COURT_FRONT = 6.775
const PLAYER_MARGIN = .30
const ROLE_PROFILES = {
	"guard": {"speed":4.7,"rebound_jump":.66,"rebound_travel":.34,"box_strength":1.0},
	"forward": {"speed":4.4,"rebound_jump":.76,"rebound_travel":.48,"box_strength":1.25},
	"center": {"speed":4.0,"rebound_jump":.86,"rebound_travel":.28,"box_strength":1.6}
}

static func role_profile(role: String) -> Dictionary:
	return ROLE_PROFILES.get(role,ROLE_PROFILES.guard)

static func clamp_to_court(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -COURT_HALF_WIDTH + PLAYER_MARGIN, COURT_HALF_WIDTH - PLAYER_MARGIN), pos.y, clampf(pos.z, COURT_BACK + PLAYER_MARGIN, COURT_FRONT - PLAYER_MARGIN))

static func ball_outside(pos: Vector3) -> bool:
	return absf(pos.x) > COURT_HALF_WIDTH or pos.z < COURT_BACK or pos.z > COURT_FRONT

static func finish_type(from: Vector3, velocity: Vector2) -> String:
	var offset = Vector2(HOOP.x - from.x, HOOP.z - from.z)
	var distance = offset.length()
	var approach = velocity.dot(offset.normalized())
	# Running layups engage earlier; the inner zone needs much less approach speed.
	if from.z < HOOP.z - 0.1 or distance > 3.0:
		return "shot"
	if distance <= 1.85 and absf(from.x) < 1.4 and (approach >= .75 or (distance <= 1.05 and velocity.length() < .8)):
		return "dunk"
	return "layup" if distance <= 2.6 or approach >= 1.2 else "shot"

static func release_bonus(hold: float) -> float:
	return 0.08 if hold >= 0.36 and hold <= 0.50 else 0.0

static func shot_points(from: Vector3) -> int:
	return 3 if beyond_arc(from, 0) else 2

static func beyond_arc(pos: Vector3, margin: float) -> bool:
	var offset = Vector2(pos.x - HOOP.x, pos.z - HOOP.z)
	var corner_end = sqrt(THREE_DISTANCE * THREE_DISTANCE - THREE_CORNER * THREE_CORNER)
	return absf(offset.x) >= THREE_CORNER + margin if offset.y < corner_end else offset.length() >= THREE_DISTANCE + margin

static func shot_probability(distance: float, contest: float, moving: bool) -> float:
	var base = 0.9 if distance < 2.5 else (0.81 if distance < 5.7 else 0.7)
	return clampf(base - contest * 0.58 - (0.12 if moving else 0.0), 0.12, 0.95)

static func is_clear(pos: Vector3) -> bool:
	return beyond_arc(pos, .12)

static func can_steal(attacker: Vector3, defender: Vector3, defending_direction: Vector3) -> bool:
	var offset = attacker - defender
	return offset.length() < 1.45 and offset.normalized().dot(defending_direction) > 0.3

static func guard_contact_extra(defender: Vector3,attacker: Vector3,yaw: float,weight: float) -> float:
	var offset=Vector2(attacker.x-defender.x,attacker.z-defender.z)
	if offset.length()<.001:return 0.0
	var front=offset.normalized().dot(Vector2(sin(yaw),cos(yaw)))
	# At most ten centimetres, fading to zero before an attacker gets the flank.
	return .10*clampf(weight,0,1)*smoothstep(.65,.95,front)

static func can_box_out(holder: Vector3, opponent: Vector3, target: Vector3) -> bool:
	var back = Vector2(opponent.x-holder.x, opponent.z-holder.z)
	var front = Vector2(target.x-holder.x, target.z-holder.z)
	return back.length() >= .30 and back.length() <= 1.25 and front.length() > .12 and back.normalized().dot(-front.normalized()) > .30

static func winner(scores: Array, time_left: float, settled: bool) -> int:
	if not settled:
		return -1
	if maxi(scores[0], scores[1]) >= 11 or time_left <= 0:
		if scores[0] != scores[1]:
			return 0 if scores[0] > scores[1] else 1
	return -1
