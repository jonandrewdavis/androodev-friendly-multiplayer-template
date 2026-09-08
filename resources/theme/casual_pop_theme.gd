@tool
extends Theme
## Procedural, resolution-independent casual UI. Palette edits rebuild all states.

@export var accent_color: Color = Color("67b7ff"):
	set(value):
		accent_color = value
		rebuild()
@export var success_color: Color = Color("72dfb2"):
	set(value):
		success_color = value
		rebuild()
@export var warning_color: Color = Color("ffd477"):
	set(value):
		warning_color = value
		rebuild()
@export var danger_color: Color = Color("ff8b99"):
	set(value):
		danger_color = value
		rebuild()
@export var surface_color: Color = Color("253451"):
	set(value):
		surface_color = value
		rebuild()
@export_range(4, 28, 1) var corner_radius: int = 14:
	set(value):
		corner_radius = value
		rebuild()
@export_range(0, 10, 1) var elevation: int = 5:
	set(value):
		elevation = value
		rebuild()

const INK = Color("14213b")
const PAPER = Color("f5f8ff")
const REGULAR = preload("res://assets/fonts/Lato-Regular.ttf")
const BOLD = preload("res://assets/fonts/Lato-Bold.ttf")
const BLACK = preload("res://assets/fonts/Lato-Black.ttf")

func _init() -> void:
	rebuild()

func _box(color: Color, depth: int = 0, padding: Vector2 = Vector2(22, 12)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner_radius)
	box.corner_detail = 12
	box.set_border_width_all(1)
	box.border_width_bottom = 1 + depth
	box.border_color = color.darkened(0.30)
	box.shadow_color = Color(0.015, 0.025, 0.06, 0.30)
	box.shadow_size = depth
	box.shadow_offset = Vector2(0, depth * 0.6)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box

func _ink_on(color: Color) -> Color:
	# Choose the higher WCAG contrast of our dark ink and white.
	var luminance := color.srgb_to_linear().get_luminance()
	var dark_luminance := INK.srgb_to_linear().get_luminance()
	return INK if (luminance + 0.05) / (dark_luminance + 0.05) > 1.05 / (luminance + 0.05) else Color.WHITE

func _buttons(type: StringName, color: Color) -> void:
	var hover := color.lightened(0.10)
	var pressed := color.darkened(0.08)
	set_stylebox("normal", type, _box(color, elevation))
	set_stylebox("hover", type, _box(hover, elevation))
	set_stylebox("pressed", type, _box(pressed, 1 if elevation > 0 else 0))
	set_stylebox("hover_pressed", type, _box(pressed, 1 if elevation > 0 else 0))
	set_stylebox("disabled", type, _box(surface_color.lerp(PAPER, 0.06)))
	set_color("font_color", type, _ink_on(color))
	set_color("font_hover_color", type, _ink_on(hover))
	set_color("font_pressed_color", type, _ink_on(pressed))
	set_color("font_hover_pressed_color", type, _ink_on(pressed))
	set_color("font_focus_color", type, _ink_on(color))
	set_color("font_disabled_color", type, surface_color.lerp(PAPER, 0.42))
	set_font("font", type, BOLD)

func rebuild() -> void:
	default_font = REGULAR
	default_font_size = 22
	var focus := _box(accent_color)
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = accent_color.lightened(0.35)
	focus.set_expand_margin_all(3)
	for type in [&"Button", &"OptionButton"]:
		_buttons(type, surface_color.lightened(0.12))
		set_stylebox("focus", type, focus)
	var variations := {"PrimaryButton": accent_color, "SuccessButton": success_color, "WarningButton": warning_color, "DangerButton": danger_color}
	for type in variations:
		set_type_variation(type, &"Button")
		_buttons(type, variations[type])
	var panel := _box(surface_color, elevation, Vector2(24, 24))
	panel.set_corner_radius_all(corner_radius + 6)
	panel.border_color = surface_color.lightened(0.16)
	panel.shadow_size = elevation * 2
	for type in [&"Panel", &"PanelContainer", &"PopupPanel", &"PopupMenu", &"TooltipPanel"]:
		set_stylebox("panel", type, panel)
	set_type_variation(&"AccentPanel", &"PanelContainer")
	var accent_panel := panel.duplicate() as StyleBoxFlat
	accent_panel.border_width_top = 4
	accent_panel.border_color = accent_color
	set_stylebox("panel", &"AccentPanel", accent_panel)
	set_color("font_color", &"Label", PAPER)
	set_type_variation(&"TitleLabel", &"Label")
	set_font("font", &"TitleLabel", BLACK)
	set_font_size("font_size", &"TitleLabel", 36)
	set_type_variation(&"LabelSmall", &"Label")
	set_font_size("font_size", &"LabelSmall", 16)
	set_color("font_color", &"LabelSmall", surface_color.lerp(PAPER, 0.70))
	set_type_variation(&"BadgeLabel", &"Label")
	set_font("font", &"BadgeLabel", BLACK)
	set_font_size("font_size", &"BadgeLabel", 16)
	set_color("font_color", &"BadgeLabel", _ink_on(warning_color))
	set_stylebox("normal", &"BadgeLabel", _box(warning_color, 0, Vector2(12, 6)))
	set_color("default_color", &"RichTextLabel", PAPER)
	set_font("bold_font", &"RichTextLabel", BOLD)
	set_color("font_color", &"TooltipLabel", PAPER)
	for type in [&"LineEdit", &"TextEdit"]:
		set_stylebox("normal", type, _box(surface_color.darkened(0.30), 0, Vector2(14, 12)))
		set_stylebox("read_only", type, _box(surface_color.darkened(0.15), 0, Vector2(14, 12)))
		set_stylebox("focus", type, focus)
		set_color("font_color", type, PAPER)
		set_color("font_placeholder_color", type, surface_color.lerp(PAPER, 0.60))
		set_color("caret_color", type, accent_color)
		set_color("selection_color", type, Color(accent_color, 0.35))
	set_stylebox("hover", &"PopupMenu", _box(accent_color, 0, Vector2(10, 8)))
	set_color("font_color", &"PopupMenu", PAPER)
	set_color("font_hover_color", &"PopupMenu", _ink_on(accent_color))
	set_constant("v_separation", &"PopupMenu", 12)
	var track := _box(surface_color.darkened(0.35), 0, Vector2(4, 5))
	var fill := _box(accent_color, 0, Vector2(4, 5))
	for type in [&"HSlider", &"VSlider"]:
		set_stylebox("slider", type, track)
		set_stylebox("grabber_area", type, fill)
		set_stylebox("grabber_area_highlight", type, fill)
	set_stylebox("background", &"ProgressBar", track)
	set_stylebox("fill", &"ProgressBar", fill)
	set_color("font_color", &"ProgressBar", PAPER)
	set_color("font_outline_color", &"ProgressBar", INK)
	set_constant("outline_size", &"ProgressBar", 4)
	for type in [&"CheckBox", &"CheckButton"]:
		set_color("font_color", type, PAPER)
		set_color("font_hover_color", type, accent_color)
		set_stylebox("focus", type, focus)
	for type in [&"HBoxContainer", &"VBoxContainer"]:
		set_constant("separation", type, 14)
	var separator := StyleBoxLine.new()
	separator.color = surface_color.lightened(0.16)
	set_stylebox("separator", &"HSeparator", separator)
	set_constant("separation", &"HSeparator", 16)
	emit_changed()
