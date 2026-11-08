extends RigidBody3D

@export_file("*.tscn") var scene_path: String
@export var damage: float
@export var source_id: int
@export var speed: float = 1.0
#@export var position: Vector3 = Vector3.ONE
@export var direction: Vector3 = Vector3.ONE
@export var lifetime: float

#var body_entered: Callable
#var tree_entered: Callable


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	if v.length_squared() > 0.01 and absf(v.normalized().y) < 0.99:
		state.transform.basis = Basis.looking_at(v)
		state.angular_velocity = Vector3.ZERO
