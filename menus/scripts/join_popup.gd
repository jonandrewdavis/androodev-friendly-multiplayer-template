class_name JoinPopup
extends ColorRect


@onready var close_button: Button = $CloseButton
@onready var list_item_scene: PackedScene = preload("uid://burlpkae25t88")
@onready var item_list: VBoxContainer = $ScrollContainer/ItemList
@onready var refresh_button: Button = $RefreshButton
@onready var reg_container: ScrollContainer = $ScrollContainer


func _ready() -> void:
	close_button.pressed.connect(func() -> void: queue_free())
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	MultiplayerService.lobby_found.connect(add_list_item.bind(item_list))
	MultiplayerService.fetch_lobby_list()


func add_list_item(address: Variant, lobby_name: String, cur_players: int, max_players: int, list: VBoxContainer) -> void:
	var item: JoinListItem = list_item_scene.instantiate()
	item.address = address
	item.lobby_name = lobby_name
	item.cur_players = cur_players
	item.max_players = max_players
	list.add_child(item)


func _on_refresh_button_pressed() -> void:
	for item: JoinListItem in item_list.get_children():
		item.queue_free()
	MultiplayerService.fetch_lobby_list()
