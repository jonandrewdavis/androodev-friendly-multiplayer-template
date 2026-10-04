extends Control

class_name CharacterSettingsMenu

signal cancel_button_clicked
signal confirm_button_clicked

@export var username_line_edit: LineEdit
@onready var color_picker_grid: ColorPickerGrid = %ColorPickerGrid

@export var reset_confirmation_dialog: ConfirmationModal
@export var cancel_confirmation_dialog: ConfirmationModal
@export var cancel_button: Button

var previous_config: ConfigFile # null if no value changed since last visit to the character page.
var _focus_before_modal: Control


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	username_line_edit.text_changed.connect(on_username_changed)
	color_picker_grid.color_changed.connect(on_color_changed)
	reset_confirmation_dialog.confirmed.connect(_on_reset_confirmed)
	cancel_confirmation_dialog.confirmed.connect(_on_cancel_confirmed)
	reset_confirmation_dialog.cancelled.connect(_on_modal_canceled)
	cancel_confirmation_dialog.cancelled.connect(_on_modal_canceled)

	username_line_edit.text_changed.connect(_on_setting_changed)
	color_picker_grid.color_changed.connect(_on_setting_changed)

	initialize()

	visibility_changed.connect(on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if !visible: return
	if event is InputEventJoypadButton:
		if event.is_action_released("pause"):
			_on_settings_confirm_button_pressed()
			get_viewport().set_input_as_handled()
		elif event.is_action_released("ui_cancel"):
			if cancel_button.disabled:
				_on_settings_confirm_button_pressed() # just close the menu, no edits were made
			else:
				_on_settings_cancel_button_pressed() # asks confirmation before closing the menu


func _on_setting_changed(_v=null) -> void:
	cancel_button.disabled = false


func on_visibility_changed() -> void:
	if is_visible_in_tree():
		previous_config = ConfigFile.new()
		previous_config.parse(GGT_GameConfig.config.encode_to_text())
		initialize()
		cancel_button.disabled = true
		username_line_edit.grab_focus()
	else:
		previous_config = null


func initialize(cfg: ConfigFile = GGT_GameConfig.config) -> void:
	username_line_edit.text = cfg.get_value("character", "username", GGT_GameConfig.DEFAULT_USERNAME)
	color_picker_grid.color = cfg.get_value("character", "color", GGT_GameConfig.DEFAULT_PLAYER_COLOR)

func on_username_changed(value: String) -> void:
	GGT_GameConfig.set_username(value)


func on_color_changed(value) -> void:
	GGT_GameConfig.set_player_color(value)


func _on_settings_cancel_button_pressed() -> void:
	_focus_before_modal = get_viewport().gui_get_focus_owner()
	cancel_button_clicked.emit()
	cancel_confirmation_dialog.show_with_text(tr("Are you sure you want to discard your changes?", "settings"))


func _on_cancel_confirmed() -> void:
	if previous_config:
		GGT_GameConfig.revert_to(previous_config)
		initialize(previous_config)
	else:
		initialize()
	cancel_button.disabled = true
	get_viewport().gui_release_focus()


func _on_modal_canceled() -> void:
	if _focus_before_modal:
		_focus_before_modal.grab_focus()


func _on_settings_confirm_button_pressed() -> void:
	if username_line_edit.text.strip_edges().is_empty():
		GGT_GameConfig.set_username(GGT_GameConfig.DEFAULT_USERNAME)
		username_line_edit.text = GGT_GameConfig.DEFAULT_USERNAME
	GGT_GameConfig.persist()
	confirm_button_clicked.emit()


func _on_settings_reset_button_pressed() -> void:
	_focus_before_modal = get_viewport().gui_get_focus_owner()
	reset_confirmation_dialog.show_with_text(tr("Are you sure you want to reset your character to the default values?", "settings"))


func _on_reset_confirmed() -> void:
	GGT_GameConfig.reset_character()
	initialize(GGT_GameConfig.config)
	cancel_button.disabled = false
	if _focus_before_modal:
		_focus_before_modal.grab_focus()
