extends MultiplayerBackend

signal logged_in

const GAME_SOCKET_NAME = "ANDROOFRIENDLY"
const LOBBY_BUCKET = "default"
const LOBBY_NAME_ATTR = "lobby_name"

## EOS can only be set up once per run, but this backend is recreated after a one-player game.
static var platform_ready := false

var joinable := true
var current_lobby: HLobby = null

func _ready() -> void:
	# Setup HEOS Logs
	HLog.log_level = HLog.LogLevel.VERBOSE

	if not platform_ready:
		platform_ready = await _setup_platform()
		if not platform_ready:
			push_error("Failed to setup EOS. See logs for more details")
			status_changed.emit("EOS setup failed.")
			return

	if not HAuth.product_user_id.is_empty():
		return

	await _login()


func _setup_platform() -> bool:
	var credentials = HCredentials.new()
	credentials.product_name = "Friendly Multiplayer Template"
	credentials.product_version = "1.0"
	credentials.product_id = "e1fe900bdca247519f5498fb33ff8460"
	credentials.sandbox_id = "b654af373679432b9f0d0ac8b9f268a8"
	credentials.deployment_id = "acb3d3a3f71f4a6d8522284d10b7ac48"
	credentials.client_id = "xyza7891G3JUsOXcy3ydEewNLIFNf6dQ"
	credentials.client_secret = "IykHkFKl01dzcQoiRufDIgxxa24dptn5m0G9vCRYmq0"

	# optional
	#credentials.encryption_key = "ENCRYPTION_KEY_HERE"

	return await HPlatform.setup_eos_async(credentials)


func _login() -> void:
	# Setup Logs from EOS
	#HPlatform.log_msg.connect(_on_eos_log_msg)
	#var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
	#if not EOS.is_success(log_res):
		#printerr("Failed to set logging level")
		#return

	HAuth.logged_in.connect(_on_logged_in)

	# During development use the devauth tool to login
	if OS.is_debug_build():
		#HAuth.auth_login_scope_flags = EOS.Auth.ScopeFlags.BasicProfile
		#await get_tree().process_frame
		#await HAuth.login_devtool_async("localhost:4545", "AndrooDev22")
		# Instances on one machine share a device ID; retry if another instance wins the race
		while not await HAuth.login_anonymous_async("Player%d" % (randi() % 1000)):
			await get_tree().create_timer(3.0).timeout
	else:
		## Or login without any credentials
		await HAuth.login_anonymous_async('cool guy')


func _on_logged_in():
	print("Logged in successfully: product_user_id=%s" % HAuth.product_user_id)


func host_game(options: HostOptions) -> void:
	var invite_only = false
	var create_opts := EOS.Lobby.CreateLobbyOptions.new()
	create_opts.bucket_id = LOBBY_BUCKET
	create_opts.max_lobby_members = options.max_players
	create_opts.presence_enabled = false
	create_opts.enable_rtc_room = false
	create_opts.permission_level = EOS.Lobby.LobbyPermissionLevel.InviteOnly if invite_only else EOS.Lobby.LobbyPermissionLevel.PublicAdvertised

	var lobby := await HLobbies.create_lobby_async(create_opts)
	prints("Lobby result:", lobby)
	if not lobby:
		join_lobby_failed.emit("Failed to create lobby!")
		return

	lobby.add_attribute(LOBBY_NAME_ATTR, options.lobby_name)
	if not await lobby.update_async():
		push_warning("Failed to set lobby name attribute")

	var peer = EOSGMultiplayerPeer.new()
	var err := peer.create_server(GAME_SOCKET_NAME)
	if err == OK:
		multiplayer.set_multiplayer_peer(peer)
		current_lobby = lobby
		set_joinable(true)
		lobby_joined.emit()
	else:
		push_error("Failed to create game host: ", str(err))
		join_lobby_failed.emit(str(err))

func join_game(address: Variant) -> void:
	var remote_puid := address as String
	var joined_lobby: HLobby = await HLobbies.join_by_id_async(remote_puid)
	if joined_lobby == null:
		printerr("FAILED: Joining EOS lobby at %s..." % address)
		return
	print("Joining EOS lobby at %s..." % joined_lobby.owner_product_user_id)
	var peer = EOSGMultiplayerPeer.new()
	var err := peer.create_client(GAME_SOCKET_NAME, joined_lobby.owner_product_user_id)
	if err == OK:
		multiplayer.set_multiplayer_peer(peer)
		current_lobby = joined_lobby
		lobby_joined.emit()
	else:
		push_error("Failed to join game.", str(err))
		join_lobby_failed.emit(str(err))

func leave_game() -> void:
	joinable = false
	_close_peer() # before the await: a new game may have started by the time it finishes
	if current_lobby and current_lobby.is_valid():
		await current_lobby.leave_async()

func fetch_lobby_list() -> bool:
	var lobbies = await HLobbies.search_by_bucket_id_async(LOBBY_BUCKET)
	if not lobbies:
		push_warning("Could not fetch lobbies")
		return false
	
	for lobby: HLobby in lobbies:
		var lobby_name: String = lobby.get_attribute(LOBBY_NAME_ATTR).get("value", lobby.lobby_id)
		lobby_found.emit(lobby.lobby_id, lobby_name, lobby.members.size(), lobby.max_members)
	
	return true
	
func set_joinable(value: bool) -> void:
	joinable = value
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.refuse_new_connections = not value
		
func get_joinable() -> bool:
	return joinable

func get_uid(_peer_id: int) -> Variant:
	return HAuth.product_user_id
	
func get_username(_peer_id: int) -> String:
	return HAuth.display_name
