extends Control
## F6: interactive control gallery. --capture-theme saves a rendered overview.

const CasualTheme = preload("res://resources/theme/casual_pop_theme.gd")
var columns: GridContainer
var status: Label
var options: OptionButton
var menu: MenuButton
var tabs: TabContainer
var tab_bar: TabBar
var name_input: LineEdit
var notes: TextEdit
var check: CheckBox
var toggle: CheckButton
var slider: HSlider
var vertical_slider: VSlider
var progress: ProgressBar
var primary: Button
var palette_pickers: Array[ColorPickerButton] = []

func _label(text: String, variation := "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label

func _button(text: String, variation := "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: status.text = text + " selected")
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _card(parent: Node, title: String, subtitle: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_content_margin(side, 18)
	panel.add_theme_stylebox_override("panel", frame)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var heading := _label(title)
	heading.add_theme_font_override("font", CasualTheme.BOLD)
	heading.tooltip_text = subtitle
	content.add_child(heading)
	return content

func _report(message: String) -> void:
	status.text = message

func _ready() -> void:
	theme = CasualTheme.new()
	var background := ColorRect.new()
	background.color = Color("19212e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	center.add_child(margin)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 1340
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	var heading := _row(content)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	titles.add_child(_label("Casual Pop / Refined", "TitleLabel"))
	titles.add_child(_label("Soft depth. Precise controls. Color with purpose.", "LabelSmall"))
	var badge := _label("CONTROL GALLERY", "BadgeLabel")
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(badge)
	columns = GridContainer.new()
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 18)
	columns.add_theme_constant_override("v_separation", 18)
	content.add_child(columns)
	status = _label("Ready — try a control, or use Tab to explore keyboard focus.", "LabelSmall")
	_build_buttons()
	_build_inputs()
	_build_choices()
	_build_ranges()
	_build_menus()
	_build_tabs()
	var palette := _row(content)
	palette.add_child(_label("PALETTE", "LabelSmall"))
	for entry in [["Accent", "accent_color"], ["Gradient", "gradient_color"], ["Success", "success_color"], ["Warning", "warning_color"], ["Danger", "danger_color"]]:
		palette.add_child(_label(entry[0], "LabelSmall"))
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(62, 32)
		picker.color = theme.get(entry[1])
		picker.edit_alpha = false
		picker.color_changed.connect(func(color: Color) -> void: theme.set(entry[1], color))
		palette.add_child(picker)
		palette_pickers.append(picker)
	var reset := _button("Reset palette", "OutlineButton")
	reset.pressed.connect(func() -> void:
		theme = CasualTheme.new()
		var properties := ["accent_color", "gradient_color", "success_color", "warning_color", "danger_color"]
		for i in palette_pickers.size():
			palette_pickers[i].color = theme.get(properties[i])
	)
	palette.add_child(reset)
	content.add_child(status)
	resized.connect(func() -> void: _fit(content))
	_fit(content)
	if "--capture-theme" in OS.get_cmdline_user_args():
		for frame in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/casual-pop-refined.png")
		get_tree().quit()

func _fit(content: Control) -> void:
	var narrow := size.x < 1200
	columns.columns = 1 if narrow else 2
	content.custom_minimum_size.x = minf(1340, maxf(600, size.x - 96))

func _build_buttons() -> void:
	var card := _card(columns, "01  /  Buttons", "A quieter silhouette, with filled and outlined actions.")
	var row := _row(card)
	primary = _button("Start game", "PrimaryButton")
	primary.tooltip_text = "Start a new adventure"
	row.add_child(primary)
	row.add_child(_button("Secondary"))
	row.add_child(_button("Outline", "OutlineButton"))
	row = _row(card)
	row.add_child(_button("Confirm", "SuccessButton"))
	row.add_child(_button("Reward", "WarningButton"))
	row.add_child(_button("Remove", "DangerButton"))
	var disabled := _button("Disabled")
	disabled.disabled = true
	row.add_child(disabled)

func _build_inputs() -> void:
	var card := _card(columns, "02  /  Text fields", "Quiet surfaces, a clear caret, and an accent focus ring.")
	var row := _row(card)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter a lobby name"
	name_input.clear_button_enabled = true
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_input)
	var locked := LineEdit.new()
	locked.text = "Read only"
	locked.editable = false
	locked.custom_minimum_size.x = 148
	row.add_child(locked)
	notes = TextEdit.new()
	notes.placeholder_text = "Write a welcome message…"
	notes.custom_minimum_size.y = 96
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes.highlight_current_line = true
	card.add_child(notes)

func _build_choices() -> void:
	var card := _card(columns, "03  /  Checks & switches", "Dedicated indicators. No inherited button backgrounds.")
	var row := _row(card)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	check = CheckBox.new()
	check.text = "Remember lobby"
	check.button_pressed = true
	check.toggled.connect(func(on: bool) -> void: _report("Remember lobby: " + str(on)))
	left.add_child(check)
	var unchecked := CheckBox.new()
	unchecked.text = "Show invitations"
	left.add_child(unchecked)
	var disabled := CheckBox.new()
	disabled.text = "Managed by host"
	disabled.button_pressed = true
	disabled.disabled = true
	left.add_child(disabled)
	toggle = CheckButton.new()
	toggle.text = "Notifications"
	toggle.button_pressed = true
	toggle.toggled.connect(func(on: bool) -> void: _report("Notifications: " + str(on)))
	right.add_child(toggle)
	var off := CheckButton.new()
	off.text = "Private lobby"
	right.add_child(off)
	var locked := CheckButton.new()
	locked.text = "Voice locked"
	locked.disabled = true
	right.add_child(locked)
	var radios := _row(card)
	var group := ButtonGroup.new()
	for i in 2:
		var radio := CheckBox.new()
		radio.text = "Casual" if i == 0 else "Competitive"
		radio.button_group = group
		radio.button_pressed = i == 0
		radios.add_child(radio)

func _build_ranges() -> void:
	var card := _card(columns, "04  /  Sliders & progress", "Slim tracks and crisp handles, horizontal or vertical.")
	var row := _row(card)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var label_row := _row(stack)
	var label := _label("Master volume", "LabelSmall")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)
	var value := _label("65%", "LabelSmall")
	label_row.add_child(value)
	slider = HSlider.new()
	slider.value = 65
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % v
		progress.value = v
	)
	stack.add_child(slider)
	var ticked := HSlider.new()
	ticked.value = 40
	ticked.step = 20
	ticked.tick_count = 6
	stack.add_child(ticked)
	var disabled := HSlider.new()
	disabled.value = 35
	disabled.editable = false
	stack.add_child(disabled)
	progress = ProgressBar.new()
	progress.value = 65
	progress.show_percentage = false
	progress.custom_minimum_size.y = 10
	stack.add_child(progress)
	for i in 2:
		var v := VSlider.new()
		v.value = 70 if i == 0 else 35
		v.custom_minimum_size = Vector2(36, 154)
		v.editable = i == 0
		row.add_child(v)
		if i == 0:
			vertical_slider = v

func _build_menus() -> void:
	var card := _card(columns, "05  /  Menus & dropdowns", "Open these to inspect selection, separators, and submenus.")
	var row := _row(card)
	options = OptionButton.new()
	options.add_item("Europe · Amsterdam")
	options.add_item("US East · Virginia")
	options.add_item("Asia · Singapore")
	options.add_item("Unavailable region")
	options.set_item_disabled(3, true)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.item_selected.connect(func(i: int) -> void: _report("Region: " + options.get_item_text(i)))
	row.add_child(options)
	var disabled := OptionButton.new()
	disabled.add_item("Automatic")
	disabled.disabled = true
	row.add_child(disabled)
	row = _row(card)
	menu = MenuButton.new()
	menu.focus_mode = Control.FOCUS_ALL
	menu.text = "Lobby"
	menu.get_popup().add_item("Invite a friend", 0, KEY_MASK_CTRL | KEY_I)
	menu.get_popup().add_check_item("Friends only", 1)
	menu.get_popup().set_item_checked(1, true)
	menu.get_popup().add_separator()
	var submenu := PopupMenu.new()
	submenu.name = "Region"
	submenu.add_item("Europe")
	submenu.add_item("North America")
	menu.get_popup().add_child(submenu)
	menu.get_popup().add_submenu_item("Region", "Region")
	menu.get_popup().add_item("Leave lobby")
	menu.get_popup().add_item("Host controls")
	menu.get_popup().set_item_disabled(5, true)
	menu.get_popup().id_pressed.connect(func(id: int) -> void:
		if id == 1:
			menu.get_popup().set_item_checked(1, not menu.get_popup().is_item_checked(1))
		_report("Lobby menu: " + str(id))
	)
	row.add_child(menu)
	var view := MenuButton.new()
	view.focus_mode = Control.FOCUS_ALL
	view.text = "View"
	view.get_popup().add_radio_check_item("Compact")
	view.get_popup().add_radio_check_item("Comfortable")
	view.get_popup().set_item_checked(1, true)
	view.get_popup().id_pressed.connect(func(id: int) -> void:
		for i in 2:
			view.get_popup().set_item_checked(i, i == id)
	)
	row.add_child(view)
	var help := MenuButton.new()
	help.text = "Unavailable"
	help.disabled = true
	row.add_child(help)

func _build_tabs() -> void:
	var card := _card(columns, "06  /  Tabs", "Selected color and a fine underline establish hierarchy.")
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 96
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	for title in ["General", "Audio", "Locked"]:
		var body := VBoxContainer.new()
		body.name = title
		body.add_child(_label("Lobby preferences" if title == "General" else "Audio preferences", "LabelSmall"))
		tabs.add_child(body)
	tabs.set_tab_disabled(2, true)
	card.add_child(tabs)
	tab_bar = TabBar.new()
	tab_bar.add_tab("Overview")
	tab_bar.add_tab("Players")
	tab_bar.add_tab("History")
	tab_bar.set_tab_disabled(2, true)
	tab_bar.tab_alignment = TabBar.ALIGNMENT_LEFT
	card.add_child(tab_bar)
