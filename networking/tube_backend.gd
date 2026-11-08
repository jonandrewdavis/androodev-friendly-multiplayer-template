class_name TubeBackend
extends MultiplayerBackend
## Peer-to-peer WebRTC sessions via the Tube addon. Tube has no lobby discovery, so hosts publish their session ID to a [LobbyRegistry].

const APP_ID := "afmt-tube-00001"
const TRACKERS: Array[String] = ["wss://tracker.androodev.com"]
const TURN_URL := "https://api.androodev.com/turn_complete"
const ALLOWED_ROOM_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ICE_FETCH_TIMEOUT := 3.0

var tube: TubeClient
var registry := LobbyRegistry.new()
var joinable := false
var max_players := 0
var lobby_name := ""
## Identifies the latest host or join attempt, so one abandoned while fetching ICE servers doesn't carry on.
var attempt := 0

func _ready() -> void:
	var context := TubeContext.new()
	context.app_id = APP_ID
	context.trackers_urls = TRACKERS
	context.session_id_characters_set = ALLOWED_ROOM_CHARACTERS
	tube = TubeClient.new()
	tube.context = context
	# TubeClient installs its multiplayer_api on the tree; share the existing one so other listeners keep working.
	tube.multiplayer_api = get_tree().get_multiplayer()
	tube.session_created.connect(_on_session_created)
	tube.session_joined.connect(lobby_joined.emit)
	tube.session_left.connect(_on_session_left)
	tube.error_raised.connect(_on_error_raised)
	add_child(tube)
	add_child(registry)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	status_changed.emit("")

func host_game(options: HostOptions) -> void:
	lobby_name = options.lobby_name
	max_players = options.max_players
	status_changed.emit("Creating session...")
	attempt += 1
	var token := attempt
	await _fetch_ice_servers()
	if token == attempt:
		tube.create_session()

func _on_session_created() -> void:
	tube.refuse_new_connections = not joinable
	status_changed.emit("Session created")
	registry.publish({
		"app_id": APP_ID,
		"session_id": tube.session_id,
		"name": lobby_name,
		"cur_players": 1,
		"max_players": max_players,
		"joinable": joinable,
	})
	lobby_joined.emit()

func join_game(address: Variant) -> void:
	status_changed.emit("Joining session...")
	attempt += 1
	var token := attempt
	await _fetch_ice_servers()
	if token == attempt:
		tube.join_session(str(address).strip_edges().to_upper())

## On failure, carries on without them: players on the same network can usually still connect.
func _fetch_ice_servers() -> void:
	var http := HTTPRequest.new()
	http.timeout = ICE_FETCH_TIMEOUT
	add_child(http)
	if http.request(TURN_URL) != OK:
		http.queue_free()
		push_warning("Could not request ICE servers.")
		return
	var response: Array = await http.request_completed
	http.queue_free()
	var body: Variant = JSON.parse_string(response[3].get_string_from_utf8()) if response[0] == HTTPRequest.RESULT_SUCCESS else null
	if not (body is Dictionary and body.get("iceServers") is Array):
		push_warning("Could not fetch ICE servers.")
		return
	var servers: Array[Dictionary] = []
	servers.assign(body.iceServers)
	tube.context.turn_servers = servers

func leave_game() -> void:
	attempt += 1
	joinable = false
	registry.unpublish()
	if tube.state != TubeClient.State.IDLE:
		tube.leave_session()
	_close_peer()

func fetch_lobby_list() -> bool:
	for lobby: Dictionary in await registry.list(APP_ID):
		lobby_found.emit(lobby.session_id, lobby.name, int(lobby.cur_players), int(lobby.max_players))
	return true

func _on_session_left() -> void:
	_notify_session_lost.call_deferred()

## Tube also reports leaving on purpose, and Godot may have reported the same loss already: in both cases the service is idle by now.
func _notify_session_lost() -> void:
	if MultiplayerService.state == MultiplayerService.State.IN_GAME and not tube.is_server:
		multiplayer.server_disconnected.emit()

func _on_error_raised(code: TubeClient.SessionError, message: String) -> void:
	match code:
		TubeClient.SessionError.CREATE_SESSION_FAILED, TubeClient.SessionError.JOIN_SESSION_FAILED:
			_close_peer()
			join_lobby_failed.emit(message)
		TubeClient.SessionError.SIGNALING_FAILED, TubeClient.SessionError.ONLINE_SIGNALING_FAILED:
			push_warning(message)
			status_changed.emit("Signaling unavailable")
			if tube.state == TubeClient.State.CREATING_SESSION: # Tube waits forever here on platforms with local signaling
				tube.leave_session()
				_close_peer()
				join_lobby_failed.emit(message)
			else: # trackers don't reconnect, so players finding this lobby online couldn't reach it
				registry.unpublish()
		_:
			push_warning(message)

func _on_peer_connected(_id: int) -> void:
	_update_player_count()

func _on_peer_disconnected(_id: int) -> void:
	_update_player_count.call_deferred()

func _update_player_count() -> void:
	# Capped because a peer over the limit is counted until the service has removed it.
	registry.update({"cur_players": mini(multiplayer.get_peers().size() + 1, max_players)})

func set_joinable(value: bool) -> void:
	joinable = value
	if tube.is_server:
		tube.refuse_new_connections = not value
	registry.update({"joinable": value})

func get_joinable() -> bool:
	return joinable

func get_uid(peer_id: int) -> String:
	return str(peer_id)

func get_username(peer_id: int) -> String:
	return str(peer_id)

## The session ID other players enter to join. Empty when not in a session.
func get_room_code() -> String:
	return tube.session_id

func _exit_tree() -> void:
	registry.unpublish()
	if tube.state != TubeClient.State.IDLE:
		tube.leave_session()
