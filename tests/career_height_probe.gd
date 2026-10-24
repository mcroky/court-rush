extends SceneTree
func _init():
	var mesh=load("res://assets/characters/rush_player.res")
	print("HUMAN_AABB=",mesh.get_aabb())
	quit()
