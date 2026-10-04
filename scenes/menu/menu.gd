@tool
extends Control

const UI_LAYER = "res://scenes/ui/ui_layer.tscn"
const TIMEOUT_DUR := 10.0
var timeout_token := 0

## Multiplayer backend used by this game. Web exports always use Tube (WebRTC).
@export var backend_type := MultiplayerBackend.Type.NONE:
	set(value):
		backend_type = value
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if backend_type == MultiplayerBackend.Type.NONE:
		return ["Select a Backend Type. (Web exports always use Tube.)"]
	return []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if MultiplayerService.backend == null: # keeps a debug-selected backend when returning from a game
		MultiplayerService.set_backend(backend_type)
	_setup_debug_backend_option()
	%StatusLabel.text = MultiplayerService.status_text
	MultiplayerService.status_changed.connect(func(text: String) -> void: %StatusLabel.text = text)
	MultiplayerService.creating_lobby.connect(_show_pending.bind("Hosting game..."))
	MultiplayerService.joining_lobby.connect(_show_pending.bind("Joining game..."))
	MultiplayerService.join_lobby_failed.connect(_show_failure)
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	%HostButton.pressed.connect(func() -> void:
		%MainContainer.hide()
		%Help.hide()
		%HostPanel.open())
	%JoinButton.pressed.connect(func() -> void:
		%MainContainer.hide()
		%Help.hide()
		%JoinPanel.open())
	%HostPanel.closed.connect(_restore_main)
	%JoinPanel.closed.connect(_restore_main)
	%SettingsButton.pressed.connect(func() -> void: %SettingsMenu.show())
	%SettingsMenu.visibility_changed.connect(func() -> void:
		%MainContainer.visible = not %SettingsMenu.visible
		%Help.visible = not %SettingsMenu.visible
		if not %SettingsMenu.visible:
			%SettingsButton.grab_focus())
	%SettingsMenu.confirm_button_clicked.connect(func() -> void: %SettingsMenu.hide())
	%CharacterButton.pressed.connect(func() -> void: %CharacterSettingsMenu.show())
	%CharacterSettingsMenu.visibility_changed.connect(func() -> void:
		%MainContainer.visible = not %CharacterSettingsMenu.visible
		%Help.visible = not %CharacterSettingsMenu.visible
		if not %CharacterSettingsMenu.visible:
			%CharacterButton.grab_focus())
	%CharacterSettingsMenu.confirm_button_clicked.connect(func() -> void: %CharacterSettingsMenu.hide())
	%FailedButton.pressed.connect(func() -> void:
		%PendingOverlay.hide()
		_restore_main())
	%ExitButton.pressed.connect(_exit)
	if OS.has_feature("web"):
		%ExitButton.hide()
	%HostButton.grab_focus()
	if not MultiplayerService.kick_reason.is_empty():
		_show_failure(MultiplayerService.kick_reason)
		MultiplayerService.kick_reason = ""

## Developer-only backend switcher; removed from release builds.
func _setup_debug_backend_option() -> void:
	if not OS.is_debug_build():
		%DebugBackendOption.queue_free()
		return
	for type in MultiplayerService.backend_scripts:
		%DebugBackendOption.add_item(MultiplayerBackend.Type.find_key(type).capitalize(), type)
	%DebugBackendOption.select(%DebugBackendOption.get_item_index(MultiplayerService.backend_type))
	%DebugBackendOption.item_selected.connect(func(index: int) -> void: MultiplayerService.set_backend(%DebugBackendOption.get_item_id(index)))

func _restore_main() -> void:
	%MainContainer.show()
	%Help.show()
	%HostButton.grab_focus()

func _show_pending(text: String) -> void:
	timeout_token += 1
	var token := timeout_token
	%MainContainer.hide()
	%Help.hide()
	%PendingLabel.text = text
	%FailedLabel.hide()
	%FailedButton.hide()
	%PendingOverlay.show()
	%PendingOverlay.grab_focus()
	await get_tree().create_timer(TIMEOUT_DUR).timeout
	if token == timeout_token and MultiplayerService.pending:
		MultiplayerService.leave_game()
		_show_failure("Timed out.")

func _show_failure(reason: String) -> void:
	timeout_token += 1
	%HostPanel.hide()
	%JoinPanel.hide()
	%MainContainer.hide()
	%Help.hide()
	%PendingLabel.text = "Unable to continue"
	%FailedLabel.text = reason
	%FailedLabel.show()
	%FailedButton.show()
	%PendingOverlay.show()
	%FailedButton.grab_focus()

func _on_lobby_joined() -> void:
	timeout_token += 1
	%PendingOverlay.hide()
	GGT.change_scene(UI_LAYER, {"show_progress_bar": false})

func _exit() -> void:
	var transitions := get_node_or_null("/root/GGT_Transitions")
	if transitions:
		transitions.fade_in({"show_progress_bar": false})
		await transitions.anim.animation_finished
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
