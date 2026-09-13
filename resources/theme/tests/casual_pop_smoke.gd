extends Node
## Run headless for assertions; add -- --visual for rendered interaction captures.

const Preview = preload("res://resources/theme/casual_pop_preview.tscn")
const CasualTheme = preload("res://resources/theme/casual_pop_theme.gd")
var gallery: Control
var visual := false
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _settle() -> void:
	for i in 5:
		await get_tree().process_frame

func _capture(name: String) -> void:
	await _settle()
	if visual:
		# A covered desktop window may skip automatic draws; explicitly render
		# before reading back so captures do not wait indefinitely for a signal.
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("/tmp/casual-pop-" + name + ".png")

func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	get_viewport().gui_embed_subwindows = true
	if visual:
		get_window().grab_focus()
		Input.warp_mouse(Vector2(40, 40))
	gallery = Preview.instantiate()
	add_child(gallery)
	await _settle()
	if visual:
		await _visual_states()
		get_tree().quit()
		return
	var theme = gallery.theme
	for type in ["Button", "MenuButton", "OptionButton", "CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			expect(theme.has_stylebox(state, type), type + ": missing " + state)
		var minimum: Vector2 = theme.get_stylebox("normal", type).get_minimum_size()
		for state in ["hover", "pressed", "disabled"]:
			expect(theme.get_stylebox(state, type).get_minimum_size() == minimum, type + ": state changes layout")
	for type in ["CheckBox", "CheckButton"]:
		for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
			expect(theme.has_icon(state, type), type + ": missing " + state)
	for type in ["TabBar", "TabContainer"]:
		for state in ["tab_unselected", "tab_selected", "tab_hovered", "tab_disabled", "tab_focus"]:
			expect(theme.has_stylebox(state, type), type + ": missing " + state)
	for type in ["HSlider", "VSlider"]:
		for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
			expect(theme.has_icon(state, type), type + ": missing " + state)
	await _capture("refined")
	gallery.check.grab_focus()
	await _key(KEY_SPACE)
	expect(not gallery.check.button_pressed, "Checkbox keyboard toggle failed")
	gallery.toggle.grab_focus()
	await _key(KEY_SPACE)
	expect(not gallery.toggle.button_pressed, "Switch keyboard toggle failed")
	gallery.slider.grab_focus()
	await _key(KEY_RIGHT)
	expect(gallery.slider.value > 65, "Horizontal slider keyboard input failed")
	expect(gallery.progress.value == gallery.slider.value, "Slider/progress binding failed")
	gallery.vertical_slider.grab_focus()
	await _key(KEY_UP)
	expect(gallery.vertical_slider.value > 70, "Vertical slider keyboard input failed")
	gallery.tab_bar.grab_focus()
	await _key(KEY_RIGHT)
	expect(gallery.tab_bar.current_tab == 1, "TabBar keyboard input failed")
	gallery.tabs.get_tab_bar().grab_focus()
	await _key(KEY_RIGHT)
	expect(gallery.tabs.current_tab == 1, "TabContainer keyboard input failed")
	gallery.name_input.text = "Friday night crew"
	gallery.name_input.grab_focus()
	gallery.name_input.select(0, 6)
	gallery.notes.text = "Welcome back. Pick a team and join the lobby.\nBring your best game."
	await _capture("fields-focus")
	gallery.notes.grab_focus()
	gallery.notes.select(0, 0, 0, 12)
	await _capture("textedit-focus")
	gallery.options.grab_focus()
	await _settle()
	await _key(KEY_SPACE)
	await _settle()
	var popup: PopupMenu = gallery.options.get_popup()
	expect(popup.visible, "OptionButton popup did not open")
	popup.set_focused_item(1)
	await _capture("dropdown")
	popup.grab_focus()
	popup.set_focused_item(1)
	await _key(KEY_ENTER)
	expect(gallery.options.selected == 1, "Dropdown keyboard selection failed")
	popup.hide()
	var menu_popup: PopupMenu = gallery.menu.get_popup()
	gallery.menu.grab_focus()
	await _key(KEY_SPACE)
	expect(menu_popup.visible, "MenuButton keyboard opening failed")
	menu_popup.set_focused_item(1)
	await _capture("menu")
	menu_popup.set_focused_item(3)
	menu_popup.grab_focus()
	await _key(KEY_RIGHT)
	await _capture("submenu")
	(menu_popup.get_node("Region") as PopupMenu).hide()
	menu_popup.hide()
	gallery.toggle.layout_direction = Control.LAYOUT_DIRECTION_RTL
	gallery.toggle.button_pressed = true
	gallery.options.get_parent().layout_direction = Control.LAYOUT_DIRECTION_RTL
	gallery.options.get_parent().queue_sort()
	await _capture("rtl")
	gallery.toggle.layout_direction = Control.LAYOUT_DIRECTION_LTR
	gallery.options.get_parent().layout_direction = Control.LAYOUT_DIRECTION_LTR
	gallery.options.get_parent().queue_sort()
	var old_icon: Image = theme.get_icon("checked", "CheckBox").get_image()
	theme.accent_color = Color("bf98ef")
	theme.gradient_color = Color("ed99bb")
	gallery.palette_pickers[0].color = theme.accent_color
	gallery.palette_pickers[1].color = theme.gradient_color
	var new_icon: Image = theme.get_icon("checked", "CheckBox").get_image()
	expect(old_icon.get_data() != new_icon.get_data(), "Palette did not regenerate checkbox artwork")
	expect(theme.get_stylebox("grabber_area", "HSlider").bg_color == theme.accent_color, "Palette did not update slider fill")
	expect(CasualTheme.new().accent_color != theme.accent_color, "Theme instances share palette state")
	await _capture("alternate-palette")
	var path := "user://casual-pop-smoke-roundtrip.tres"
	expect(ResourceSaver.save(theme, path) == OK, "Theme save failed")
	expect(FileAccess.get_file_as_bytes(path).size() < 1048576, "Theme serialized uncompressed pixel data")
	var restored = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	expect(restored != null and restored.accent_color == theme.accent_color, "Palette save/reload failed")
	if restored:
		expect(restored.get_icon("checked", "CheckBox").get_image().get_data() == new_icon.get_data(), "Icon save/reload failed")
		var before: Image = restored.get_icon("checked", "CheckBox").get_image()
		restored.accent_color = Color("53d6a3")
		expect(restored.get_icon("checked", "CheckBox").get_image().get_data() != before.get_data(), "Reloaded theme cannot recolor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CASUAL POP PASS" if failures.is_empty() else "CASUAL POP FAILED: " + str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func _visual_states() -> void:
	# Behavioral checks run headless above. Hold popup windows open for snapshots
	# so unrelated desktop focus changes cannot dismiss them mid-capture.
	await _capture("refined")
	gallery.name_input.text = "Friday night crew"
	gallery.name_input.grab_focus()
	gallery.name_input.select(0, 6)
	gallery.notes.text = "Welcome back. Pick a team and join the lobby.\nBring your best game."
	await _capture("fields-focus")
	gallery.notes.grab_focus()
	gallery.notes.select(0, 0, 0, 12)
	await _capture("textedit-focus")
	gallery.notes.release_focus()
	var dropdown: PopupMenu = gallery.options.get_popup()
	dropdown.popup_window = false
	dropdown.transient = false
	gallery.options.show_popup()
	dropdown.set_focused_item(1)
	await _capture("dropdown")
	dropdown.hide()
	var popup: PopupMenu = gallery.menu.get_popup()
	popup.popup_window = false
	popup.transient = false
	popup.position = Vector2i(gallery.menu.global_position + Vector2(0, gallery.menu.size.y))
	popup.popup()
	popup.set_focused_item(1)
	await _capture("menu")
	var submenu := popup.get_node("Region") as PopupMenu
	submenu.popup_window = false
	submenu.transient = false
	submenu.position = popup.position + Vector2i(popup.size.x, 80)
	submenu.popup()
	popup.set_focused_item(3)
	await _capture("submenu")
	submenu.hide()
	popup.hide()
	gallery.options.get_parent().layout_direction = Control.LAYOUT_DIRECTION_RTL
	gallery.options.get_parent().queue_sort()
	gallery.toggle.layout_direction = Control.LAYOUT_DIRECTION_RTL
	await _capture("rtl")
	gallery.options.get_parent().layout_direction = Control.LAYOUT_DIRECTION_LTR
	gallery.options.get_parent().queue_sort()
	gallery.toggle.layout_direction = Control.LAYOUT_DIRECTION_LTR
	gallery.theme.accent_color = Color("bf98ef")
	gallery.theme.gradient_color = Color("ed99bb")
	gallery.palette_pickers[0].color = gallery.theme.accent_color
	gallery.palette_pickers[1].color = gallery.theme.gradient_color
	await _capture("alternate-palette")
	print("CASUAL POP VISUAL CAPTURES COMPLETE")
