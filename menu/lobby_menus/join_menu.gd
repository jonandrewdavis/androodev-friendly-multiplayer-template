extends Control

const JOIN_LIST_ITEM = preload("uid://da7j7kjf5qunx")

@onready var room_code_input: LineEdit = %RoomCodeInput
@onready var room_code_button: Button = %RoomCodeButton
@onready var lobby_list_container: VBoxContainer = %LobbyListContainer
@onready var back_button: Button = %BackButton
@onready var refresh_button: Button = %RefreshButton

func _ready() -> void:
	MultiplayerService.lobby_found.connect(_add_lobby_to_list)
	MultiplayerService.joining_lobby.connect(_join_pending)
	
	room_code_input.text_changed.connect(_update_room_code)
	room_code_button.pressed.connect(_on_room_code_button_pressed)
	room_code_button.disabled = true	

	back_button.pressed.connect(_on_back_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	_on_refresh_button_pressed()


func _update_room_code(new_text: String):
	room_code_button.disabled = new_text ==  ""
	var caret_pos: int = room_code_input.caret_column
	room_code_input.text = new_text.to_upper()
	room_code_input.caret_column = caret_pos
	
	
func _on_room_code_button_pressed():
	MultiplayerService.join_game(room_code_input.text)


func _add_lobby_to_list(address: Variant, _lobby_name: String, _cur_players: int, _max_players: int):
	var new_item = JOIN_LIST_ITEM.instantiate()
	new_item.name = "Lobby: " + str(address)
	new_item.get_node("%Button").pressed.connect(func(): MultiplayerService.join_game(address))
	lobby_list_container.add_child(new_item, true)

	
func _join_pending():
	pass
	
func _on_refresh_button_pressed():
	for child in lobby_list_container.get_children():
		child.queue_free()
	MultiplayerService.fetch_lobby_list()	

func _on_back_button_pressed():
	GGT.change_scene(GGT._history.get_previous_loaded_scene_data().path)
