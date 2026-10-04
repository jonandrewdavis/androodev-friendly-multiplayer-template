extends Node

var session := 0
@onready var level_loader: LevelLoader = %LevelLoader
@onready var player_spawner: PlayerSpawner = %PlayerSpawner

func _ready() -> void:
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	MultiplayerService.game_exited.connect(clear)
	multiplayer.server_disconnected.connect(MultiplayerService.leave_game)
	multiplayer.connection_failed.connect(MultiplayerService.leave_game)

func _on_lobby_joined() -> void:
	if not multiplayer.is_server():
		return
	session += 1
	var token := session
	await level_loader.spawn_level(LevelLoader.LEVEL_DICT.keys()[0])
	if token != session or not multiplayer.is_server():
		return
	player_spawner.spawn_player(1)
	if MultiplayerService.backend.has_active_session(): # offline games aren't advertised
		MultiplayerService.set_joinable(true)

func clear() -> void:
	session += 1
	player_spawner.clear_players()
	level_loader.clear_level()

func change_level(key: String) -> void:
	if multiplayer.is_server() and LevelLoader.LEVEL_DICT.has(key):
		level_loader.spawn_level.rpc(key)
