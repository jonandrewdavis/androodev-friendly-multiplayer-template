extends Control

const JOIN_LIST_ITEM = preload("uid://da7j7kjf5qunx")

@onready var room_code_input: LineEdit = %RoomCodeInput
@onready var room_code_button: Button = %RoomCodeButton
@onready var lobby_list_container: VBoxContainer = %LobbyListContainer

func _ready() -> void:
	MultiplayerService.lobby_found.connect(_add_lobby_to_list)
	MultiplayerService.joining_lobby.connect(_join_pending)
	
	room_code_input.text_changed.connect(_update_room_code)
	room_code_button.pressed.connect(_on_room_code_button_pressed)
	room_code_button.disabled = true	
	
	#lobby_list_container.add_child()
	for i in range(20):
		var new_item = JOIN_LIST_ITEM.instantiate()
		new_item.name = "i" + str(i)
		lobby_list_container.add_child(new_item, true)


func _update_room_code(new_text: String):
	room_code_button.disabled = new_text ==  ""
	var caret_pos: int = room_code_input.caret_column
	room_code_input.text = new_text.to_upper()
	room_code_input.caret_column = caret_pos
	
	
func _on_room_code_button_pressed():
	MultiplayerService.join_game(room_code_input.text)

func _add_lobby_to_list():
	pass

	
func _join_pending():
	pass
