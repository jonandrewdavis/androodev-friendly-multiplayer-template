extends MultiplayerSpawner
class_name PropSpawner

const BOX = preload("uid://c38er141mkjb")
const ARROW = preload("uid://cpncw03ipoymd")

var PROPS_LIST = [
	BOX,
	ARROW,
]

func _ready() -> void:
	set_spawn_function(_custom_projectile_spawn)
	for prop: Resource in PROPS_LIST:
		add_spawnable_scene(prop.resource_path)

func add_prop(prop: Resource, position: Vector3 = Vector3.ZERO):
	var prop_to_add = prop.instantiate()
	prop_to_add.position = position
	add_child(prop_to_add, true)


@rpc("any_peer", 'call_local')
func request_projectile(scene_path: StringName, origin: Vector3, direction: Vector3):
	if multiplayer.get_remote_sender_id() == 0:
		push_error('RPC called without a .rpc')
		return
	
	var source_id := multiplayer.get_remote_sender_id()
	spawn([scene_path, origin, direction, source_id])

# NOTE: Spawn is always a variant. 
# TODO: Figure out how to type this better, better type contract?
# TODO: See: res://resources/contracts/projectile_request.gd
func _custom_projectile_spawn(data: Variant) -> Node:
	var scene_path = data[0] 
	var origin = data[1]
	var direction = data[2]
	var source_id = data[3]

	var new_projectile: RigidBody3D = load(scene_path).instantiate()
	
	# Required.
	new_projectile.position = origin
	new_projectile.linear_velocity = direction * new_projectile.speed
	new_projectile.basis = Basis.looking_at(direction)
	new_projectile.source_id = source_id

	return new_projectile
