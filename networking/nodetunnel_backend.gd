class_name NodeTunnelBackend
extends MultiplayerBackend

const RELAY_ADDRESS := "us-east.nodetunnel.io:8080"
const APP_ID := "0ahb6lkmhi5dtfi"
## How long to wait for the relay to answer before giving up.
const RELAY_TIMEOUT := 10.0
enum State {DISCONNECTED, AUTHENTICATING, READY, HOSTING, JOINING, IN_ROOM}

## Emitted when authentication finishes, whether it succeeded or not.
signal _relay_settled
## Emitted when a room list request finishes. [param ok] is false on timeout or disconnect.
signal _rooms_settled(ok: bool)

var peer: NodeTunnelPeer
var state := State.DISCONNECTED
var pending_action: Callable
var joinable := false
var max_players := 0
var lobby_name := ""
var generation := 0
var rooms_request := 0
var pending_admissions: Array[int] = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)
	_connect_to_relay()

func _connect_to_relay() -> void:
	peer = NodeTunnelPeer.new()
	peer.authenticated.connect(_on_authenticated.bind(generation), CONNECT_DEFERRED)
	peer.error.connect(_on_error.bind(generation), CONNECT_DEFERRED)
	peer.room_connected.connect(_on_room_connected.bind(generation), CONNECT_DEFERRED)
	peer.forced_disconnect.connect(_on_forced_disconnect.bind(generation), CONNECT_DEFERRED)
	peer.rooms_received.connect(_on_rooms_received.bind(generation), CONNECT_DEFERRED)
	peer.join_validation = _validate_join
	state = State.AUTHENTICATING
	var err := peer.connect_to_relay(RELAY_ADDRESS, APP_ID)
	if err != OK:
		_fail(error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connecting to relay...")
	_fail_after_timeout(State.AUTHENTICATING, "Relay connection timed out.")

## Fails if we are still in [param waiting_state] on the same peer after [constant RELAY_TIMEOUT].
func _fail_after_timeout(waiting_state: State, reason: String) -> void:
	var token := generation
	await get_tree().create_timer(RELAY_TIMEOUT).timeout
	if token == generation and state == waiting_state:
		_fail(reason)

func _ensure_relay(action: Callable) -> void:
	if state != State.DISCONNECTED and multiplayer.multiplayer_peer != peer:
		_reset_peer()
	match state:
		State.READY:
			action.call()
		State.AUTHENTICATING:
			pending_action = action
		State.DISCONNECTED:
			pending_action = action
			_connect_to_relay()
		_:
			push_error("NodeTunnel is busy (state %s)." % State.keys()[state])
			join_lobby_failed.emit("Already connected to a room.")

func _on_authenticated(token: int) -> void:
	if token != generation:
		return
	state = State.READY
	status_changed.emit("Relay ready")
	_relay_settled.emit()
	var action := pending_action
	pending_action = Callable()
	if action.is_valid():
		action.call()

func host_game(options: HostOptions) -> void:
	lobby_name = options.lobby_name
	max_players = options.max_players
	_ensure_relay(_host_room)

func _host_room() -> void:
	state = State.HOSTING
	peer.refuse_new_connections = true
	var err := peer.host_room(true, _encode_metadata())
	if err != OK:
		_fail(error_string(err))
		return
	_fail_after_timeout(State.HOSTING, "Creating the room timed out.")

func join_game(address: Variant) -> void:
	var code := str(address).strip_edges()
	if code.is_empty():
		join_lobby_failed.emit("Enter a room code.")
		return
	_ensure_relay(_join_room.bind(code))

func _join_room(code: String) -> void:
	state = State.JOINING
	var err := peer.join_room(code)
	if err != OK:
		_fail(error_string(err))
		return
	_fail_after_timeout(State.JOINING, "Joining the room timed out.")

func _on_room_connected(token: int) -> void:
	if token != generation:
		return
	state = State.IN_ROOM
	status_changed.emit("Room connected")
	lobby_joined.emit()

## Connects to the relay if needed, then waits for the room list.
## Rooms are reported through [signal lobby_found] before this returns.
func fetch_lobby_list() -> bool:
	if state == State.DISCONNECTED:
		_connect_to_relay()
	if state == State.AUTHENTICATING:
		await _relay_settled
	if state != State.READY:
		return false
	var err := peer.get_rooms()
	if err != OK:
		push_warning("Could not fetch rooms: " + error_string(err))
		return false
	rooms_request += 1
	_expire_rooms_request(rooms_request)
	return await _rooms_settled

func _expire_rooms_request(request: int) -> void:
	await get_tree().create_timer(RELAY_TIMEOUT).timeout
	if request == rooms_request:
		_rooms_settled.emit(false)

func _on_rooms_received(rooms: Array, token: int) -> void:
	if token != generation:
		return
	if state == State.IN_ROOM:
		return
	for room in rooms:
		if not room is Dictionary or not room.get("metadata") is String or not room.get("id") is String:
			continue
		var metadata: Variant = JSON.parse_string(room.metadata)
		if metadata is Dictionary and metadata.get("name") is String and (metadata.get("cur") is float or metadata.get("cur") is int) and (metadata.get("max") is float or metadata.get("max") is int):
			lobby_found.emit(room.id, metadata.name, int(metadata.cur), int(metadata.max))
	rooms_request += 1 # the answer arrived, so the pending timeout no longer applies
	_rooms_settled.emit(true)

func _encode_metadata() -> String:
	return JSON.stringify({"name": lobby_name, "cur": multiplayer.get_peers().size() + 1, "max": max_players})

func _on_peer_changed(id: int) -> void:
	if state == State.IN_ROOM and multiplayer.is_server():
		if id in multiplayer.get_peers() and not pending_admissions.is_empty():
			pending_admissions.pop_front()
		peer.update_room(_encode_metadata())

func _validate_join(_metadata: String) -> bool:
	var now := Time.get_ticks_msec()
	while not pending_admissions.is_empty() and now - pending_admissions[0] > 10000:
		pending_admissions.pop_front()
	if not joinable or peer.refuse_new_connections or multiplayer.get_peers().size() + pending_admissions.size() + 1 >= max_players:
		return false
	pending_admissions.append(now)
	return true

func set_joinable(value: bool) -> void:
	joinable = value
	if peer != null:
		peer.refuse_new_connections = not value

func get_joinable() -> bool:
	return joinable

## NodeTunnel has no persistent player identity, so this is the relay-assigned peer id.
## A new id is assigned on every connection, which means bans only last until the player rejoins.
func get_uid(peer_id: int) -> String:
	return str(peer_id)

func get_username(peer_id: int) -> String:
	return str(peer_id)

## The code other players enter to join this room. Empty when not in a room.
func get_room_code() -> String:
	return peer.room_id if peer != null and state == State.IN_ROOM else ""

func _on_error(message: String, token: int) -> void:
	if token != generation:
		return
	if state == State.IN_ROOM:
		push_warning(message)
	elif state in [State.AUTHENTICATING, State.HOSTING, State.JOINING]:
		_fail(message)
	else:
		_reset_peer()

func _on_forced_disconnect(token: int) -> void:
	if token != generation:
		return
	var was_in_room := state == State.IN_ROOM
	var was_server := multiplayer.is_server()
	_reset_peer()
	if was_in_room:
		if was_server:
			MultiplayerService.leave_game()
		else:
			multiplayer.server_disconnected.emit()
	else:
		join_lobby_failed.emit("Relay connection lost.")

func _fail(reason: String) -> void:
	_reset_peer()
	join_lobby_failed.emit(reason)

## Drops the current relay peer. Callbacks from it are ignored afterwards
## because they are bound to the old [member generation].
func _reset_peer() -> void:
	generation += 1
	pending_action = Callable()
	pending_admissions.clear()
	joinable = false
	state = State.DISCONNECTED
	if peer != null:
		peer.join_validation = Callable()
		if multiplayer.multiplayer_peer != peer: # replaced by something else, e.g. an offline game
			peer.close()
	_close_peer()
	peer = null
	status_changed.emit("Relay disconnected")
	# Unblock any fetch_lobby_list() still waiting on the old peer.
	_relay_settled.emit()
	rooms_request += 1
	_rooms_settled.emit(false)

func leave_game() -> void:
	_reset_peer()
	_connect_to_relay()

func _exit_tree() -> void:
	_reset_peer()
