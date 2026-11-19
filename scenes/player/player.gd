extends CharacterBody3D


const SPEED = 10.0
const JUMP_VELOCITY = 4.5
const interpolation_speed = 5.0

@export var _networked_position: Vector3

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	if not is_multiplayer_authority():
		set_process(false)
		set_process_input(false)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		var weight : float = 1.0 - exp(-interpolation_speed * delta)
		global_position = global_position.lerp(_networked_position, weight)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	_networked_position = global_position
	move_and_slide()
