extends Node3D

# TODO: This extends "Gameplay" abstract class that picks what character you want, etc. etc. 
# Sets up start and end conditions

func _ready() -> void:
	if multiplayer.is_server():
		World.prop_spawner.add_prop(World.prop_spawner.BOX)

# TODO: Figure out how to do manual adding & removing of players :pain:
# OR? accept they must be just re-arranged, not created & destroyed
# (would prevent additional characters for additional game types)

func _enter_tree() -> void:
	pass
	#multiplayer.peer_connected.connect(World.player_spawner.spawn_player)

func _exit_tree() -> void:
	pass
	#if multiplayer.is_server():
		#multiplayer.peer_connected.disconnect(World.player_spawner.spawn_player)
