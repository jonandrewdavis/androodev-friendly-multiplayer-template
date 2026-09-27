extends MultiplayerBackend
## [b]A [MultiplayerBackend] using Steam lobbies and [SteamMultiplayerPeer].[/b][br][br]
## Requires the GodotSteam GDExtension (with MultiplayerPeer support) in [code]addons/[/code].
## [MultiplayerService] only loads this script when that extension is present, so it has no [code]class_name[/code].
## Hosting creates a Steam lobby, then a [SteamMultiplayerPeer] host; joining takes a lobby ID.


## 480 is Valve's public test app (Spacewar). Replace with your own app ID.
const APP_ID := 480
## Lobby data tag used to filter out other games that share [constant APP_ID].
const LOBBY_TAG := "androodev-fmt"
const NOT_RUNNING := "Steam is not running."


var steam_ready := false
var lobby_id := 0
var max_players: int
var lobby_name: String
var joinable := false


func _ready() -> void:
	steam_ready = Steam.steamInit(APP_ID, true)
	if not steam_ready:
		status_changed.emit(NOT_RUNNING)
		return
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	status_changed.emit("Steam ready")


func _exit_tree() -> void:
	leave_game()
	if steam_ready:
		Steam.lobby_created.disconnect(_on_lobby_created)
		Steam.lobby_joined.disconnect(_on_lobby_joined)
		Steam.lobby_match_list.disconnect(_on_lobby_match_list)


func host_game(options: HostOptions) -> void:
	if not steam_ready:
		join_lobby_failed.emit(NOT_RUNNING)
		return
	max_players = options.max_players
	lobby_name = options.lobby_name
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		join_lobby_failed.emit("Could not create Steam lobby (%d)." % result)
		return
	lobby_id = new_lobby_id
	Steam.setLobbyData(lobby_id, "name", lobby_name)
	Steam.setLobbyData(lobby_id, "tag", LOBBY_TAG)
	Steam.setLobbyJoinable(lobby_id, false)
	var peer := _new_peer()
	var err := peer.create_host()
	if err != OK:
		leave_game()
		join_lobby_failed.emit(error_string(err))
		return
	peer.refuse_new_connections = true
	multiplayer.set_multiplayer_peer(peer)
	lobby_joined.emit()


## Joins the Steam lobby with ID [param address] ([int] or numeric [String]).
func join_game(address: Variant) -> void:
	if not steam_ready:
		join_lobby_failed.emit(NOT_RUNNING)
		return
	var id := int(str(address).strip_edges())
	if id <= 0:
		join_lobby_failed.emit("Invalid lobby ID.")
		return
	Steam.joinLobby(id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	var owner_id := Steam.getLobbyOwner(joined_lobby_id)
	if owner_id == Steam.getSteamID():
		return # we created this lobby; _on_lobby_created handles it
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		join_lobby_failed.emit("Could not join Steam lobby (%d)." % response)
		return
	lobby_id = joined_lobby_id
	var peer := _new_peer()
	var err := peer.create_client(owner_id)
	if err != OK:
		leave_game()
		join_lobby_failed.emit(error_string(err))
		return
	multiplayer.set_multiplayer_peer(peer)
	lobby_joined.emit()


func leave_game() -> void:
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
	for id: int in lobbies:
		lobby_found.emit(id, Steam.getLobbyData(id, "name"), Steam.getNumLobbyMembers(id), Steam.getLobbyMemberLimit(id))


func set_joinable(value: bool) -> void:
	joinable = value
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		multiplayer.multiplayer_peer.refuse_new_connections = not value
	if lobby_id != 0:
		Steam.setLobbyJoinable(lobby_id, value)


func get_joinable() -> bool:
	return joinable


## UID is the peer's Steam ID, or [param peer_id] if it can't be resolved.
func get_uid(peer_id: int) -> Variant:
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		var steam_id: int = multiplayer.multiplayer_peer.get_steam64_from_peer_id(peer_id)
		if steam_id != 0:
			return steam_id
	return peer_id


func get_username(peer_id: int) -> String:
	var uid: Variant = get_uid(peer_id)
	if uid is int and uid != peer_id:
		return Steam.getFriendPersonaName(uid)
	return str(peer_id)


func _new_peer() -> SteamMultiplayerPeer:
	var peer := SteamMultiplayerPeer.new()
	peer.server_relay = true
	return peer
