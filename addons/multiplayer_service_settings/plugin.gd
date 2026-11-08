@tool
extends EditorPlugin


func _enter_tree() -> void:
	var default_label: String = BackendSetup.LABELS[MultiplayerBackend.Type.OFFLINE]
	if not ProjectSettings.has_setting(BackendSetup.SETTING):
		ProjectSettings.set_setting(BackendSetup.SETTING, default_label)
	ProjectSettings.set_initial_value(BackendSetup.SETTING, default_label)
	ProjectSettings.set_as_basic(BackendSetup.SETTING, true)
	ProjectSettings.add_property_info({
		"name": BackendSetup.SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(PackedStringArray(BackendSetup.LABELS.values())),
	})
