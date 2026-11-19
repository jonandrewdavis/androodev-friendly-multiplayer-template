extends Control

@onready var main_container: Control = %MainContainer
@onready var button_container: VBoxContainer = %ButtonVBoxContainer
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var multiplayer_option_button: OptionButton = %MultiplayerOptionButton
@onready var settings_menu: PanelContainer = %SettingsMenu
@onready var multiplayer_status_label: Label = %MultiplayerStatusLabel

const JOIN_MENU = preload("uid://dnvawcgmhlkmt")

# TODO: We may be able to compress this into a single "Join" menu
# which does the lobby list by default, with a "Host Game button"
# nearby. Then, is there enough on this main menu?

# TODO: join errors, host errors, etc... _update_status_with_reason is un-used.

func _ready():
	# NOTE: We prefer to set up signals in code, rather than side panel for
	# better searchability. Signals at the top.
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	settings_button.pressed.connect(func(): settings_menu.show())
	settings_menu.visibility_changed.connect(_on_settings_menu_visibility_changed)
	settings_menu.confirm_button_clicked.connect(func(): settings_menu.hide())
	exit_button.pressed.connect(_on_exit_button_pressed)

	MultiplayerService.state_updated.connect(_on_multiplayer_state_updated)
	MultiplayerService.creating_lobby.connect(func(): _update_status_with_reason(''))
	MultiplayerService.joining_lobby.connect(func(): _update_status_with_reason(''))
	MultiplayerService.join_lobby_failed.connect(_update_status_with_reason)
	# needed for gamepads to work
	host_button.grab_focus()
	if OS.has_feature('web'):
		exit_button.queue_free() # exit button dosn't make sense on HTML5

	# cursor shape, nice to have
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for button: Button in button_container.get_children():
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_set_up_multiplayer_backend_options()


func _on_host_button_pressed() -> void:
	var _opts = HostOptions.new()
	_opts.max_players = 2
	MultiplayerService.host_game(_opts)

	
func _on_join_button_pressed() -> void:
	get_tree().change_scene_to_file(JOIN_MENU.resource_path)
	#MultiplayerService.join_game('127.0.0.1')


func _on_exit_button_pressed() -> void:
	# gently shutdown the game
	var transitions = get_node_or_null("/root/GGT_Transitions")
	if transitions:
		transitions.fade_in({
			'show_progress_bar': false
		})
		await transitions.anim.animation_finished
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _on_settings_menu_visibility_changed() -> void:
	main_container.visible = !settings_menu.visible
	if !settings_menu.visible:
		settings_button.grab_focus()


func _set_up_multiplayer_backend_options():
	for i in range(MultiplayerService.BACKEND_LABELS.size()):
		multiplayer_option_button.add_item(MultiplayerService.BACKEND_LABELS[i], i)
	multiplayer_option_button.select(GGT_GameConfig.get_multiplayer_backend())
	multiplayer_option_button.item_selected.connect(_on_multiplayer_option_changed)
	if not OS.is_debug_build():
		# TODO: Move to Help section? Move somewhere else.
		# TODO: Should we just queue free this thing?
		multiplayer_option_button.disabled = true


func _on_multiplayer_option_changed(index: int):
	GGT_GameConfig.set_multiplayer_backend(index)
	GGT_GameConfig.persist()


# TODO: not sure about this. Seems to work for now.
func _on_multiplayer_state_updated(new_state: MultiplayerService.State):
	host_button.disabled = new_state == MultiplayerService.State.ERROR
	join_button.disabled = new_state == MultiplayerService.State.ERROR
	host_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if new_state == MultiplayerService.State.ERROR else Control.CURSOR_POINTING_HAND
	join_button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if new_state == MultiplayerService.State.ERROR else Control.CURSOR_POINTING_HAND

func _update_status_with_reason(reason: String):
	multiplayer_status_label.text = reason
