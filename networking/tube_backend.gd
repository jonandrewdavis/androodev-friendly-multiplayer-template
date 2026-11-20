class_name TubeBackend
extends MultiplayerBackend
## [b]Peer-to-peer WebRTC sessions using the Tube addon[/b][br][br]
## Allows us to establish a connection using a [WebRTCMultiplayerPeer]
## Tube does not have the ability to list lobbies. (WIP)

const TRACKERS: Array[String] = ["wss://tracker.androodev.com"] # Signaling server
const ANDROO_API: String = "https://api.androodev.com/turn_complete" # Helps get ICE & TURN
const ALLOWED_ROOM_CHARACTERS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# Unique AppID for Tube, fetched from project settings. Mine is "androodev-friendly-multiplayer-template".
# Change it in your project name so that we don't overlap. Shortens or lengthens to exactly 15 characters.
var app_id: String = ProjectSettings.get_setting("application/config/name").substr(0, 15).rpad(15, '0')
var tube_client: TubeClient
var joinable: bool = false


func _ready() -> void:
	lobby_hint = 'Session ID'
	var context := TubeContext.new()
	context.app_id = app_id
	context.trackers_urls = TRACKERS
	context.session_id_characters_set = ALLOWED_ROOM_CHARACTERS
	tube_client = TubeClient.new()
	tube_client.context = context
	tube_client.multiplayer_api = get_tree().get_multiplayer()
	tube_client.session_created.connect(lobby_joined.emit)
	tube_client.session_joined.connect(lobby_joined.emit)
	tube_client.session_left.connect(func(): _on_session_left.call_deferred())
	tube_client.error_raised.connect(_on_error_raised) 
	add_child(tube_client)


# NOTE: Tube ignores host options for now (no max players, disregards name)
func host_game(_options: HostOptions) -> void:
	await _fetch_ice_and_turn_servers()
	tube_client.create_session()
	print(tube_client.session_id)

func join_game(address: Variant) -> void:
	await _fetch_ice_and_turn_servers()
	tube_client.join_session(address) # A session ID
	
	
func leave_game() -> void:
	tube_client.leave_session()

# TODO: No lobbies for Tube yet
func fetch_lobby_list() -> bool:
	return true

func set_joinable(new_joinable_value: bool) -> void:
	# TODO: Should we do (tube_client.refuse_new_connections) ? 
	joinable = new_joinable_value

func get_joinable() -> bool:
	return joinable


func get_uid(peer_id: int) -> Variant:
	return str(peer_id)


func get_username(peer_id: int) -> String:
	return str(peer_id)


func _on_session_left() -> void:
	print(multiplayer.multiplayer_peer)
	print(multiplayer.multiplayer_peer  is WebRTCMultiplayerPeer)
	if multiplayer.multiplayer_peer is WebRTCMultiplayerPeer and not tube_client.is_server:
		multiplayer.server_disconnected.emit()


func _on_error_raised(code: TubeClient.SessionError, message: String) -> void:
	match code:
		TubeClient.SessionError.CREATE_SESSION_FAILED, \
		TubeClient.SessionError.JOIN_SESSION_FAILED:
			_close_peer()
			join_lobby_failed.emit(message)
		TubeClient.SessionError.SIGNALING_FAILED, \
		TubeClient.SessionError.ONLINE_SIGNALING_FAILED:
			push_warning(message)
			if tube_client.state == TubeClient.State.CREATING_SESSION:
				tube_client.leave_session()
				_close_peer()
				join_lobby_failed.emit(message)
		_: 
			push_warning(message)
			
func get_room_code():
	return tube_client.session_id

func _fetch_ice_and_turn_servers() -> void:
	var http := HTTPRequest.new()
	http.timeout = 3.0
	add_child(http)
	if http.request(ANDROO_API) != OK:
		http.queue_free()
		push_warning("Could not request ICE servers.")
		return
	var response: Array = await http.request_completed
	http.queue_free()
	var servers: Array[Dictionary] = []
	servers.assign(JSON.parse_string(response[3].get_string_from_utf8()).iceServers)
	tube_client.context.turn_servers = servers

func _exit_tree() -> void:
	if tube_client.state != TubeClient.State.IDLE:
		tube_client.leave_session()
