class_name PeerInfo extends RefCounted

var peer_id: int
var steam_id: int
var steam_name: String

static func create(new_peer_id: int, new_steam_id: int, new_steam_name: String) -> PeerInfo:
	var new_peer_info := PeerInfo.new()
	new_peer_info.peer_id = new_peer_id
	new_peer_info.steam_id = new_steam_id
	new_peer_info.steam_name = new_steam_name
	return new_peer_info


func to_dict() -> Dictionary:
	return {
		"peer_id": self.peer_id,
		"steam_id": self.steam_id,
		"steam_name": self.steam_name
	}


static func from_dict(peer_info_dict: Dictionary) -> PeerInfo:
	var new_peer_info := PeerInfo.new()
	new_peer_info.peer_id = peer_info_dict["peer_id"]
	new_peer_info.steam_id = peer_info_dict["steam_id"]
	new_peer_info.steam_name = peer_info_dict["steam_name"]
	return new_peer_info
	
