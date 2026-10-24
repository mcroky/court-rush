extends SceneTree

var failures = 0
var samples = 0
var pushing = 0
var worst_toe_drift = 0.0
var slowest_mean_speed = INF
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		if failures < 12: push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	for fps in [30,60,120]:
		for ball in [false,true]:
			for side in [-1.0,1.0]:
				game.start_mode("practice")
				var p = game.players[0]
				p.position = Vector3.ZERO
				p.facing = 0
				p.rotation.y = 0
				p.reset_stance()
				p.has_ball = ball
				p.dribble_hand = side
				p.ball_side = side
				var min_twist = INF
				var max_twist = -INF
				var toes = [Vector3.ZERO,Vector3.ZERO]
				var tracked = [false,false]
				var travel_speed = 0.0
				var travel_samples = 0
				for f in range(int(fps*2.4)):
					var dt = 1.0/fps
					p.steer_motion(Vector2(0,4.7),24,dt)
					p.position += p.movement_step(dt)
					p.animate(dt,f*dt)
					if f < fps*.65: continue
					travel_speed += p.last_visual_velocity.length()
					travel_samples += 1
					check(p.body.position.y < (-.225 if ball else -.18),"Running rose out of its low athletic stance")
					check(p.upper.rotation.x > .16,"Running chest stayed upright")
					min_twist = minf(min_twist,p.upper.rotation.y)
					max_twist = maxf(max_twist,p.upper.rotation.y)
					for i in range(2):
						if p.swinging[i]:
							tracked[i] = false
							continue
						var toe = p.shoes[i].to_global(p.LAYUP_TOE)
						if not tracked[i]:
							toes[i] = toe
							tracked[i] = true
						var drift = toe.distance_to(toes[i])
						worst_toe_drift = maxf(worst_toe_drift,drift)
						check(drift < .008,"Running support toe slid instead of pushing")
						if p.landing_push_pitch[i] > .12: pushing += 1
					check(not (p.swinging[0] and p.swinging[1]),"Low run launched both feet")
					samples += 1
				check(max_twist-min_twist > .24,"Running shoulders barely followed the opposing arms")
				var mean_speed = travel_speed/travel_samples
				slowest_mean_speed = minf(slowest_mean_speed,mean_speed)
				check(mean_speed > 4.5,"Contact constraints slowed sustained running")
	check(pushing > 100,"Normal running omitted the planted heel-to-toe push")
	print("LOW_RUN frames=",samples," toe_push_samples=",pushing," worst_toe_drift_m=",worst_toe_drift," slowest_mean_speed_mps=",slowest_mean_speed," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
