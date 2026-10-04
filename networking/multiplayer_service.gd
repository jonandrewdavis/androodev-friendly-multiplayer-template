extends Node


const KICK_REASON_KICKED := "You were kicked."
const KICK_REASON_BANNED := "You are banned from this lobby."
## Removed setting; older settings files may still contain it.
const LEGACY_CONFIG_SECTION := "multiplayer"

const ADDRESS_HINTS := {MultiplayerBackend.Type.ENET: "IP address", MultiplayerBackend.Type.NODETUNNEL: "Room code", MultiplayerBackend.Type.STEAM: "Lobby ID", MultiplayerBackend.Type.TUBE: "Session ID"}

var backend: MultiplayerBackend
var backend_type := MultiplayerBackend.Type.NONE

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
signal backend_changed(type: MultiplayerBackend.Type)
signal status_changed(text: String)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

	if ClassDB.class_exists("WebRTCPeerConnection"):
		backend_scripts[MultiplayerBackend.Type.TUBE] = load("res://networking/tube_backend.gd")

	if not OS.get_name() == "Web":
		_ready_desktop_backends()

	if GGT_GameConfig.config.has_section(LEGACY_CONFIG_SECTION):
		GGT_GameConfig.config.erase_section(LEGACY_CONFIG_SECTION)
		GGT_GameConfig.persist()

func _ready_desktop_backends():
	backend_scripts[MultiplayerBackend.Type.ENET] = load("res://networking/enet_backend.gd")

	if ClassDB.class_exists('NodeTunnelPeer'):
		backend_scripts[MultiplayerBackend.Type.NODETUNNEL] = load("res://networking/nodetunnel_backend.gd")

	if ClassDB.class_exists("SteamMultiplayerPeer"):
		backend_scripts[MultiplayerBackend.Type.STEAM] = load("res://networking/steam_backend.gd")


## Web builds can only use WebRTC, so they always run Tube.
func resolve_backend(requested: MultiplayerBackend.Type) -> MultiplayerBackend.Type:
	return MultiplayerBackend.Type.TUBE if OS.has_feature("web") else requested


## Modify [enum MultiplayerBackend.Type] and [method _ready] for each backend you want to support.
func set_backend(type: MultiplayerBackend.Type) -> void:
	type = resolve_backend(type)
	if not backend_scripts.has(type):
		push_error("Multiplayer backend %s is unavailable; select one on the Menu scene." % MultiplayerBackend.Type.find_key(type))
		return
	if (backend != null and type == backend_type) or pending or (backend != null and backend.has_active_session()):
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
