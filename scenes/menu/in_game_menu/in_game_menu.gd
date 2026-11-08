extends CanvasLayer

const PLAYER_LIST_ITEM = preload("res://scenes/menu/in_game_menu/player_list_item.tscn")
var players: Dictionary = {}

@onready var settings_button: Button = %SettingsButton
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var character_settings_button: Button = %CharacterSettingsButton
@onready var character_settings_menu: CharacterSettingsMenu = %CharacterSettingsMenu

func _ready() -> void:
	hide()
	
	MultiplayerService.game_exited.connect(_on_game_exited)
	if DebugMenu != null:
		DebugMenu.update_settings_label()
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
		await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	%ResumeButton.pressed.connect(resume)
	%LeaveButton.pressed.connect(MultiplayerService.leave_game)
	%LoadLevelButton.pressed.connect(_load_level)

	_setup_sub_menu(settings_button, settings_menu)
	_setup_sub_menu(character_settings_button, character_settings_menu)
	
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		_add_player(peer_id)

	var backend := MultiplayerService.backend
	%LobbyAddressLabel.visible = backend.has_method("get_room_code")
	if %LobbyAddressLabel.visible:
		%LobbyAddressLabel.text = MultiplayerService.ADDRESS_HINTS[MultiplayerService.backend_type] + ": " + backend.get_room_code()

	# TODO: Move these functions into their own "Host menu" (admin menu)?
	%HostPanel.visible = multiplayer.is_server()
	if multiplayer.is_server():
		for key in LevelLoader.LEVEL_DICT:
			%LevelOption.add_item(key)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if GGT.is_changing_scene():
			return
		if %SettingsMenu.visible:
			%SettingsMenu.hide()
		elif visible:
			resume()
		else:
			show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			%ResumeButton.grab_focus()

func resume() -> void:
	%SettingsMenu.hide()
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_sub_menu(button:Button, sub_menu: Control):
	button.pressed.connect(func() -> void: sub_menu.show())
	sub_menu.visibility_changed.connect(func() -> void:
		%PauseRoot.visible = not sub_menu.visible
		if not sub_menu.visible:
			%ResumeButton.grab_focus())
	sub_menu.confirm_button_clicked.connect(func() -> void: sub_menu.hide())
	

func _add_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var item = PLAYER_LIST_ITEM.instantiate()
	item.peer_id = peer_id
	%PlayerList.add_child(item)
	players[peer_id] = item

func _remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		var item: Node = players[peer_id]
		%PlayerList.remove_child(item)
		item.queue_free()
		players.erase(peer_id)

func _load_level() -> void:
	World.change_level(%LevelOption.get_item_text(%LevelOption.selected))

func _open_menu_type(type):
	match type:
		'character_menu':
			pass
		'settings_menu':
			pass

func _on_game_exited() -> void:
	# TODO: Do we need this?
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
