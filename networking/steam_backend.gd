extends MultiplayerBackend

const APP_ID := 480
const LOBBY_TAG := "androodev-fmt"
const NOT_RUNNING := "Steam is not running."
enum Phase {IDLE, HOSTING, JOINING, IN_LOBBY}

static var steam_ready := false

var phase := Phase.IDLE
var lobby_id := 0
var max_players := 0
var lobby_name := ""
var joinable := false

func _ready() -> void:
	if not steam_ready:
		var result: Dictionary = Steam.steamInitEx(APP_ID, true)
		steam_ready = result.get("status") == Steam.STEAM_API_INIT_RESULT_OK
		if not steam_ready:
			status_changed.emit("%s %s" % [NOT_RUNNING, result.get("verbal", "")])
			return
		Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.join_requested.connect(_on_join_requested)
	multiplayer.peer_connected.connect(_on_peer_connected)
	status_changed.emit("Steam ready")

func host_game(options: HostOptions) -> void:
	if not steam_ready:
		join_lobby_failed.emit(NOT_RUNNING)
		return
	max_players = options.max_players
	lobby_name = options.lobby_name
	phase = Phase.HOSTING
	status_changed.emit("Creating lobby...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if phase != Phase.HOSTING:
		if result == Steam.RESULT_OK:
			Steam.leaveLobby(new_lobby_id)
		return
	if result != Steam.RESULT_OK:
		_fail("Could not create Steam lobby (%d)." % result)
		return
	lobby_id = new_lobby_id
	Steam.setLobbyData(lobby_id, "name", lobby_name)
	Steam.setLobbyData(lobby_id, "tag", LOBBY_TAG)
	Steam.setLobbyJoinable(lobby_id, joinable)
	var peer := SteamMultiplayerPeer.new()
	var err := peer.host_with_lobby(lobby_id)
	if err != OK:
		_fail(error_string(err))
		return
	peer.refuse_new_connections = not joinable
	multiplayer.set_multiplayer_peer(peer)
	phase = Phase.IN_LOBBY
	status_changed.emit("Lobby created")
	lobby_joined.emit()

func join_game(address: Variant) -> void:
	if not steam_ready:
		join_lobby_failed.emit(NOT_RUNNING)
		return
	var id := str(address).strip_edges().to_int()
	if id <= 0:
		join_lobby_failed.emit("Invalid lobby ID.")
		return
	phase = Phase.JOINING
	lobby_id = id
	status_changed.emit("Joining lobby...")
	Steam.joinLobby(id)

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if phase != Phase.JOINING or joined_lobby_id != lobby_id:
		if phase == Phase.IDLE and response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
			Steam.leaveLobby(joined_lobby_id)
		return
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		_fail("Could not join Steam lobby (%d)." % response)
		return
	var peer := SteamMultiplayerPeer.new()
	var err := peer.connect_to_lobby(lobby_id)
	if err != OK:
		_fail(error_string(err))
		return
	multiplayer.set_multiplayer_peer(peer)
	phase = Phase.IN_LOBBY
	status_changed.emit("Lobby joined")
	lobby_joined.emit()

func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if phase == Phase.IDLE and not MultiplayerService.pending:
		MultiplayerService.join_game(requested_lobby_id)

func leave_game() -> void:
	phase = Phase.IDLE
	joinable = false
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
	_close_peer()

func fetch_lobby_list() -> void:
	if not steam_ready:
		return
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("tag", LOBBY_TAG, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
	if phase != Phase.IDLE:
		return
	for id: int in lobbies:
		lobby_found.emit(id, Steam.getLobbyData(id, "name"), Steam.getNumLobbyMembers(id), Steam.getLobbyMemberLimit(id))

func _on_peer_connected(id: int) -> void:
	if phase == Phase.IN_LOBBY and multiplayer.is_server() and multiplayer.get_peers().size() + 1 > max_players:
		(multiplayer.multiplayer_peer as SteamMultiplayerPeer).disconnect_peer(id)

func set_joinable(value: bool) -> void:
	joinable = value
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		multiplayer.multiplayer_peer.refuse_new_connections = not value
	if lobby_id != 0 and phase == Phase.IN_LOBBY:
		Steam.setLobbyJoinable(lobby_id, value)

func get_joinable() -> bool:
	return joinable

func get_uid(peer_id: int) -> Variant:
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		var steam_id: int = multiplayer.multiplayer_peer.get_steam_id_for_peer_id(peer_id)
		if steam_id > 0:
			return steam_id
	return peer_id

func get_username(peer_id: int) -> String:
	var uid: Variant = get_uid(peer_id)
	if uid is int and uid != peer_id:
		return Steam.getFriendPersonaName(uid)
	return str(peer_id)

func has_active_session() -> bool:
	return phase == Phase.IN_LOBBY

func get_room_code() -> String:
	return str(lobby_id) if phase == Phase.IN_LOBBY else ""

func _fail(reason: String) -> void:
	leave_game()
	join_lobby_failed.emit(reason)

func _exit_tree() -> void:
	if not steam_ready:
		return
	leave_game()
	Steam.lobby_created.disconnect(_on_lobby_created)
	Steam.lobby_joined.disconnect(_on_lobby_joined)
	Steam.lobby_match_list.disconnect(_on_lobby_match_list)
	Steam.join_requested.disconnect(_on_join_requested)
