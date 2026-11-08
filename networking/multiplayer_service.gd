extends Node

const KICK_REASON_KICKED := "You were kicked."
const KICK_REASON_BANNED := "You are banned from this lobby."
const REFUSE_REASON_FULL := "This lobby is full."
const REFUSE_REASON_NOT_JOINABLE := "This lobby is not joinable."
const KICK_GRACE_SECONDS := 1.0

enum State {
	IDLE, ## Not in a game.
	CONNECTING, ## A host or join request is in flight.
	IN_GAME, ## Hosting or joined, including one-player games.
}

const ADDRESS_HINTS := {
	MultiplayerBackend.Type.OFFLINE: "Unavailable offline",
	MultiplayerBackend.Type.ENET: "IP address",
	MultiplayerBackend.Type.NODETUNNEL: "Room code",
	MultiplayerBackend.Type.STEAM: "Lobby ID",
	MultiplayerBackend.Type.TUBE: "Session ID",
	MultiplayerBackend.Type.EOS: "Lobby ID"
}

var backend: MultiplayerBackend
var backend_type := MultiplayerBackend.Type.OFFLINE
## The backend a one-player game replaced, restored when that game ends. OFFLINE if nothing was replaced.
var solo_return_type := MultiplayerBackend.Type.OFFLINE
## Why the last [method set_backend] failed. Empty once a backend starts.
var backend_error: String
var state := State.IDLE
## The player limit of the game this instance is hosting.
var max_players := 0
var banlist: Array
var kick_reason: String
var status_text: String

signal lobby_found(address: Variant, lobby_name: String, cur_players: int, max_players: int)
signal joining_lobby
signal lobby_joined
signal creating_lobby
signal join_lobby_failed(reason: String)
signal game_exited
signal backend_changed(type: MultiplayerBackend.Type)
## Emitted when a backend can't start because its setup is not in place.
signal backend_failed(reason: String)
signal status_changed(text: String)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

	_start_backend(MultiplayerBackend.Type.OFFLINE) # so backend is never null

	# Deferred so the autoloads after this one (e.g. EOS's HPlatform) are ready when the backend starts.
	set_backend.call_deferred(BackendSetup.get_configured_type())


## Starts [param type], replacing the current backend. Only works while [constant State.IDLE].
## If [param type] can't start, the current backend keeps running.
## Backends are configured in [BackendSetup].
func set_backend(type: MultiplayerBackend.Type) -> void:
	if type == backend_type or state != State.IDLE:
		return
	var setup_error := BackendSetup.get_setup_error(type)
	if not setup_error.is_empty():
		push_error(setup_error)
		backend_error = setup_error
		backend_failed.emit(setup_error)
		return
	backend_error = ""
	remove_child(backend)
	backend.free()
	_start_backend(type)


func _start_backend(type: MultiplayerBackend.Type) -> void:
	backend_type = type
	backend = load(BackendSetup.SCRIPTS[type]).new()
	backend.lobby_found.connect(lobby_found.emit)
	backend.lobby_joined.connect(_on_lobby_joined)
	backend.join_lobby_failed.connect(_on_join_lobby_failed)
	backend.status_changed.connect(_on_status_changed)
	_on_status_changed("")
	add_child(backend)
	backend_changed.emit(type)


func _on_lobby_joined() -> void:
	if state == State.IDLE:
		backend.leave_game()
		return
	state = State.IN_GAME
	lobby_joined.emit()


func _on_join_lobby_failed(reason: String) -> void:
	if state != State.CONNECTING:
		_on_status_changed(reason)
		return
	state = State.IDLE
	join_lobby_failed.emit(reason)


func _on_status_changed(text: String) -> void:
	status_text = text
	status_changed.emit(text)


func host_game(options: HostOptions) -> void:
	if state != State.IDLE:
		return
	if options.max_players == 1 and backend_type != MultiplayerBackend.Type.OFFLINE:
		solo_return_type = backend_type
		set_backend(MultiplayerBackend.Type.OFFLINE)
	max_players = options.max_players
	state = State.CONNECTING
	creating_lobby.emit()
	backend.host_game(options)


func join_game(address: Variant) -> void:
	if state != State.IDLE:
		return
	state = State.CONNECTING
	joining_lobby.emit()
	backend.join_game(address)


func leave_game() -> void:
	assert(multiplayer.has_multiplayer_peer())
	state = State.IDLE
	backend.leave_game()
	banlist.clear()
	game_exited.emit()
	if solo_return_type != MultiplayerBackend.Type.OFFLINE:
		var return_type := solo_return_type
		solo_return_type = MultiplayerBackend.Type.OFFLINE
		set_backend(return_type)


func fetch_lobby_list() -> bool:
	if state != State.IDLE:
		return false

	# NOTE: We do need to await fetch_lobby_list (it's a coroutine).
	# due to how @abstract works, we must supress this warning.
	@warning_ignore("redundant_await")
	return await backend.fetch_lobby_list()


func set_joinable(joinable: bool) -> void:
	assert(multiplayer.is_server())
	backend.set_joinable(joinable)


func kick_player(peer_id: int, reason := KICK_REASON_KICKED) -> void:
	assert(multiplayer.is_server())
	_kick_player_rpc.rpc_id(peer_id, reason)
	await get_tree().create_timer(KICK_GRACE_SECONDS).timeout
	if peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func _kick_player_rpc(reason: String) -> void:
	kick_reason = reason
	leave_game()


func ban_player(peer_id: int) -> void:
	assert(multiplayer.is_server())
	banlist.append(backend.get_uid(peer_id))
	kick_player(peer_id, KICK_REASON_BANNED)


func _on_peer_connected(peer_id: int) -> void:
	# peer_connected also fires on clients (for the server peer and other clients).
	# Only the server can decide joinability/bans, so bail out early elsewhere.
	if not multiplayer.is_server():
		return
	var reason := get_refusal_reason(peer_id)
	if not reason.is_empty():
		kick_player(peer_id, reason)


func get_refusal_reason(peer_id: int) -> String:
	if banlist.has(backend.get_uid(peer_id)):
		return KICK_REASON_BANNED
	if not backend.get_joinable():
		return REFUSE_REASON_NOT_JOINABLE
	if multiplayer.get_peers().size() + 1 > max_players:
		return REFUSE_REASON_FULL
	return ""


func get_username(peer_id: int) -> String:
	return backend.get_username(peer_id)
