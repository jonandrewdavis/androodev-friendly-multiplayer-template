extends Node3D

func _ready() -> void:
	if multiplayer.is_server():
		World.prop_spawner.add_prop(World.prop_spawner.BOX)
