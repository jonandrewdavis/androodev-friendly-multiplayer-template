extends CanvasLayer

@onready var in_game_container: Control = %InGameContainer

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var leave_button: Button = %LeaveButton
@onready var settings_menu: PanelContainer = %SettingsMenu

# TODO: Do we need controller focus here? Like in Main menu?

func _ready():
	hide()

	resume_button.pressed.connect(func(): resume())
	settings_button.pressed.connect(func() -> void: settings_menu.show())
	settings_menu.confirm_button_clicked.connect(func() -> void: settings_menu.hide())
	leave_button.pressed.connect(MultiplayerService.leave_game)
	
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
		await get_tree().process_frame
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if GGT.is_changing_scene():
			return
		if settings_menu.visible:
			# TODO: Handle the corner case of a "Reset values" modal visible. 
			# Need to zero out the current action, not as simple as just hide.
			# Maack's does a lot of this for you. GGT is a little more loose,
			# but it is much lighter weight, which I like - AD.
			settings_menu.hide()
		elif visible:
			resume()
		else:
			show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			%ResumeButton.grab_focus()
			
func resume() -> void:
	settings_menu.hide()
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_game_exited() -> void:
	# TODO: Do we need this?
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
