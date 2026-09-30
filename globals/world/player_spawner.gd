class_name PlayerSpawner
extends MultiplayerSpawner

#const PLAYER_SCENE: PackedScene = preload("res://player/proto_controller.tscn")
#const PLAYER_SCENE: PackedScene = preload("res://player/PlayerCharacter/player_character_scene.tscn")
const PLAYER_CHARACTER = preload("uid://p8nowy1cujv1")

func _ready() -> void:
	self.add_spawnable_scene(PLAYER_CHARACTER.resource_path)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and MultiplayerService.backend.get_joinable() and not MultiplayerService.banlist.has(MultiplayerService.backend.get_uid(peer_id)):
		spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		remove_player(peer_id)

func spawn_player(id: int) -> void:
	if has_node(str(id)):
		return
	var player = PLAYER_CHARACTER.instantiate()
	player.name = str(id)
	add_child(player)

func remove_player(id: int) -> void:
	var player := get_node_or_null(str(id))
	if player:
		remove_child(player)
		player.queue_free()

func clear_players() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
