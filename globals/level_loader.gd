class_name LevelLoader
extends Node

const WAIT_INTERVAL := 0.1
const LEVEL_DICT: Dictionary[String, String] = {
	"castle": "uid://xgs22y8bv2cw"
}

signal load_progress(progress: float)

var current_key := ""
var generation := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and not current_key.is_empty():
		spawn_level.rpc_id(peer_id, current_key)

func clear_level() -> void:
	generation += 1
	current_key = ""
	for child in get_children():
		remove_child(child)
		child.queue_free()


@rpc("authority", "call_local", "reliable")
func spawn_level(key: String) -> bool:
	if not LEVEL_DICT.has(key):
		return false
	clear_level()
	current_key = key
	var token := generation
	var path := LEVEL_DICT[key]
	var err := ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		push_error("Could not load level: ", key)
		MultiplayerService.leave_game()
		return false
	var progress := []
	load_progress.emit(0.0)
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		load_progress.emit(progress[0])
		await get_tree().create_timer(WAIT_INTERVAL).timeout
		if token != generation:
			return false
	if token != generation:
		return false
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Could not load level: ", key)
		MultiplayerService.leave_game()
		return false
	load_progress.emit(1.0)
	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	add_child(packed.instantiate())
	return true
