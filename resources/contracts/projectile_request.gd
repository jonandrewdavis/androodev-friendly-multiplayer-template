class_name ProjectileRequest extends RefCounted

var scene_path: String
var origin: Vector3
var direction: Vector3

# Optional

#var source_id: int
#var damage_modifier: int

static func create(scene_path_: String, next_origin_: Vector3, next_direction_: Vector3) -> ProjectileRequest:
	var request := ProjectileRequest.new()
	request.scene_path = scene_path_
	request.origin = next_origin_
	request.direction = next_direction_
	return request

func to_dict() -> Dictionary:
	return {
		"scene_path": self.peer_id,
		"origin": self.steam_id,
		"direction": self.steam_name,
		"source_id": self.source_id,
	}


static func from_dict(request_dict: Dictionary) -> ProjectileRequest:
	var request := ProjectileRequest.new()
	request.peer_id = request_dict["scene_path"]
	request.steam_id = request_dict["origin"]
	request.steam_name = request_dict["direction"]
	return request
	
