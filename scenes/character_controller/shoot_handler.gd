extends Node3D
class_name ShootHandler

@export var player: CharacterBody3D
@export var CURRENT_PROJECTILE: ProjectileResource

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
	var new_arrow: ProjectileResource = CURRENT_PROJECTILE
	new_arrow.position = global_position
	new_arrow.direction = _get_shoot_direction()
	new_arrow.body_entered = _on_hit
	# TODO: Distinguish between player with "1" and NPCs (enemies) with "1"
	new_arrow.source_id = get_multiplayer_authority() 
	World.prop_spawner.add_projectile.rpc_id(1, inst_to_dict(new_arrow))

# We can't send a callable.
func _on_hit(body_hit: Node3D, projectile: RigidBody3D, projectile_resource: ProjectileResource):
	projectile.freeze = true
	if multiplayer.is_server():
		var health := body_hit.get_node_or_null("Health_Component") as HealthComponent
		if health:
			health.damage(projectile_resource.damage, projectile_resource.source_id)

func _get_shoot_direction():
	var viewport_rect = get_viewport().get_visible_rect().size
	var raycast_start = player.camera.project_ray_origin(viewport_rect / 2)
	var raycast_end = raycast_start + player.camera.project_ray_normal(viewport_rect / 2) * 200
	return -(raycast_start - raycast_end).normalized()
