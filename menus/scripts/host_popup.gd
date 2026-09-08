class_name HostOptionsPopup
extends ColorRect


const MAX_NAME_LENGTH := 20
const MAX_PLAYERS := 4
const MIN_PLAYERS := 1


@onready var name_edit: TextEdit = $Options/GameName/TextEdit
@onready var up_button: Button = $Options/MaxPlayers/Buttons/UpButton
@onready var down_button: Button = $Options/MaxPlayers/Buttons/DownButton
@onready var host_button: Button = $HostButton
@onready var close_button: Button = $CloseButton
@onready var count_label: Label = $Options/MaxPlayers/CountLabel


var last_edit_text: String


func _ready() -> void:
	name_edit.text_changed.connect(_on_edit_text_changed)
	up_button.pressed.connect(_on_up_button_pressed)
	down_button.pressed.connect(_on_down_button_pressed)
	host_button.pressed.connect(_on_host_button_pressed)
	close_button.pressed.connect(func() -> void: queue_free())


func _on_edit_text_changed() -> void:
	# remove commas
	while name_edit.text.contains(","):
		name_edit.text = name_edit.text.erase(name_edit.text.find(","))
	if len(name_edit.text) > MAX_NAME_LENGTH:
		name_edit.text = last_edit_text
	else:
		last_edit_text = name_edit.text


func _on_up_button_pressed() -> void:
	var count := int(count_label.text)
	count += 1
	if count == MAX_PLAYERS:
		up_button.disabled = true
	assert(count <= MAX_PLAYERS)
	count_label.text = str(count)
	down_button.disabled = false


func _on_down_button_pressed() -> void:
	var count := int(count_label.text)
	count -= 1
	if count == MIN_PLAYERS:
		down_button.disabled = true
	assert(count >= MIN_PLAYERS)
	count_label.text = str(count)
	up_button.disabled = false


func _on_host_button_pressed() -> void:
	var options := HostOptions.new()
	options.max_players = int(count_label.text)
	options.lobby_name = name_edit.placeholder_text if name_edit.text.is_empty() else name_edit.text
	MultiplayerService.host_game(options)
