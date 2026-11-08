extends MultiplayerSpawner
class_name PropSpawner

const BOX = preload("uid://c38er141mkjb")
const ARROW = preload("uid://cpncw03ipoymd")
const SEAGULL = preload("uid://c2kxbafiemnpg")

var PROPS_LIST = [
	BOX,
	ARROW,
	SEAGULL,
]

func _ready() -> void:
	set_spawn_function(_custom_spawn_function)
	for prop: Resource in PROPS_LIST:
		add_spawnable_scene(prop.resource_path)

func add_prop(prop: Resource, position: Vector3 = Vector3.ZERO):
	var prop_to_add = prop.instantiate()
	prop_to_add.position = position
	add_child(prop_to_add, true)






@rpc("any_peer", 'call_local')
# TODO: Type everything that goes into here. ? can we call it locally
# as a player, so we don't have to dict_to_string it?
func add_projectile(projectile_resource: Variant):
	if multiplayer.get_remote_sender_id() == 0:
		push_error('RPC called without a .rpc')
		return
	spawn(projectile_resource)

# NOTE: Spawn is always a variant, but it's not a RPC... 
# There's not much benefit in this versus just "add_child()" if
# if the contract sucks.
func _custom_spawn_function(proj_string: Variant):
	var proj: ProjectileResource = dict_to_inst(proj_string)
	var new_projectile: RigidBody3D = load(proj.scene_path).instantiate()
	new_projectile.position = proj.position
	new_projectile.linear_velocity = proj.direction * proj.speed
	new_projectile.basis = Basis.looking_at(proj.direction)
	new_projectile.add_collision_exception_with(World.player_spawner.get_node(str(proj.source_id)))
	new_projectile.max_contacts_reported = 1
	new_projectile.contact_monitor = true
	if proj.body_entered: new_projectile.body_entered.connect(proj.body_entered.bind(new_projectile, proj))
	if proj.tree_entered: new_projectile.tree_entered.connect(proj.tree_entered.bind(new_projectile, proj))		
	if multiplayer.is_server():
		if proj.lifetime: new_projectile.tree_entered.connect(_bind_lifetime.bind(new_projectile, proj.lifetime))		

	return new_projectile

func _bind_lifetime(node: Node3D, lifetime: float):
	await get_tree().create_timer(lifetime).timeout	
	if node:
		node.queue_free()
