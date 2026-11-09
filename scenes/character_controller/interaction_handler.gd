extends Node

@onready var player: PhysicsBody3D = self.get_parent()

var interact_length = 5.0

# Pick something up,
# Play a oneshot 

func _ready():
	if not player:
		push_warning("Player not set for: ", name)
		queue_free()
		return	
	set_process_input(is_multiplayer_authority())

# TODO: Check for inputs.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed('interact'):
		if player._is_facing_forward():
			_interact()

# shapecast
func _interact():
	var viewport_rect = get_viewport().get_visible_rect().size
	var raycast_start = player.camera.project_ray_origin(viewport_rect / 2)
	var raycast_end = raycast_start + player.camera.project_ray_normal(viewport_rect / 2) * interact_length
