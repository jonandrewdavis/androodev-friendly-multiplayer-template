extends Node

const KICK_REASON_KICKED := "You were kicked."
const KICK_REASON_BANNED := "You are banned from this lobby."
const REFUSE_REASON_FULL := "This lobby is full."
const REFUSE_REASON_NOT_JOINABLE := "This lobby is not joinable."
const KICK_GRACE_SECONDS := 1.0

#enum State {
#	ERROR,
#	IDLE,
#	READY,
#	CONNECTING,
#	IN_GAME,
#}

const BACKEND_LABELS := { 
	MultiplayerBackend.Type.OFFLINE: "Offline",
	MultiplayerBackend.Type.ENET: "ENet (Localhost)",
	MultiplayerBackend.Type.TUBE: "Tube (WebRTC)",
	MultiplayerBackend.Type.NODETUNNEL: "NodeTunnel (Relay)",
	MultiplayerBackend.Type.STEAM: "Steam",
	MultiplayerBackend.Type.EOS: "Epic Online Services"
}

const BACKEND_SCRIPTS := { 
	MultiplayerBackend.Type.OFFLINE: "res://networking/offline_backend.gd",
	MultiplayerBackend.Type.ENET: "res://networking/enet_backend.gd",
	MultiplayerBackend.Type.TUBE: "res://networking/tube_backend.gd",
	#MultiplayerBackend.Type.NODETUNNEL: "",
	#MultiplayerBackend.Type.STEAM: "",
	#MultiplayerBackend.Type.EOS: ""
}

var backend: MultiplayerBackend
var banlist: Array
var kick_reason: String
#var state: State = State.IDLE : set = _set_state

signal lobby_found(address: Variant, cur_players: int, max_players: int)
signal joining_lobby
signal lobby_joined
signal creating_lobby
signal join_lobby_failed(reason: String)
signal game_exited
#signal state_updated(state: State)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)	
	# Handles the backend options drop down
	GGT_GameConfig.game_config_changed.connect(_on_game_config_changed)
	_init_backend.call_deferred(GGT_GameConfig.get_multiplayer_backend())

## Modify for each [enum BackendType] you want to support.
func _init_backend(type: MultiplayerBackend.Type) -> void:
	if _is_backend_valid(type):
		backend = load(BACKEND_SCRIPTS[type]).new()
		backend.lobby_found.connect(lobby_found.emit)
		backend.lobby_joined.connect(lobby_joined.emit)
		backend.lobby_joined.connect(_on_lobby_joined_state)
		backend.join_lobby_failed.connect(join_lobby_failed.emit)
		backend.name = MultiplayerBackend.Type.keys()[type] # Identifies the node better
		add_child(backend, true)
	else:
		join_lobby_failed.emit("Backend not ready") # TODO: better signal?
		push_error("Backend not ready")
		#state = State.ERROR


func host_game(options: HostOptions) -> void:
	#if state != State.IDLE:
	#	return
	#state = State.CONNECTING
	creating_lobby.emit()
	backend.host_game(options)


func join_game(address: Variant) -> void:
	#if state != State.IDLE:
	#	return
	#state = State.CONNECTING
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
	if not multiplayer.is_server():
		return

	if not backend.get_joinable() or banlist.has(backend.get_uid(peer_id)):
		kick_player(peer_id)


func get_username(peer_id: int) -> String:
	return backend.get_username(peer_id)


# NOTE: We get notified our backend has updated, so we need to test if our current
# backend needs to be removed & set up new.
func _on_game_config_changed():
	var _index: int = GGT_GameConfig.get_multiplayer_backend()
	var next_backend_name = MultiplayerBackend.Type.keys()[_index]
	if not backend:
		_init_backend(_index)
	elif backend.name != next_backend_name:
		backend.queue_free()
		_init_backend(_index)

	#if GGT_GameConfig.get_multiplayer_backend():
	#	prints("DEBUG: Multiplayer backend changed", GGT_GameConfig.get_multiplayer_backend())

func _on_lobby_joined_state():
	pass
	#if state == State.IDLE:
		# Joining a game while your peer is IDLE should kick back to the menu.
		# You may have missed a host() or join() if this happens.

	#push_warning("Tried to join a game without having a multiplayer connection")
	#backend.leave_game() 
	#state = State.IN_GAME

func _is_backend_valid(type: MultiplayerBackend.Type):
	if type >= BACKEND_SCRIPTS.size():
		return false

	return true


#func _set_state(new_state: State):
#	state = new_state
#	state_updated.emit(new_state)
