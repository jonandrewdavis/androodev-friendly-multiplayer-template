extends Control

const IN_GAME_MENU = preload("uid://barl4q1kugrmm")

@onready var main_container: Control = %MainContainer
@onready var button_container: VBoxContainer = %ButtonVBoxContainer
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var multiplayer_option_button: OptionButton = %MultiplayerOptionButton
@onready var settings_menu: PanelContainer = %SettingsMenu


func _ready():
	# NOTE: We prefer to set up signals in code, rather than side panel for
	# better searchability. Signals at the top.
	host_button.pressed.connect(_on_host_button_pressed)
	settings_button.pressed.connect(func(): settings_menu.show())
	settings_menu.visibility_changed.connect(_on_settings_menu_visibility_changed)
	settings_menu.confirm_button_clicked.connect(_on_settings_menu_confirm_button_clicked)
	exit_button.pressed.connect(_on_exit_button_pressed)
	
	_set_up_multiplayer_backend_options()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# needed for gamepads to work
	host_button.grab_focus()
	if OS.has_feature('web'):
		exit_button.queue_free() # exit button dosn't make sense on HTML5

	# cursor shape, nice to have
	for button: Button in button_container.get_children():
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_host_button_pressed() -> void:
	# TODO: Bug with GGT here? 4.8 maybe?
	#GGT.change_scene("res://scenes/levels/home.tscn", {"show_progress_bar": false})
	get_tree().change_scene_to_packed(IN_GAME_MENU)

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

func _on_settings_button_pressed() -> void:
	settings_menu.show()

func _on_settings_menu_visibility_changed() -> void:
	main_container.visible = !settings_menu.visible
	if !settings_menu.visible:
		settings_button.grab_focus()

func _on_settings_menu_confirm_button_clicked() -> void:
	settings_menu.hide()

func _set_up_multiplayer_backend_options():
	for i in range(MultiplayerService.BACKEND_LABELS.size()):
		multiplayer_option_button.add_item(MultiplayerService.BACKEND_LABELS[i], i)
	multiplayer_option_button.select(GGT_GameConfig.get_multiplayer_backend())
	multiplayer_option_button.item_selected.connect(_on_multiplayer_option_changed)
	if not OS.is_debug_build():
		# TODO: Should we just queue free this thing?
		multiplayer_option_button.disabled = true

func _on_multiplayer_option_changed(index: int):
	GGT_GameConfig.set_multiplayer_backend(index)
	GGT_GameConfig.persist()
