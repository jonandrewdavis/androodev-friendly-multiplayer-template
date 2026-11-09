extends Control

const TIMEOUT_DUR := 10.0
var pending_attempt_id := 0

@onready var main_container: MarginContainer = %MainContainer
@onready var status_label: Label = %StatusLabel

@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton

@onready var character_settings_button: Button = %CharacterSettingsButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton

@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var character_settings_menu: CharacterSettingsMenu = %CharacterSettingsMenu
@onready var pending_overlay: ColorRect = %PendingOverlay
@onready var host_panel: HostPanel = %HostPanel
@onready var join_panel: JoinPanel = %JoinPanel
@onready var help_panel: PanelContainer = %HelpPanel

@onready var pending_label: Label = %PendingLabel
@onready var load_progress_bar: ProgressBar = %LoadProgressBar
@onready var failed_label: Label = %FailedLabel
@onready var failed_button: Button = %FailedButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status_label.text = MultiplayerService.status_text
	MultiplayerService.status_changed.connect(func(text: String) -> void: status_label.text = text)
	_update_session_buttons()
	MultiplayerService.backend_changed.connect(func(_type: MultiplayerBackend.Type) -> void: _update_session_buttons())
	MultiplayerService.backend_failed.connect(_show_failure)
	MultiplayerService.creating_lobby.connect(_show_pending.bind("Hosting game..."))
	MultiplayerService.joining_lobby.connect(_show_pending.bind("Joining game..."))
	MultiplayerService.join_lobby_failed.connect(_show_failure)
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	World.level_loader.load_progress.connect(func(value: float) -> void: load_progress_bar.value = value)
	host_button.pressed.connect(func() -> void:
		main_container.hide()
		help_panel.hide()
		host_panel.open())
	join_button.pressed.connect(func() -> void:
		main_container.hide()
		help_panel.hide()
		join_panel.open())
	host_panel.closed.connect(_restore_main)
	join_panel.closed.connect(_restore_main)


	_setup_sub_menu(settings_button, settings_menu)
	_setup_sub_menu(character_settings_button, character_settings_menu)

	failed_button.pressed.connect(func() -> void:
		pending_overlay.hide()
		_restore_main())
	exit_button.pressed.connect(_exit)
	if OS.has_feature("web"):
		exit_button.hide()
	host_button.grab_focus()
	if not MultiplayerService.kick_reason.is_empty():
		_show_failure(MultiplayerService.kick_reason)
		MultiplayerService.kick_reason = ""
	elif not MultiplayerService.backend_error.is_empty():
		_show_failure(MultiplayerService.backend_error)


func _setup_sub_menu(button:Button, sub_menu: Control):
	button.pressed.connect(func(): sub_menu.show())
	sub_menu.visibility_changed.connect(func() -> void:
		main_container.visible = not sub_menu.visible
		if not button.visible:
			settings_button.grab_focus())
	sub_menu.confirm_button_clicked.connect(func() -> void: sub_menu.hide())

func _restore_main() -> void:
	main_container.show()
	help_panel.show()
	host_button.grab_focus()

func _show_pending(text: String) -> void:
	pending_attempt_id += 1
	var attempt_id := pending_attempt_id
	main_container.hide()
	help_panel.hide()
	pending_label.text = text
	failed_label.hide()
	failed_button.hide()
	load_progress_bar.hide()
	pending_overlay.show()
	pending_overlay.grab_focus()
	await get_tree().create_timer(TIMEOUT_DUR).timeout
	if attempt_id == pending_attempt_id and MultiplayerService.state == MultiplayerService.State.CONNECTING:
		MultiplayerService.leave_game()
		_show_failure("Timed out.")

func _show_failure(reason: String) -> void:
	pending_attempt_id += 1
	help_panel.hide()
	join_panel.hide()
	main_container.hide()
	help_panel.hide()
	pending_label.text = "Unable to continue"
	failed_label.text = reason
	load_progress_bar.hide()
	failed_label.show()
	failed_button.show()
	pending_overlay.show()
	failed_button.grab_focus()

func _on_lobby_joined() -> void:
	pending_attempt_id += 1
	# Keep the overlay up while the level loads; the scene change frees the menu.
	pending_label.text = "Loading level..."
	load_progress_bar.value = 0.0
	load_progress_bar.show()

func _update_session_buttons() -> void:
	join_button.disabled = MultiplayerService.backend_type == MultiplayerBackend.Type.OFFLINE

func _exit() -> void:
	var transitions := get_node_or_null("/root/GGT_Transitions")
	if transitions:
		transitions.fade_in({"show_progress_bar": false})
		await transitions.anim.animation_finished
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
