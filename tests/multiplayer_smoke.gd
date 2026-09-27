extends Node

var mode := ""
var failure := ""
var exits := 0
var joined := 0
var discovered := false
var original_backend: int
var scenario_completed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("SMOKE FAIL: " + message)
		get_tree().quit(1)

func _wait_until(predicate: Callable, seconds := 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	return predicate.call()

func _in_session() -> bool:
	return not MultiplayerService.pending and MultiplayerService.backend.has_active_session()

func _address() -> String:
	var backend := MultiplayerService.backend
	return (backend as NodeTunnelBackend).get_room_code() if backend is NodeTunnelBackend else "127.0.0.1"

func _run() -> void:
	get_tree().current_scene = null
	var args := OS.get_cmdline_user_args()
	mode = args[0] if not args.is_empty() else "offline"
	original_backend = MultiplayerService.backend_type
	MultiplayerService.join_lobby_failed.connect(func(reason: String) -> void: failure = reason)
	MultiplayerService.game_exited.connect(func() -> void: exits += 1)
	MultiplayerService.lobby_joined.connect(func() -> void: joined += 1)
	MultiplayerService.lobby_found.connect(func(_address: Variant, lobby_name: String, _cur: int, _max: int) -> void:
		if lobby_name == "Smoke Test":
			discovered = true)
	if mode in ["offline", "visual"]:
		await _offline()
	else:
		MultiplayerService.set_backend(MultiplayerService.BackendType.NODETUNNEL if mode.begins_with("relay") else MultiplayerService.BackendType.ENET, false)
		if mode.contains("session"):
			await _session()
		elif mode.contains("capacity") or mode.contains("full"):
			await _capacity()
		elif mode == "relay-invalid":
			MultiplayerService.join_game("INVALID-ROOM-CODE")
			_check(await _wait_until(func() -> bool: return not failure.is_empty()), "invalid code fails")
			_check(not MultiplayerService.pending and not MultiplayerService.backend.has_active_session(), "invalid code resets state")
			scenario_completed = true
		elif mode.ends_with("host"):
			await _host()
		else:
			await _client()
	_check(scenario_completed, "scenario completed without script errors")
	if not scenario_completed:
		return
	MultiplayerService.leave_game()
	MultiplayerService.set_backend(original_backend, false)
	print("SMOKE PASS: ", mode)
	get_tree().quit()

func _offline() -> void:
	MultiplayerService.set_backend(MultiplayerService.BackendType.ENET, false)
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
	await get_tree().scene_changed
	if mode == "visual":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1280, 720)
	await _snapshot("menu")
	var menu := get_tree().current_scene
	menu.get_node("%SettingsButton").pressed.emit()
	_check(menu.get_node("%SettingsMenu").visible, "menu settings open")
	menu.get_node("%SettingsMenu").confirm_button_clicked.emit()
	_check(menu.get_node("%MainContainer").visible, "menu settings close")
	menu.get_node("%HostButton").pressed.emit()
	var panel := menu.get_node("%HostPanel")
	await _snapshot("host")
	panel.get_node("%MaxPlayersSpin").value = 1
	panel.get_node("%HostButton").pressed.emit()
	_check(await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Gameplay" and not GGT.is_changing_scene()), "offline gameplay transition")
	_check(not MultiplayerService.pending and multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "offline lobby joined")
	_check(World.player_spawner.get_child_count() == 1, "offline player spawned")
	var pause := get_tree().current_scene.get_node("UILayer/PauseLayer")
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	pause._unhandled_input(event)
	_check(pause.visible and not get_tree().paused, "pause keeps simulation active")
	await _snapshot("pause")
	pause.get_node("%SettingsButton").pressed.emit()
	pause.get_node("%SettingsMenu").confirm_button_clicked.emit()
	_check(pause.get_node("%PauseRoot").visible, "pause settings close")
	World.change_level("example-2")
	_check(await _wait_until(func() -> bool: return World.level_loader.current_key == "example-2" and World.level_loader.get_child_count() == 1), "offline level change")
	pause.get_node("%LeaveButton").pressed.emit()
	_check(await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Menu" and not GGT.is_changing_scene()), "return to menu")
	_check(World.player_spawner.get_child_count() == 0 and World.level_loader.get_child_count() == 0, "world cleared")
	MultiplayerService.set_backend(MultiplayerService.BackendType.NODETUNNEL, false)
	var options := HostOptions.new()
	options.max_players = 1
	options.lobby_name = "Offline relay selection"
	MultiplayerService.host_game(options)
	_check(not MultiplayerService.pending and multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "relay selection supports offline")
	MultiplayerService.leave_game()
	await get_tree().create_timer(0.3).timeout
	_check(World.player_spawner.get_child_count() == 0 and World.level_loader.get_child_count() == 0, "leave cancels level loading")
	_check(await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Menu" and not GGT.is_changing_scene()), "leave during transition returns to menu")
	scenario_completed = true

func _snapshot(label: String) -> void:
	if mode != "visual":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/nodetunnel-" + label + ".png")

func _capacity() -> void:
	if mode.ends_with("host"):
		var options := HostOptions.new()
		options.max_players = 4
		options.lobby_name = "Capacity Smoke"
		MultiplayerService.host_game(options)
		_check(await _wait_until(func() -> bool: return _in_session() and MultiplayerService.backend.get_joinable()), "capacity host ready")
		var file := FileAccess.open("/private/tmp/nodetunnel-capacity-room.txt", FileAccess.WRITE)
		file.store_string(_address())
		file.close()
		print("CAPACITY HOST READY")
		_check(await _wait_until(func() -> bool: return multiplayer.get_peers().size() == 3, 25.0), "four players joined")
		await get_tree().create_timer(6.0).timeout
		_check(multiplayer.get_peers().size() == 3, "fifth player refused")
	else:
		var address := FileAccess.get_file_as_string("/private/tmp/nodetunnel-capacity-room.txt")
		MultiplayerService.join_game(address)
		if mode.contains("full"):
			_check(await _wait_until(func() -> bool: return not failure.is_empty()), "full room rejected")
			_check(not MultiplayerService.backend.has_active_session(), "fifth player never admitted")
		else:
			_check(await _wait_until(func() -> bool: return _in_session()), "capacity client joined")
			_check(await _wait_until(func() -> bool: return exits > 0, 30.0), "capacity host left")
	scenario_completed = true

func _host() -> void:
	var options := HostOptions.new()
	options.max_players = 4
	options.lobby_name = "Smoke Test"
	MultiplayerService.host_game(options)
	_check(await _wait_until(func() -> bool: return _in_session() and MultiplayerService.backend.get_joinable()), "host ready: " + failure)
	print("SMOKE HOST READY: ", _address())
	if mode.begins_with("relay"):
		var file := FileAccess.open("/private/tmp/nodetunnel-smoke-room.txt", FileAccess.WRITE)
		file.store_string(_address())
		file.close()
	_check(await _wait_until(func() -> bool: return multiplayer.get_peers().size() == 1, 25.0), "client admitted")
	await get_tree().create_timer(1.0).timeout
	_check(World.player_spawner.get_child_count() == 2, "host sees two players")
	World.change_level("example-2")
	await get_tree().create_timer(2.0).timeout
	MultiplayerService.kick_player(multiplayer.get_peers()[0])
	_check(await _wait_until(func() -> bool: return multiplayer.get_peers().is_empty()), "kick disconnects client")
	_check(await _wait_until(func() -> bool: return multiplayer.get_peers().size() == 1), "client rejoins after kick")
	await get_tree().create_timer(1.0).timeout
	MultiplayerService.ban_player(multiplayer.get_peers()[0])
	_check(await _wait_until(func() -> bool: return multiplayer.get_peers().is_empty()), "ban disconnects client")
	if not mode.begins_with("relay"):
		await get_tree().create_timer(3.0).timeout
		MultiplayerService.banlist.clear()
	_check(await _wait_until(func() -> bool: return multiplayer.get_peers().size() == 1), "last reconnect")
	await get_tree().create_timer(1.0).timeout
	MultiplayerService.leave_game()
	scenario_completed = true

func _session() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
	await get_tree().scene_changed
	if mode.ends_with("host"):
		var options := HostOptions.new()
		options.max_players = 4
		options.lobby_name = "Session smoke"
		MultiplayerService.host_game(options)
		_check(await _wait_until(func() -> bool: return _in_session() and MultiplayerService.backend.get_joinable()), "session host ready")
		var file := FileAccess.open("/private/tmp/nodetunnel-session-room.txt", FileAccess.WRITE)
		file.store_string(_address())
		file.close()
		print("SESSION HOST READY")
		_check(await _wait_until(func() -> bool: return multiplayer.get_peers().size() == 1), "session client joined")
	else:
		MultiplayerService.join_game(FileAccess.get_file_as_string("/private/tmp/nodetunnel-session-room.txt"))
		_check(await _wait_until(func() -> bool: return _in_session()), "session client connected")
	_check(await _wait_until(func() -> bool: return World.player_spawner.get_child_count() == 2), "session players replicated")
	for second in range(30 if mode.ends_with("host") else 25):
		await get_tree().create_timer(1.0).timeout
		_check(_in_session() and exits == 0, "session stays connected past ten seconds")
	scenario_completed = true

func _client() -> void:
	MultiplayerService.fetch_lobby_list()
	_check(await _wait_until(func() -> bool: return discovered), "lobby discovery")
	var address := "127.0.0.1"
	if mode.begins_with("relay"):
		address = FileAccess.get_file_as_string("/private/tmp/nodetunnel-smoke-room.txt")
	MultiplayerService.join_game(address)
	_check(await _wait_until(func() -> bool: return _in_session()), "client connected: " + failure)
	_check(await _wait_until(func() -> bool: return World.player_spawner.get_child_count() == 2), "client replicated players")
	_check(await _wait_until(func() -> bool: return World.level_loader.current_key == "example-2"), "client follows level change")
	_check(await _wait_until(func() -> bool: return exits == 1), "client kicked")
	_check(MultiplayerService.kick_reason == MultiplayerService.KICK_REASON_KICKED, "kick reason")
	await get_tree().create_timer(0.5).timeout
	MultiplayerService.join_game(address)
	_check(await _wait_until(func() -> bool: return exits == 2), "client banned")
	_check(MultiplayerService.kick_reason == MultiplayerService.KICK_REASON_BANNED, "ban reason")
	await get_tree().create_timer(0.5).timeout
	if not mode.begins_with("relay"):
		MultiplayerService.join_game(address)
		_check(await _wait_until(func() -> bool: return exits == 3), "banned reconnect refused")
		_check(MultiplayerService.kick_reason == MultiplayerService.KICK_REASON_BANNED, "banned reconnect reason")
		await get_tree().create_timer(3.5).timeout
	var prior_exits := exits
	MultiplayerService.join_game(address)
	_check(await _wait_until(func() -> bool: return _in_session()), "last connection")
	_check(await _wait_until(func() -> bool: return exits > prior_exits), "host disconnect")
	scenario_completed = true
