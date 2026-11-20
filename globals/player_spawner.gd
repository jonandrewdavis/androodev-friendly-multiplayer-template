extends MultiplayerSpawner
class_name PlayerSpawner

const PLAYER = preload("uid://cggocmcyxbaki")

func _ready():
	add_spawnable_scene(PLAYER.resource_path)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func spawn_player(peer_id: int):
	if not multiplayer.is_server():
		return 

	for player_body in get_children():
		if player_body.name == str(peer_id):
			return
	
	var new_player = PLAYER.instantiate()
	new_player.name = str(peer_id)
	add_child(new_player, true)

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		remove_player(peer_id)

func remove_player(peer_id: int):
	var player := get_node_or_null(str(peer_id))
	if player:
		remove_child(player)
		player.queue_free()
		
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
