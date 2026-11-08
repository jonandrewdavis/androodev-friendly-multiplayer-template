@tool
extends Control

class_name ColorPickerGrid

@export var colors = [Color.WHITE, Color.DEEP_PINK, Color.CYAN, Color.BLUE_VIOLET, Color.ROYAL_BLUE, Color.CORAL, Color.FOREST_GREEN, Color.CRIMSON, Color.GOLD]
@export var toggle_group: ButtonGroup
@onready var color_grid: GridContainer = %ColorGrid

signal color_changed(color)

@export var color: Color = colors[0]: 
	set = _set_given_color

func _ready() -> void:
	toggle_group.pressed.connect(_on_local_color_changed)
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

	_highlight_button(color)


func _on_local_color_changed(button: Button):
	color = button.get_theme_stylebox('pressed').bg_color
	color_changed.emit(color)

func _set_given_color(new_color: Color):
	color = new_color
	if is_node_ready():
		_highlight_button(new_color)

func _highlight_button(target: Color):
	if not toggle_group: return
	# set_pressed_no_signal doesn't unpress the rest of the ButtonGroup, so set every button explicitly
	for button in toggle_group.get_buttons():
		button.set_pressed_no_signal(button.get_theme_stylebox('pressed').bg_color.is_equal_approx(target))
