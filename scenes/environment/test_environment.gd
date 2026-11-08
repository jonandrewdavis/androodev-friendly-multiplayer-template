extends Node3D

func _ready() -> void:
	if multiplayer.is_server():
		World.prop_spawner.add_prop(World.prop_spawner.BOX)
		
		
		World.prop_spawner.add_prop(World.prop_spawner.SEAGULL, Vector3(randi_range(30, -30), 30, randi_range(30, -30))) 
		World.prop_spawner.add_prop(World.prop_spawner.SEAGULL, Vector3(randi_range(30, -30), 30, randi_range(30, -30)))
		World.prop_spawner.add_prop(World.prop_spawner.SEAGULL, Vector3(randi_range(30, -30), 30, randi_range(30, -30)))
		World.prop_spawner.add_prop(World.prop_spawner.SEAGULL, Vector3(randi_range(30, -30), 30, randi_range(30, -30)))
