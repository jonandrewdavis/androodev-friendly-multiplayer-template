class_name JoinListItem
extends HBoxContainer


@onready var name_label: Label = $NameLabel
@onready var player_count_label: Label = $PlayerCount
@onready var join_button: Button = $JoinButton


var lobby_name: String
var address: Variant
var cur_players: int
var max_players: int


func _ready() -> void:
	name_label.text = lobby_name
	player_count_label.text = "(%d/%d)" % [cur_players, max_players]
	join_button.pressed.connect(_on_join_button_pressed)


func _on_join_button_pressed() -> void:
	MultiplayerService.join_game(address)


func set_button_disabled(disabled: bool) -> void:
	join_button.disabled = disabled
