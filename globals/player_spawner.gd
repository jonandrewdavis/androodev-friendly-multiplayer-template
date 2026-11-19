extends MultiplayerSpawner
class_name PlayerSpawner

const PLAYER = preload("uid://cggocmcyxbaki")

func _ready():
	add_spawnable_scene(PLAYER.resource_path)

func spawn_player(peer_id: int):
	if not multiplayer.is_server():
		return 

	for player_body in get_children():
		if player_body.name == str(peer_id):
			return
	
	var new_player = PLAYER.instantiate()
	new_player.name = str(peer_id)
	add_child(new_player, true)


func clear_players():
	pass
