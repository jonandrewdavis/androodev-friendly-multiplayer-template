class_name ENetBackend
extends MultiplayerBackend
## [b]An example implementation of [MultiplayerBackend].[/b][br][br]
## Allows us to establish a connection using [ENetMultiplayerPeer],
## hosting by passing in [HostOptions]; and joining by passing in an IP or MAC
## address as a [String].


const GAME_PORT := 3005
const SEARCH_PORT := 90210
const BROADCAST_ADDRESS := "255.255.255.255"
const GREETING_MESSAGE := "Anyone there?"


## Used by lobby hosts to listen for other instances looking for a game.
var search_server := UDPServer.new()
var search_peer := PacketPeerUDP.new()
var max_players: int
var lobby_name: String


func _ready() -> void:
	search_peer.set_dest_address(BROADCAST_ADDRESS, SEARCH_PORT)
	search_peer.set_broadcast_enabled(true)


## [b]Polls the Local Area Network for lobbies.[/b]
## If this instance is a host, we listen for packets from other instances searching for a lobby.
## If we receive one, we send back a packet containing our lobby's information.[br]
## As an instance looking for a game, we emit [signal lobby_found] if we receive a packet containing lobby information.
func _process(_delta: float) -> void:
	if search_server.is_listening():
		assert(multiplayer.is_server())
		search_server.poll()
		if search_server.is_connection_available():
			var ppeer := search_server.take_connection()
			var packet_str := "%s,%d,%d" % [lobby_name, multiplayer.get_peers().size() + 1, max_players]
			ppeer.put_packet(packet_str.to_utf8_buffer())
	while search_peer.get_available_packet_count() > 0:
		assert(not search_server.is_listening())
		var ip := search_peer.get_packet_ip()
		var packet := search_peer.get_packet().get_string_from_utf8().split(',')
		if ip != null and not ip.is_empty():
			lobby_found.emit(ip, packet[0], int(packet[1]), int(packet[2]))


## Hosts a lobby using the maximum number of players and lobby name specified in [param options].
func host_game(options: HostOptions) -> void:
	print("Creating ENet lobby...")
	max_players = options.max_players
	lobby_name = options.lobby_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, max_players - 1)
	if err == OK:
		multiplayer.set_multiplayer_peer(peer)
		lobby_joined.emit()
	else:
		push_error("Failed to create game host: ", str(err))
		join_lobby_failed.emit(str(err))


## Joins a lobby hosted at IP address [param address].
func join_game(address: Variant) -> void:
	var addr := address as String
	print("Joining ENet lobby at %s..." % addr)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, GAME_PORT)
	if err == OK:
		multiplayer.set_multiplayer_peer(peer)
		lobby_joined.emit()
	else:
		push_error("Failed to join game.", str(err))
		join_lobby_failed.emit(str(err))


func leave_game() -> void:
	_close_peer()
	search_server.stop()


## Sends a packet over the [constant BROADCAST_ADDRESS] to request lobby information from other instances on the LAN.
func fetch_lobby_list() -> void:
	assert(not search_server.is_listening())
	assert(not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	print_debug("Searching For Games over LAN...")
	search_peer.put_packet(GREETING_MESSAGE.to_utf8_buffer())


func set_joinable(joinable: bool) -> void:
	print_debug("Setting ENet Lobby Joinable=" + str(joinable))
	if joinable:
		search_server.listen(SEARCH_PORT) # for some reason setting the bind address to the broadcast address doesn't work here
	else:
		search_server.stop()


func get_joinable() -> bool:
	assert(multiplayer.is_server())
	return search_server.is_listening()


## UID is IP or MAC address.
## If for some reason we can't find that, just return [param peer_id] as a [String].
func get_uid(peer_id: int) -> String:
	var peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
	if peer:
		return peer.get_remote_address()
	else:
		return str(peer_id)


func get_username(peer_id: int) -> String:
	return str(peer_id)
