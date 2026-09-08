extends Control
## Run this scene (F6) to explore the second theme without switching the project.

const CasualTheme = preload("res://resources/theme/casual_pop_theme.gd")

func _label(text: String, variation: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label

func _button(text: String, variation: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _ready() -> void:
	theme = CasualTheme.new()
	var background := ColorRect.new()
	background.color = Color("14213b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"AccentPanel"
	panel.custom_minimum_size.x = 760
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label("Ready, set, play.", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("CASUAL POP", "BadgeLabel"))
	content.add_child(_label("A little more color. A little more character.", "LabelSmall"))
	var actions := HBoxContainer.new()
	content.add_child(actions)
	actions.add_child(_button("Host game", "PrimaryButton"))
	actions.add_child(_button("Join friends", "SuccessButton"))
	actions.add_child(_button("Settings"))
	var states := HBoxContainer.new()
	content.add_child(states)
	states.add_child(_button("Claim reward", "WarningButton"))
	states.add_child(_button("Leave lobby", "DangerButton"))
	var disabled := _button("Unavailable")
	disabled.disabled = true
	states.add_child(disabled)
	content.add_child(HSeparator.new())
	content.add_child(_label("Your lobby"))
	var input := LineEdit.new()
	input.placeholder_text = "Give your next adventure a name"
	content.add_child(input)
	var row := HBoxContainer.new()
	content.add_child(row)
	var option := OptionButton.new()
	option.add_item("4 players")
	option.add_item("2 players")
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	var check := CheckButton.new()
	check.text = "Friends only"
	check.button_pressed = true
	row.add_child(check)
	var progress := ProgressBar.new()
	progress.value = 65
	progress.custom_minimum_size.y = 26
	content.add_child(progress)
	var slider := HSlider.new()
	slider.value = 65
	slider.value_changed.connect(func(value: float) -> void: progress.value = value)
	content.add_child(slider)
	content.add_child(HSeparator.new())
	var palette := HBoxContainer.new()
	content.add_child(palette)
	for entry in [["Accent", "accent_color"], ["Mint", "success_color"], ["Gold", "warning_color"], ["Coral", "danger_color"]]:
		palette.add_child(_label(entry[0], "LabelSmall"))
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(62, 36)
		picker.color = theme.get(entry[1])
		picker.edit_alpha = false
		picker.color_changed.connect(func(color: Color) -> void: theme.set(entry[1], color))
		palette.add_child(picker)
	content.add_child(_label("Try the colors above. Hover, press, or Tab through the controls.", "LabelSmall"))
	if "--capture-theme" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/casual-pop-preview.png")
		get_tree().quit()
