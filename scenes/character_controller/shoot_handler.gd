extends Node3D
class_name ShootHandler

@export var player: CharacterBody3D

func _ready():
	if not player:
		push_warning("Player not set for: ", name)
		queue_free()
		return	
	
	set_process_input(is_multiplayer_authority())
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed('primary'):
		player.signal_oneshot.emit(OneShotHandler.UPPER_BODY, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		player.signal_oneshot.emit(OneShotHandler.BOW_HOLD, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif event.is_action_released('primary'):
		var oneshot_handler : OneShotHandler = player.get_node("%AnimationTree/Oneshot_Handler")
		if player._is_facing_forward() and oneshot_handler.is_bow_held():
			oneshot_handler.fire_bow()
			_shoot()
		else:
			oneshot_handler.cancel_bow()

func _shoot():
	var scene_path: String = World.prop_spawner.ARROW.resource_path
	var origin := global_position
	var direction := _get_shoot_direction()
	World.prop_spawner.request_projectile.rpc_id(1, scene_path, origin, direction)

func _get_shoot_direction() -> Vector3:
	var viewport_rect = get_viewport().get_visible_rect().size
	var raycast_start = player.camera.project_ray_origin(viewport_rect / 2)
	var raycast_end = raycast_start + player.camera.project_ray_normal(viewport_rect / 2) * 200
	return -(raycast_start - raycast_end).normalized()
