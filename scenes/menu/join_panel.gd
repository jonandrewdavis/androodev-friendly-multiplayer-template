class_name JoinPanel
extends PanelContainer

signal closed
const ITEM_SCENE := preload("res://scenes/menu/join_list_item.tscn")
var addresses: Dictionary = {}

func _ready() -> void:
	%CloseButton.pressed.connect(_close)
	%RefreshButton.pressed.connect(_refresh)
	%JoinAddressButton.pressed.connect(_join_address)
	%AddressEdit.text_submitted.connect(func(_text: String) -> void: _join_address())
	MultiplayerService.lobby_found.connect(_add_lobby)
	MultiplayerService.backend_changed.connect(_refresh_hint)
	MultiplayerService.joining_lobby.connect(_close)

func open() -> void:
	_refresh_hint(MultiplayerService.backend_type)
	show()
	_refresh()
	%AddressEdit.grab_focus()

func _refresh_hint(_type: int) -> void:
	%AddressEdit.placeholder_text = MultiplayerService.ADDRESS_HINTS[MultiplayerService.backend_type]
	%AddressEdit.clear()

func _refresh() -> void:
	addresses.clear()
	for child in %LobbyList.get_children():
		%LobbyList.remove_child(child)
		child.queue_free()
	%SearchLabel.text = "Searching..."
	await MultiplayerService.fetch_lobby_list()
	if addresses.is_empty():
		%SearchLabel.text = "No rooms found. Try an address or refresh."
	else:
		%SearchLabel.text = ""

func _add_lobby(address: Variant, lobby_name: String, cur: int, maximum: int) -> void:
	if not visible:
		return
	if addresses.has(address):
		addresses[address].update_lobby(lobby_name, cur, maximum)
		return
	var item := ITEM_SCENE.instantiate()
	item.address = address
	%LobbyList.add_child(item)
	item.update_lobby(lobby_name, cur, maximum)
	addresses[address] = item

func _join_address() -> void:
	MultiplayerService.join_game(%AddressEdit.text.strip_edges())

func _close() -> void:
	hide()
	closed.emit()
