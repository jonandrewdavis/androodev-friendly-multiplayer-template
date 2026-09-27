extends Node


const KICK_REASON_KICKED := "You were kicked."
const KICK_REASON_BANNED := "You are banned from this lobby."
const CONFIG_SECTION := "multiplayer"
const CONFIG_KEY_BACKEND := "backend"


## Add a new entry for each [MultiplayerBackend].
enum BackendType {ENET, NODETUNNEL, STEAM}
const BACKEND_LABELS := {BackendType.ENET: "LAN (ENet)", BackendType.NODETUNNEL: "Online (NodeTunnel)", BackendType.STEAM: "Steam"}
const ADDRESS_HINTS := {BackendType.ENET: "IP address", BackendType.NODETUNNEL: "Room code", BackendType.STEAM: "Lobby ID"}


var backend: MultiplayerBackend
var backend_type: BackendType
## Backends whose dependencies are present, mapped to their script.
var backend_scripts: Dictionary = {}
var banlist: Array
var kick_reason: String
var status_text: String
## True while a host or join request is in flight.
var pending := false


signal lobby_found(address: Variant, cur_players: int, max_players: int)
signal joining_lobby
signal lobby_joined
signal creating_lobby
signal join_lobby_failed(reason: String)
signal game_exited
signal backend_changed(type: BackendType)
signal status_changed(text: String)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	backend_scripts[BackendType.ENET] = load("res://globals/networking/enet_backend.gd")
	backend_scripts[BackendType.NODETUNNEL] = load("res://globals/networking/nodetunnel_backend.gd")
	# Steam is optional: the backend script only parses when the GodotSteam extension is installed.
	if ClassDB.class_exists("SteamMultiplayerPeer"):
		backend_scripts[BackendType.STEAM] = load("res://globals/networking/steam_backend.gd")
	var saved: Variant = GGT_GameConfig.config.get_value(CONFIG_SECTION, CONFIG_KEY_BACKEND, BackendType.ENET)
	set_backend(saved if saved is int and backend_scripts.has(saved) else BackendType.ENET, false)


## Modify [constant BackendType] and [method _ready] for each backend you want to support.
func set_backend(type: BackendType, persist_choice := true) -> void:
	if not backend_scripts.has(type) or pending or (backend != null and backend.has_active_session()):
		return
	if backend != null:
		remove_child(backend)
		backend.free()
	backend_type = type
	backend = backend_scripts[type].new()
	backend.lobby_found.connect(lobby_found.emit)
	backend.lobby_joined.connect(_on_lobby_joined)
	backend.join_lobby_failed.connect(_on_join_lobby_failed)
	backend.status_changed.connect(_on_status_changed)
	add_child(backend)
	if persist_choice:
		GGT_GameConfig.config.set_value(CONFIG_SECTION, CONFIG_KEY_BACKEND, type)
		GGT_GameConfig.persist()
	backend_changed.emit(type)


func _on_lobby_joined() -> void:
	pending = false
	lobby_joined.emit()


func _on_join_lobby_failed(reason: String) -> void:
	if not pending: # e.g. a backend's background connection failed; nothing is waiting on it
		_on_status_changed(reason)
		return
	pending = false
	join_lobby_failed.emit(reason)


func _on_status_changed(text: String) -> void:
	status_text = text
	status_changed.emit(text)


func host_game(options: HostOptions) -> void:
	assert(not backend.has_active_session())
	if pending:
		return
	pending = true
	creating_lobby.emit()
	if options.max_players == 1:
		multiplayer.set_multiplayer_peer(OfflineMultiplayerPeer.new())
		_on_lobby_joined()
	else:
		backend.host_game(options)


func join_game(address: Variant) -> void:
	assert(not backend.has_active_session())
	if pending:
		return
	pending = true
	joining_lobby.emit()
	backend.join_game(address)


func leave_game() -> void:
	assert(multiplayer.has_multiplayer_peer())
	pending = false
	backend.leave_game()
	banlist.clear()
	game_exited.emit()


func fetch_lobby_list() -> void:
	assert(not backend.has_active_session())
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
	# peer_connected also fires on clients (for the server peer and other clients).
	# Only the server can decide joinability/bans, so bail out early elsewhere.
	if not multiplayer.is_server():
		return
	if not backend.get_joinable() or banlist.has(backend.get_uid(peer_id)):
		kick_player(peer_id)


func get_username(peer_id: int) -> String:
	return backend.get_username(peer_id)
