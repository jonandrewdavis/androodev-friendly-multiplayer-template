class_name PlayerSpawner
extends MultiplayerSpawner


const WARN_MSG := "Tried to remove a player that doesn't exist."


@onready var player_scene: PackedScene = preload("uid://fff2awjtd2uk")


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(peer_id: int) -> void:
	if is_multiplayer_authority():
		spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_multiplayer_authority():
		remove_player(peer_id)


func spawn_player(id: int) -> void:
	var player: Player = player_scene.instantiate()
	player.name = str(id)
	add_child.call_deferred(player)
	await player.tree_entered
	player.owner = self


func remove_player(id: int) -> void:
	var player: Player = find_child(str(id))
	if player:
		player.queue_free()
	else:
		push_warning(WARN_MSG)


func clear_players() -> void:
	for child: Player in get_children():
		child.queue_free()
