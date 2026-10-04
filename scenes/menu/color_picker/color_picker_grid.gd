@tool
extends Control

class_name ColorPickerGrid

@export var colors = [Color.WHITE, Color.DEEP_PINK, Color.CYAN, Color.BLUE_VIOLET, Color.ROYAL_BLUE, Color.CORAL, Color.FOREST_GREEN, Color.CRIMSON, Color.GOLD]

@onready var toggle_group = ButtonGroup.new()
@onready var color_grid: GridContainer = %ColorGrid

signal color_changed(color)
var color: Color = colors[0]: 
	set = _set_given_color

func _ready() -> void:
	#toggle_group.pressed.connect(_on_local_color_changed)
	for color_string: Color in colors:
		var new_button = Button.new()
		new_button.custom_minimum_size = Vector2(50.0, 50.0)
		new_button.toggle_mode = true
		new_button.button_group = toggle_group

		var style_normal: StyleBoxFlat = get_theme_stylebox('normal', 'Button').duplicate()
		var temp = Color(color_string, 0.5)
		style_normal.bg_color = temp

		var style_pressed: StyleBoxFlat = get_theme_stylebox('pressed', 'Button').duplicate()
		style_pressed.bg_color = color_string
		style_pressed.border_color = Color.WHITE

		new_button.add_theme_stylebox_override('normal', style_normal)
		new_button.add_theme_stylebox_override('pressed', style_pressed)
		new_button.add_theme_stylebox_override('hover', style_pressed)
		new_button.add_theme_stylebox_override('hover_pressed', style_pressed)
		new_button.mouse_default_cursor_shape = 2
		
		color_grid.add_child(new_button)
		
	color = Color.DEEP_PINK

func _on_local_color_changed(button: Button):
	pass
	#var color_from_button = button.get_theme_stylebox('normal').bg_color
	#color = color_from_button
	#color_changed.emit(color_from_button)

func _set_given_color(new_color: Color):
	prints("MATCH", new_color)
	color = new_color
	await get_tree().create_timer(0.2).timeout
	for button in toggle_group.get_buttons():
		#print(button.get_theme_stylebox('normal').bg_color)
		if button.get_theme_stylebox('pressed').bg_color == new_color:
			print("LORD MATCH", button)
			toggle_group.pressed.emit(button)
			return
