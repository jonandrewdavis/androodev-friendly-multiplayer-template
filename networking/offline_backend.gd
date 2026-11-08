class_name OfflineBackend
extends MultiplayerBackend
## [b]Runs a one-player game with no networking.[/b][br][br]
## Used when no other backend is configured, and whenever a game is hosted with one player.
## Nothing can connect to this backend, so joining and lobby discovery are unavailable.


var joinable := false


func _ready() -> void:
	status_changed.emit("Offline")


func host_game(_options: HostOptions) -> void:
	multiplayer.set_multiplayer_peer(OfflineMultiplayerPeer.new())
	lobby_joined.emit()


func join_game(_address: Variant) -> void:
	join_lobby_failed.emit("Can't join a game while offline.")


func leave_game() -> void:
	joinable = false
	_close_peer()


func fetch_lobby_list() -> bool:
	return true


func set_joinable(value: bool) -> void:
	joinable = value


func get_joinable() -> bool:
	return joinable


func get_uid(peer_id: int) -> int:
	return peer_id


func get_username(peer_id: int) -> String:
	return str(peer_id)
