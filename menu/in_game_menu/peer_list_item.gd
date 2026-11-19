class_name PeerListItem
extends HBoxContainer

var peer_id: int

@onready var username_label: Label = %UsernameLabel
@onready var kick_button: Button = %KickButton
@onready var ban_button: Button = %BanButton
@onready var mod_controls: HBoxContainer = %ModControls

func _ready() -> void:
	username_label.text = MultiplayerService.get_username(peer_id)
	if multiplayer.is_server():	
		kick_button.pressed.connect(func() -> void: MultiplayerService.kick_player(peer_id))
		ban_button.pressed.connect(func() -> void: MultiplayerService.ban_player(peer_id))
	else:
		mod_controls.queue_free()
