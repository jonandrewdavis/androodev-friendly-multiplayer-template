extends Node

@onready var body : PhysicsBody3D = get_parent()
@onready var head : Node3D = self.get_parent().get_node("Head")

## Visual model root shifted up while swimming (UAL swim clips put the pelvis ~1m below standing height)
@export var visual_root : Node3D
## How far visual_root is raised while swimming; 0 disables
@export var swim_visual_offset : float = 0.9
## Lerp rate (per second) for the swim visual offset
@export var swim_visual_offset_speed : float = 8.0

#Returns a list of true or false values checking if each position is in a water volume
func check_underwater_points(...points: Array) -> Array:
	
	var space_state : PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state

	var underwater_points := []
	var loop_index : int = 0
	
	for current_point : Vector3 in points:
		#print(current_point)
		
		var water_query : PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		water_query.collide_with_areas = true
		water_query.collide_with_bodies = false
		water_query.position = points[loop_index]
		
		var water_results : Array[Dictionary]
		water_results = space_state.intersect_point(water_query)
		
		#print(water_results)
		underwater_points.append(false)
		for current_result in water_results:
			if current_result["collider"]:
				if current_result["collider"].is_in_group("Water_Volume") or current_result["collider"].get_parent().is_in_group("Water_Volume"):
					underwater_points[loop_index] = true

		
		loop_index += 1
	return underwater_points
# Called when the node enters the scene tree for the first time.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var water_points : Array = check_underwater_points(body.global_position, head.global_position)
	#print(water_points)
	if water_points[0] and water_points[1]:
		if body.swimming_allowed:
			body.swimming = true
		body.add_to_group("Submerged")
	elif not water_points[0] and not water_points[1]:
		body.swimming = false
		body.remove_from_group("Submerged")

	_update_swim_visual_offset(delta)

func _update_swim_visual_offset(delta: float) -> void:
	if not visual_root:
		return
	var target : float = swim_visual_offset if body.swimming else 0.0
	var weight : float = 1.0 - exp(-swim_visual_offset_speed * delta)
	visual_root.position.y = lerpf(visual_root.position.y, target, weight)
