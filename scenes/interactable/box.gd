extends RigidBody3D

# "Gravity gun" style pick ups
# Smoothing (interpolation) in laggy conditions) - lerp from a to b if you aren't the authority
# Give authority to who picks it up

@export var net_position: Vector3 
@export var net_quaternion: Quaternion

var smoothing_speed = 20.0
var snap_distance = 5.0

# server: 1
# CUBE: 1

# austrialia: 342345345
# 300ms

# JUST GIVE THE CUBE AUTHORITY AND LET THEM OWN WHERE IT IS
# clients can just say it

# - request a cube pickup (i want to be owner)
# - confirm the request
# - send back to the new owner
# - tell everyone else the new owner
# - new owner syncs

# account for:

# owner drops the cube
# owner disconnects 

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	if not is_multiplayer_authority():
		set_physics_process(false)
		freeze = true

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		net_position = global_position
		net_quaternion = global_basis.get_rotation_quaternion()

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return

	var weight := minf(smoothing_speed * delta, 1.0)

	if global_position.distance_to(net_position) > snap_distance:
		global_position = net_position
		global_basis = Basis(net_quaternion)
		return

	global_position = global_position.lerp(net_position, weight)
	global_basis = Basis(global_basis.get_rotation_quaternion().slerp(net_quaternion, weight))
