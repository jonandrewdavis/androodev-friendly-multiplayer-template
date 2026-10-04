extends Node

#TODO make a subnode instead of a script for the main node
@onready var player_controller : Node = get_parent().get_parent()
@export var animation_tree : AnimationTree

## Adjust these to help make each animation's feet match the ground (prevents sliding)
@export var walk_anim_speed : float = 3.0
@export var sprint_anim_speed : float = 9.0
@export var crouch_walk_anim_speed : float = 1.5

func _ready():
	if not is_multiplayer_authority():
		set_process(false)

func _process(_delta: float) -> void:
	apply(get_ground_speed())

## Horizontal speed only, so jumping/falling doesn't speed up the legs.
func get_ground_speed() -> float:
	return Vector2(player_controller.velocity.x, player_controller.velocity.z).length()

## Scales animation speed with player speed when appropriate
func apply(ground_speed : float) -> void:
	animation_tree.set("parameters/Walk/Character_Speed_Scale/scale", ground_speed / walk_anim_speed)
	animation_tree.set("parameters/Sprint/Character_Speed_Scale/scale", ground_speed / sprint_anim_speed)
	animation_tree.set("parameters/Crouch Walk/Character_Speed_Scale/scale", ground_speed / crouch_walk_anim_speed)
