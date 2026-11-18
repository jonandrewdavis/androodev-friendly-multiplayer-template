extends Node

const KICK_REASON_KICKED := "You were kicked."
const KICK_REASON_BANNED := "You are banned from this lobby."
const REFUSE_REASON_FULL := "This lobby is full."
const REFUSE_REASON_NOT_JOINABLE := "This lobby is not joinable."
const KICK_GRACE_SECONDS := 1.0

enum State {
	IDLE,
	CONNECTING,
	IN_GAME,
}

const BACKEND_LABELS := { 
	MultiplayerBackend.Type.OFFLINE: "Offline",
	MultiplayerBackend.Type.ENET: "ENet (Localhost)",
	MultiplayerBackend.Type.TUBE: "Tube (WebRTC)",
	MultiplayerBackend.Type.NODETUNNEL: "NodeTunnel (Relay)",
	MultiplayerBackend.Type.STEAM: "Steam",
	MultiplayerBackend.Type.EOS: "Epic Online Services"
}

const ADDRESS_HINTS := {
	MultiplayerBackend.Type.OFFLINE: "Unavailable offline",
	MultiplayerBackend.Type.ENET: "IP address",
	MultiplayerBackend.Type.TUBE: "Session ID",
	MultiplayerBackend.Type.NODETUNNEL: "Room code",
	MultiplayerBackend.Type.STEAM: "Lobby ID",
	MultiplayerBackend.Type.EOS: "Lobby ID"
}

var backend: MultiplayerBackend
var state: State = State.IDLE
var max_players := 0
var banlist: Array
var kick_reason: String
var status_text: String

signal lobby_found(address: Variant, cur_players: int, max_players: int)
signal joining_lobby
signal lobby_joined
signal creating_lobby
signal join_lobby_failed(reason: String)
signal game_exited
#signal backend_changed(type: MultiplayerBackend.Type)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	GGT_GameConfig.game_config_changed.connect(_on_game_config_changed)
	#_init_backend()
	#set_backend.call_deferred()

## Modify for each [enum BackendType] you want to support.
func _init_backend(type: MultiplayerBackend.Type) -> void:
	match type:
		MultiplayerBackend.Type.ENET:
			backend = ENetBackend.new()
	backend.lobby_found.connect(lobby_found.emit)
	backend.lobby_joined.connect(lobby_joined.emit)
	backend.join_lobby_failed.connect(join_lobby_failed.emit)
	add_child(backend)

func host_game(options: HostOptions) -> void:
	assert(not multiplayer.has_multiplayer_peer() or multiplayer.get_multiplayer_peer() is OfflineMultiplayerPeer)
	creating_lobby.emit()
	if options.max_players == 1:
		multiplayer.set_multiplayer_peer(OfflineMultiplayerPeer.new())
	else:
		backend.host_game(options)


func join_game(address: Variant) -> void:
	assert(not multiplayer.has_multiplayer_peer() or multiplayer.get_multiplayer_peer() is OfflineMultiplayerPeer)
	joining_lobby.emit()
	backend.join_game(address)


func leave_game() -> void:
	assert(multiplayer.has_multiplayer_peer())
	backend.leave_game()
	banlist.clear()
	game_exited.emit()


func fetch_lobby_list() -> void:
	assert(not multiplayer.has_multiplayer_peer() or multiplayer.get_multiplayer_peer() is OfflineMultiplayerPeer)
	backend.fetch_lobby_list()


func set_joinable(joinable: bool) -> void:
	assert(multiplayer.is_server())
	backend.set_joinable(joinable)


func kick_player(peer_id: int) -> void:
	assert(multiplayer.is_server())
	_kick_player_rpc.rpc_id(peer_id, backend.get_uid(peer_id) not in banlist)


@rpc("authority", "call_remote", "reliable")
func _kick_player_rpc(kicked: bool) -> void:
	if kicked:
		kick_reason = KICK_REASON_KICKED
	else:
		kick_reason = KICK_REASON_BANNED
	leave_game()


func ban_player(peer_id: int) -> void:
	assert(multiplayer.is_server())
	banlist.append(backend.get_uid(peer_id))
	kick_player(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if not backend.get_joinable() or banlist.has(backend.get_uid(peer_id)):
		kick_player(peer_id)


func get_username(peer_id: int) -> String:
	return backend.get_username(peer_id)


func _on_game_config_changed():
	print(GGT_GameConfig.get_multiplayer_backend())
	
