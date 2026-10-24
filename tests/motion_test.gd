extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.facing = 0
	actor.rotation.y = 0
	actor.has_ball = true
	actor.animate(1.0 / 60, 0)
	var contacts = 0
	var max_reach = 0.0
	for frame in range(180):
		var previous = actor.feet_world.duplicate()
		var was_swinging = actor.swinging.duplicate()
		actor.position.z += 4.7 / 60
		actor.motion = Vector2(0, 4.7)
		actor.animate(1.0 / 60, frame / 60.0)
		for i in range(2):
			if not actor.swinging[i] and not was_swinging[i]:
				assert(actor.feet_world[i].distance_to(previous[i]) < .001, "stance foot must stay fixed in world space")
				contacts += 1
			assert(actor.shoes[i].global_position.distance_to(actor.feet_world[i]) < .001, "rendered foot must agree with world contact")
			var side = -1 if i == 0 else 1
			var hip = actor.body.to_global(Vector3(side * .145, 1.29, 0))
			var ankle = actor.body.to_global(actor.shoes[i].position + Vector3(0, .15, -.03))
			max_reach = maxf(max_reach, hip.distance_to(ankle))
	print("CONTACT_SAMPLES=", contacts)
	assert(contacts > 60, "sprint must include repeated planted contact intervals")
	assert(max_reach < .88, "full-speed stride must remain within scaled leg reach")
	actor.position = Vector3(7, 0, -3)
	actor.animate(1.0 / 60, 4)
	assert(actor.feet_world[0].distance_to(actor.global_position) < .4, "teleport must reset foot contacts")
	actor.action = "showcase"
	actor.has_ball = false
	actor.motion = Vector2.ZERO
	for frame in range(60): actor.animate(1.0 / 60, 5 + frame / 60.0)
	for i in range(2):
		var side = -1 if i == 0 else 1
		var hip = Vector3(side * .145, 1.29, 0)
		var ankle = actor.shoes[i].position + Vector3(0, .15, -.03)
		var knee = actor.solve_knee(hip, ankle)
		assert(knee.distance_to(hip.lerp(ankle, .51)) < .08, "relaxed showcase stance must not involuntarily squat")
	print("PASS: fixed stance contacts, rendered feet, reachable gait, teleport reset; samples=", contacts, " max reach=", max_reach)
	actor.queue_free()
	await process_frame
	quit()
