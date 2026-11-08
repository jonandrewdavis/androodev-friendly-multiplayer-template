extends Node

const MENU_SCENE := "res://scenes/menu/menu.tscn"
const IN_GAME_MENU_SCENE := "res://scenes/menu/in_game_menu/in_game_menu.tscn"

var target_scene := ""
var moving_to_target := false

@onready var level_loader: LevelLoader = %LevelLoader
@onready var player_spawner: PlayerSpawner = %PlayerSpawner
@onready var prop_spawner: PropSpawner = %PropSpawner

func _ready() -> void:
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	MultiplayerService.game_exited.connect(_on_game_exited)
	multiplayer.server_disconnected.connect(MultiplayerService.leave_game)
	multiplayer.connection_failed.connect(MultiplayerService.leave_game)
	
	if multiplayer.is_server():
		MultiplayerService.lobby_joined.connect(_on_lobby_joined_server)
		
func _on_lobby_joined() -> void:
	_go_to_scene(IN_GAME_MENU_SCENE)

func _on_lobby_joined_server():
	if not await level_loader.spawn_level(LevelLoader.LEVEL_DICT.keys()[0]):
		return
	if not multiplayer.is_server():
		return
	player_spawner.spawn_player(1)
	MultiplayerService.set_joinable(true)

func _on_game_exited() -> void:
	clear()
	_go_to_scene(MENU_SCENE)

## Moves to [param path] once any scene change in progress has finished.
## Does nothing if already there, so failing to connect from the menu doesn't reload it.
func _go_to_scene(path: String) -> void:
	target_scene = path
	if moving_to_target:
		return
	moving_to_target = true
	while GGT.is_changing_scene() or get_tree().current_scene.scene_file_path != target_scene:
		if not GGT.is_changing_scene():
			GGT.change_scene(target_scene, {"show_progress_bar": false})
		await get_tree().process_frame
	moving_to_target = false

func clear() -> void:
	player_spawner.clear_players()
	level_loader.clear_level()

func change_level(key: String) -> void:
	if multiplayer.is_server() and LevelLoader.LEVEL_DICT.has(key):
		level_loader.spawn_level.rpc(key)
