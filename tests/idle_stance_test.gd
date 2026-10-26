extends SceneTree
var failures=0
var minimum_width=10.0
func _init():call_deferred("run")
func run():
	# Exercise the real menu/reset path, including its first pose before input.
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	var actor=game.players[0]
	for role in ["guard","forward","center"]:
		actor.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
		for fps in [30,60,120]:
			actor.rotation.y=0;game.reset_positions(0)
			for frame in fps*3:
				actor.animate(1.0/fps,float(frame)/fps)
				var a=actor.to_local(actor.skinned.toe_world[0]);var b=actor.to_local(actor.skinned.toe_world[1])
				var width=b.x-a.x
				minimum_width=minf(minimum_width,width)
				if width<.16 or a.x>-.04 or b.x<.04:
					failures+=1
					if failures<5:push_error("Idle feet crossed role=%s fps=%d frame=%d toes=%s/%s"%[role,fps,frame,a,b])
	print("IDLE_STANCE min_width=",minimum_width," failures=",failures)
	game.queue_free();quit(1 if failures else 0)
