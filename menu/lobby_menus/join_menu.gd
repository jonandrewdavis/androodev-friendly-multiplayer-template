extends Control


@onready var lobby_list_container: VBoxContainer = %LobbyListContainer
const JOIN_LIST_ITEM = preload("uid://da7j7kjf5qunx")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MultiplayerService.lobby_found.connect(_add_lobby_to_list)
	MultiplayerService.joining_lobby.connect(_join_pending)
	
	#lobby_list_container.add_child()
	for i in range(20):
		var new_item = JOIN_LIST_ITEM.instantiate()
		new_item.name = "i" + str(i)
		lobby_list_container.add_child(new_item, true)

func _add_lobby_to_list():
	pass
	
func _join_pending():
	pass
