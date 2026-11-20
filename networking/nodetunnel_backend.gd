class_name NodeTunnelBackend
extends MultiplayerBackend
## [b]NodeTunnel is an ENetMultiplayerPeer using a relay[/b][br][br]
## It can connect on desktop platforms without opening ports. 
## Learn more and register here: https://www.nodetunnel.io/

var node_peer: NodeTunnelPeer
const node_tunnel_address := 'us-east.nodetunnel.io:8080'
const node_tunnel_id := 'ppo3n246k03udnn'

var joinable := false

func _ready():
	node_peer = NodeTunnelPeer.new()
	#node_peer.authenticated.connect(p)
	#node_peer.room_connected.connect(handle_room_ready)
	#node_peer.error.connect(handle_error_raised)
	node_peer.connect_to_relay(node_tunnel_address, node_tunnel_id)



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
