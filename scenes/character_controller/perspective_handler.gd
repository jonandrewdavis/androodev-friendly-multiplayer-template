extends Node

@export var player_main : PhysicsBody3D
@export var player_mesh : GeometryInstance3D
@export var camera_dolly : float = 0
@export var max_dolly : float = 5
## Zoom speed while a zoom button is held
@export var dolly_change_sensitivity : float = 50
## Distance moved per mouse wheel tick
@export var scroll_step : float = 0.5
@export var hide_model_in_first_person : bool = true

## Dolly distance below which the camera snaps into first person, to avoid clipping
var first_person_threshold : float = 1
var look_rotation : Vector2

@onready var head : SpringArm3D = get_parent().get_parent()
@onready var min_dolly : float = get_parent().position.z
@onready var head_offset : Vector3 = head.position
@onready var mapped_inputs : Dictionary = player_main.mapped_inputs

func _ready() -> void:
	# Detach the head so the player can be dragged around easier
	head.top_level = true
	head.add_excluded_object(player_main)
	look_rotation = Vector2(head.rotation.x, player_main.rotation.y)

	if not is_multiplayer_authority():
		set_process_input(false)
		set_process(false)
		return

	_update_mesh_visibility()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player_main.camera_control_allowed:
		rotate_look(event.relative, player_main.look_sensitivity, 0.01)

func _process(delta: float) -> void:
	head.position = player_main.position + head_offset
	if not player_main.camera_control_allowed:
		return

	_update_zoom(delta)
	_update_mesh_visibility()

	var look_vector : Vector2 = Input.get_vector(mapped_inputs["Look_Left"], mapped_inputs["Look_Right"], mapped_inputs["Look_Up"], mapped_inputs["Look_Down"])
	if look_vector != Vector2.ZERO:
		rotate_look(look_vector, player_main.look_sensitivity * 35, delta)

func _update_zoom(delta: float) -> void:
	var change : float = _zoom_input("Zoom_Out", delta) - _zoom_input("Zoom_In", delta) * 1.5
	if change == 0:
		return

	if change > 0 and camera_dolly < first_person_threshold:
		camera_dolly = first_person_threshold + change
	elif change < 0 and camera_dolly + change < first_person_threshold:
		camera_dolly = min_dolly
	else:
		camera_dolly += change

	camera_dolly = clampf(camera_dolly, min_dolly, max_dolly)
	head.spring_length = camera_dolly


func _zoom_input(action: String, delta: float) -> float:
	if Input.is_action_just_released(mapped_inputs[action]):
		return scroll_step
	if Input.is_action_pressed(mapped_inputs[action]):
		return dolly_change_sensitivity * 0.1 * delta
	return 0.0

func _update_mesh_visibility() -> void:
	if not player_mesh:
		return
	var first_person : bool = hide_model_in_first_person and head.get_hit_length() <= first_person_threshold
	player_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## Rotates the character to change look direction.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
func rotate_look(rot_input : Vector2, sensitivity : float, delta : float) -> void:
	var speed : float = sensitivity * 0.1 * delta
	var invert : float = -1.0 if player_main.invert_mouse else 1.0
	var max_angle : float = deg_to_rad(player_main.max_vertical_look_angle)
	look_rotation.x = clampf(look_rotation.x - rot_input.y * invert * speed, -max_angle, max_angle)
	look_rotation.y -= rot_input.x * speed

	head.transform.basis = Basis.from_euler(Vector3(look_rotation.x, look_rotation.y, 0))

	# Body follows the camera in first person, or when it isn't set to face movement
	if camera_dolly < first_person_threshold or not player_main.body_faces_movement:
		player_main.transform.basis = Basis(Vector3.UP, look_rotation.y)
