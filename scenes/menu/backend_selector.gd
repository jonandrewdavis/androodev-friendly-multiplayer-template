class_name BackendSelector
extends OptionButton
## Debug-only dropdown for switching the multiplayer backend at runtime. Removes itself from release builds.
## Self-contained: add the scene to a menu, or delete the node to remove it.


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for type in BackendSetup.get_available_types():
		add_item(BackendSetup.LABELS[type], type)
	_select_type(MultiplayerService.backend_type)
	MultiplayerService.backend_changed.connect(_select_type)
	item_selected.connect(_on_item_selected)


func _select_type(type: MultiplayerBackend.Type) -> void:
	select(get_item_index(type))


func _on_item_selected(index: int) -> void:
	MultiplayerService.set_backend(get_item_id(index) as MultiplayerBackend.Type)
