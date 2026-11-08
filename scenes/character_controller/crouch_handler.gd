extends Node


@onready var head_drop_distance : float = 0.65
@onready var collider_drop_distance : float = 0.4
@onready var easing_type : Tween.TransitionType = Tween.TRANS_LINEAR



#TODO make these less hardcoded
@onready var player : PhysicsBody3D = self.get_parent()
@export var camera : Camera3D

@onready var collider : CollisionShape3D = player.get_node("Collider")
@onready var raycast_length : float = player.get_node("Collider").get_shape().height

var tween : Tween

# Absolute standing values, cached so crouch/uncrouch never drift.
var stand_collider_y : float
var stand_height : float
var stand_v_offset : float

#TODO Make the values dynamically adjust for bigger/smaller characters if possible.

func _ready() -> void:
	stand_collider_y = collider.position.y
	stand_height = collider.get_shape().height
	stand_v_offset = camera.v_offset


func _tween_to(crouched: bool) -> void:
	player.crouching = crouched
	player.stored_crouch_state = crouched
	if tween:
		tween.kill()
	var collider_y : float = stand_collider_y - (collider_drop_distance * 0.5 if crouched else 0.0)
	var height : float = stand_height - (collider_drop_distance if crouched else 0.0)
	var v_offset : float = stand_v_offset - (head_drop_distance if crouched else 0.0)
	tween = create_tween().set_parallel(true).set_trans(easing_type)
	tween.tween_property(collider, "position:y", collider_y, player.crouch_animation_time)
	tween.tween_property(collider.get_shape(), "height", height, player.crouch_animation_time)
	#Adjusts camera offset as setting the position directly interferes with the perspective script.
	tween.tween_property(camera, "v_offset", v_offset, player.crouch_animation_time)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player.input_allowed:
		if (player.swimming or player.floating) and Input.is_action_pressed(player.mapped_inputs["Crouch"]):
			player.velocity.y -= (player.jump_power * 0.02)

		if player.stored_crouch_state == false and player.crouch_allowed == true:
			if (Input.is_action_pressed(player.mapped_inputs["Crouch"]) and player.toggle_crouch == false) or (Input.is_action_just_pressed(player.mapped_inputs["Crouch"]) and player.toggle_crouch == true):
				if ((not player.swimming and not player.floating) or (player.swimming and player.is_on_floor())):
					_tween_to(true)
		elif player.stored_crouch_state == true:
			if (not Input.is_action_pressed(player.mapped_inputs["Crouch"]) and player.toggle_crouch == false) or (Input.is_action_just_pressed(player.mapped_inputs["Crouch"]) and player.toggle_crouch == true):
				#Raycast setup — exclude the player so it doesn't hit its own collider
				var space_state : PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
				var query : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(player.global_position, (player.global_position + Vector3(0, raycast_length, 0)))
				query.exclude = [player.get_rid()]
				var result : Dictionary = space_state.intersect_ray(query)
				#Stops player from uncrouching if under an obstacle
				if result.is_empty():
					_tween_to(false)
