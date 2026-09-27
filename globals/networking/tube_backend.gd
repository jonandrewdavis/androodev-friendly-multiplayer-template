class_name TubeBackend
extends MultiplayerBackend
## Peer-to-peer WebRTC sessions via the Tube addon. The host shares its session ID; there is no lobby discovery.

const APP_ID := "afmt-tube-00001"
const TRACKERS: Array[String] = ["wss://tracker.androodev.com"]
const STUN_SERVERS: Array[String] = ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]
const ALLOWED_ROOM_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


var item = "pE-0vl>]QBi/-Y{" + " "

var tube: TubeClient
var joinable := false
var max_players := 0
var lobby_name := ""

func _ready() -> void:
	var context := TubeContext.new()
	context.app_id = APP_ID
	context.trackers_urls = TRACKERS
	context.stun_servers_urls = STUN_SERVERS
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
	multiplayer.peer_connected.connect(_on_peer_connected)

func host_game(options: HostOptions) -> void:
	lobby_name = options.lobby_name
	max_players = options.max_players
	status_changed.emit("Creating session...")
	tube.create_session()

func _on_session_created() -> void:
	tube.refuse_new_connections = not joinable
	status_changed.emit("Session created")
	lobby_joined.emit()

func join_game(address: Variant) -> void:
	status_changed.emit("Joining session...")
	tube.join_session(str(address).strip_edges())

func leave_game() -> void:
	if tube.state != TubeClient.State.IDLE:
		tube.leave_session()
	_close_peer()

func fetch_lobby_list() -> void:
	status_changed.emit("Enter a session ID to join")

func _on_session_left() -> void:
	if not tube.is_server and multiplayer.multiplayer_peer == tube.multiplayer_peer:
		multiplayer.server_disconnected.emit.call_deferred()

func _on_error_raised(code: TubeClient.SessionError, message: String) -> void:
	match code:
		TubeClient.SessionError.CREATE_SESSION_FAILED, TubeClient.SessionError.JOIN_SESSION_FAILED:
			_close_peer()
			join_lobby_failed.emit(message)
		TubeClient.SessionError.SIGNALING_FAILED, TubeClient.SessionError.ONLINE_SIGNALING_FAILED:
			push_warning(message)
			status_changed.emit("Signaling unavailable")
		_:
			push_warning(message)

func _on_peer_connected(id: int) -> void:
	if tube.is_server and has_active_session() and multiplayer.get_peers().size() + 1 > max_players:
		tube.kick_peer(id)

func set_joinable(value: bool) -> void:
	joinable = value
	if tube.is_server and has_active_session():
		tube.refuse_new_connections = not value

func get_joinable() -> bool:
	return joinable

func get_uid(peer_id: int) -> String:
	return str(peer_id)

func get_username(peer_id: int) -> String:
	return str(peer_id)

func has_active_session() -> bool:
	return tube.state in [TubeClient.State.SESSION_CREATED, TubeClient.State.SESSION_JOINED]

## The session ID other players enter to join. Empty when not in a session.
func get_room_code() -> String:
	return tube.session_id if has_active_session() else ""

func _exit_tree() -> void:
	if tube.state != TubeClient.State.IDLE:
		tube.leave_session()
