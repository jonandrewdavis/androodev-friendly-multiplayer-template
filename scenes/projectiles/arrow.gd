extends RigidBody3D

@export var damage: float = 10.0
@export var source_id: int
@export var speed: float = 20.0
@export var lifetime: float = 5.0

@onready var area_3d: Area3D = $Area3D

# TODO: Collison Layer management, probably good for a full game
# Not important for a demo

func _ready():
	area_3d.body_entered.connect(_on_hit)
	
	#add_collision_exception_with(World.player_spawner.get_node(str(source_id)))

	if lifetime and multiplayer.is_server():
		_start_lifetime()
		
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	if v.length_squared() > 0.01 and absf(v.normalized().y) < 0.99:
		state.transform.basis = Basis.looking_at(v)
		state.angular_velocity = Vector3.ZERO

func _on_hit(body_hit: Node3D):
	if body_hit.name == str(source_id):
		return 

	linear_velocity = Vector3.ZERO
	freeze = true

	var health := body_hit.get_node_or_null("Health_Component") as HealthComponent
	if health:
		health.damage(damage, source_id)

func _start_lifetime():
	await get_tree().create_timer(lifetime).timeout	
	if is_inside_tree():
		queue_free()
