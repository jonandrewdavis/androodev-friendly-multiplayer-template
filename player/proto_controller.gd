# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!
# Modified by SwAAn :P
class_name Player
extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var pause_menu: PauseMenu

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var camera: Camera3D = $Head/Camera3D
@onready var pause_menu_packed: PackedScene = preload("uid://uleq8uyf6eq7")


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	if is_multiplayer_authority():
		_capture_mouse()
	else:
		camera.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if is_multiplayer_authority():
		# Pausing
		if Input.is_key_pressed(KEY_ESCAPE):
			if pause_menu == null:
				_release_mouse()
				pause_menu = pause_menu_packed.instantiate()
				add_child(pause_menu)
			else:
				pause_menu.queue_free()
				pause_menu = null
				_capture_mouse()
		# Look around
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
			_rotate_look(event.relative)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Apply gravity to velocity
		if has_gravity:
			if not is_on_floor():
				velocity += get_gravity() * delta
		# Apply jumping
		if can_jump:
			if Input.is_action_just_pressed('jump') and is_on_floor():
				velocity.y = jump_velocity
		move_speed = base_speed
		# Apply desired movement to velocity
		if can_move:
			var input_dir := Input.get_vector('move_left', 'move_right', 'move_forward', 'move_backward')
			var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			if move_dir:
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
			else:
				velocity.x = move_toward(velocity.x, 0, move_speed)
				velocity.z = move_toward(velocity.z, 0, move_speed)
		else:
			velocity.x = 0
			velocity.y = 0
		# Use velocity to actually move
		move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func _rotate_look(rot_input: Vector2) -> void:
	assert(is_multiplayer_authority())
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
