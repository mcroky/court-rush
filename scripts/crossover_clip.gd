extends RefCounted

# Deliberate poses: bait, load, strike, transfer, receive, drive.
# Separate the authored silhouette from reach/possession constraints in actor.gd.
const KEYS = [0.0,.20,.48,.64,.86,1.0]
const DROP = [0.0,.04,.10,.09,.055,.045]
const LEAN = [0.0,.08,.04,-.07,-.06,-.03]
const TWIST = [0.0,-.14,-.10,.18,.30,.22]
const PITCH = [0.0,.055,.11,.085,.10,.13]
const SHIFT = [0.0,.02,.015,-.03,-.035,-.025]
const ROLL = [0.0,-.025,-.025,.035,.04,.025]

static func sample(phase: float) -> Dictionary:
	var at = clampf(phase,0,1)
	var index = 0
	while index < KEYS.size()-2 and at > KEYS[index+1]: index += 1
	var t = smoothstep(KEYS[index],KEYS[index+1],at)
	return {"drop":lerpf(DROP[index],DROP[index+1],t),"lean":lerpf(LEAN[index],LEAN[index+1],t),"twist":lerpf(TWIST[index],TWIST[index+1],t),"pitch":lerpf(PITCH[index],PITCH[index+1],t),"shift":lerpf(SHIFT[index],SHIFT[index+1],t),"roll":lerpf(ROLL[index],ROLL[index+1],t)}
