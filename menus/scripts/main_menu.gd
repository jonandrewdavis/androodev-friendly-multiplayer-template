class_name MainMenu
extends Control


const TIMEOUT_DUR := 10.0


@onready var host_button: Button = $Buttons/HostButton
@onready var join_button: Button = $Buttons/JoinButton
@onready var quit_button: Button = $Buttons/QuitButton
@onready var host_popup: PackedScene = preload("uid://d0yvjw3bvjxkq")
@onready var join_popup: PackedScene = preload("uid://bjugfndbiagm1")
@onready var pending_overlay: ColorRect = $PendingOverlay
@onready var pending_label: Label = $PendingOverlay/PendingLabel
@onready var failed_label: Label = $PendingOverlay/FailedLabel
@onready var failed_button: Button = $PendingOverlay/FailedButton


signal lobby_failure(reason: String)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	host_button.grab_focus()
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	failed_button.pressed.connect(_on_failed_button_pressed)
	MultiplayerService.joining_lobby.connect(_on_joining_lobby)
	MultiplayerService.join_lobby_failed.connect(lobby_failure.emit)
	MultiplayerService.creating_lobby.connect(_on_creating_lobby)
	if not MultiplayerService.kick_reason.is_empty():
		_show_kick_reason(MultiplayerService.kick_reason)


func _on_host_button_pressed() -> void:
	var popup: HostOptionsPopup = host_popup.instantiate()
	add_child(popup)


func _on_join_button_pressed() -> void:
	var popup: JoinPopup = join_popup.instantiate()
	add_child(popup)


func _on_joining_lobby() -> void:
	var reason := await _show_overlay("Joining Game...")
	push_error("Failed to Join game. Reason: %s" % reason)
	_on_lobby_failure("Join", reason)


func _on_creating_lobby() -> void:
	var reason := await _show_overlay("Hosting Game...")
	push_error("Failed to Host game. Reason: %s" % reason)
	_on_lobby_failure("Host" , reason)


func _on_lobby_failure(cj: String, reason: String) -> void:
	pending_label.hide()
	failed_label.text = "Failed to %s game.\nReason: %s" % [cj, reason]
	failed_label.show()
	failed_button.show()
	failed_button.grab_focus()


func _on_failed_button_pressed() -> void:
	pending_overlay.hide()
	host_button.grab_focus()


func _show_kick_reason(reason: String) -> void:
	pending_overlay.show()
	pending_label.hide()
	failed_label.text = reason
	failed_label.show()
	failed_button.show()
	failed_button.grab_focus()


## Displays the overlay when attempting to host or join a game.
## This serves 2 purposes: disabling all of the on-screen buttons,
## and giving the player some visual feedback while they wait.
func _show_overlay(text: String) -> String:
	pending_label.text = text
	pending_overlay.show()
	pending_label.show()
	pending_overlay.grab_focus()
	failed_label.hide()
	failed_button.hide()
	_start_countdown()
	var reason: String = await lobby_failure
	return reason


## Does a countdown for [constant TIMEOUT_DUR] seconds, then emits [signal lobby_failure].
## It's not a problem if this triggers after a different failure since that will have already
## been handled.
func _start_countdown() -> void:
	await get_tree().create_timer(TIMEOUT_DUR).timeout
	lobby_failure.emit("Timed out.")
