extends RefCounted

# One receiving contact, compression, passing pose and toe push per half cycle.
# The actor supplies its actual alternating foot phase, not elapsed time.
const KEYS = [0.0,.18,.50,.82,1.0]
const ARM = [1.0,.82,0.0,-.82,-1.0]
const LOAD = [0.0,.025,.008,-.008,0.0]
const DRIVE = [.015,.025,.060,.035,.015]

static func sample(stride: float) -> Dictionary:
	var cycle = fposmod(stride/PI,2)
	var phase = fposmod(cycle,1)
	var side = 1.0 if cycle < 1 else -1.0
	var index = 0
	while index < KEYS.size()-2 and phase > KEYS[index+1]: index += 1
	var t = smoothstep(KEYS[index],KEYS[index+1],phase)
	return {"arm":side*lerpf(ARM[index],ARM[index+1],t),"load":lerpf(LOAD[index],LOAD[index+1],t),"drive":lerpf(DRIVE[index],DRIVE[index+1],t)}
