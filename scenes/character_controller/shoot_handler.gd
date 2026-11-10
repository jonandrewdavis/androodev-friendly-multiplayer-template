extends Node3D
class_name ShootHandler

const UPPER_BODY := &"UpperBody"
const BOW_HOLD := &"BowHold"
const BOW_STATE_MACHINE := &"BowStateMachine"
const BOW_PULL_HOLD := &"Bow_Pull_Hold"
const BOW_RELEASE := &"Bow_Release"
const BOW_RELEASE_ANIM := &"Mesh2Motion/Bow_Release"

@onready var player : CharacterBody3D = owner.get_parent()
@onready var animation_sync : AnimationSync = %AnimationTree

func _ready() -> void:
	set_process_input(is_multiplayer_authority())
	animation_sync.animation_finished.connect(_on_animation_finished)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary"):
		animation_sync.fire_oneshot.rpc(UPPER_BODY)
		animation_sync.fire_oneshot.rpc(BOW_HOLD)
	elif event.is_action_released(&"primary"):
		if player._is_facing_forward() and _is_bow_held():
			animation_sync.travel.rpc(BOW_STATE_MACHINE, BOW_RELEASE)
			_shoot()
		else:
			animation_sync.fade_out_oneshot.rpc(UPPER_BODY)

func _is_bow_held() -> bool:
	return animation_sync.is_oneshot_active(BOW_HOLD) \
		and animation_sync.get_current_state(BOW_STATE_MACHINE) == BOW_PULL_HOLD

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == BOW_RELEASE_ANIM:
		animation_sync.fade_out_oneshot(UPPER_BODY)

func _shoot() -> void:
	var scene_path : String = World.prop_spawner.ARROW.resource_path
	World.prop_spawner.request_projectile.rpc_id(1, scene_path, global_position, _get_shoot_direction())

func _get_shoot_direction() -> Vector3:
	var viewport_center : Vector2 = get_viewport().get_visible_rect().size / 2
	return player.camera.project_ray_normal(viewport_center)
