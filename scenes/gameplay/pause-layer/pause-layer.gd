extends CanvasLayer

@export var settings_menu: PanelContainer
@export var margin_container: MarginContainer

@onready var pause := self

@onready var resume_button: Button = %ResumeButton
@onready var color_rect = $ColorRect

@onready var pause_root: Control = %PauseRoot
@onready var nodes_grp1 = [] # should be visible during gamemplay and hidden during pause
@onready var nodes_grp2 = [pause_root, color_rect] # should be visible only in pause menu

# Inventory open
# Hit ESC -> close inventory
# Inventory closed, hit ESC -> Opens Menu (quit / disconnect)

# They both show your cursor. 

func _ready():
	pause_hide()

func pause_show():
	for n in nodes_grp1:
		n.hide()
	for n in nodes_grp2:
		n.show()

func pause_hide():
	for n in nodes_grp1:
		if n:
			n.show()
	for n in nodes_grp2:
		if n:
			n.hide()
	settings_menu.hide()


func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if settings_menu.visible:
			# TODO: close settings.
			return
		if pause_root.visible:
			resume()
		else:
			pause_game()
		get_viewport().set_input_as_handled()


func resume():
	pause_hide()

func pause_game():
	resume_button.grab_focus()
	pause_show()


func _on_Resume_pressed():
	resume()

func _on_PauseButton_pressed():
	pause_game()


func _on_main_menu_pressed():
	GGT.change_scene("res://scenes/menu/menu.tscn", {"show_progress_bar": false})


func _on_settings_pressed() -> void:
	settings_menu.show()


func _on_settings_menu_visibility_changed() -> void:
	margin_container.visible = !settings_menu.visible
	if !settings_menu.visible:
		resume_button.grab_focus() # restore focus


func _on_settings_menu_confirm_button_clicked() -> void:
	settings_menu.hide()
