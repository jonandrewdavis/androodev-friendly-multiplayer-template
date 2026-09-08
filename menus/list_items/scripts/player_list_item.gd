class_name PlayerListItem
extends HBoxContainer


@onready var username_label: Label = $UsernameLabel
@onready var kick_button: Button = $KickButton
@onready var ban_button: Button = $BanButton


var peer_id: int


func _ready() -> void:
	if multiplayer.is_server():
		kick_button.pressed.connect(_on_kick_pressed)
		ban_button.pressed.connect(_on_ban_pressed)
		kick_button.show()
		ban_button.show()
	username_label.text = MultiplayerService.get_username(peer_id)


func _on_kick_pressed() -> void:
	MultiplayerService.kick_player(peer_id)


func _on_ban_pressed() -> void:
	MultiplayerService.ban_player(peer_id)
