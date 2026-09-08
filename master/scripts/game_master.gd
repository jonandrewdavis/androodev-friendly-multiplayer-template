class_name GameMaster
extends Node
## Responsible for driving and managing the global game state.


@onready var main_menu_scene: PackedScene = preload("uid://bw5mw614jt72i")
@onready var main_menu: MainMenu = $MainMenu
@onready var player_spawner: PlayerSpawner = $PlayerSpawner
@onready var level_loader: LevelLoader = $LevelLoader


func _ready() -> void:
	MultiplayerService.lobby_joined.connect(start_game)
	MultiplayerService.game_exited.connect(exit_to_main_menu)
	multiplayer.server_disconnected.connect(exit_to_main_menu)


func start_game() -> void:
	if multiplayer.is_server():
		await level_loader.spawn_level('example')
		player_spawner.spawn_player(1)
		MultiplayerService.set_joinable(true)
	else:
		await multiplayer.connected_to_server
	main_menu.queue_free()


func exit_to_main_menu() -> void:
	if main_menu == null: # ignore if the signal was called while we're still on the main menu
		player_spawner.clear_players()
		level_loader.clear_level()
		main_menu = main_menu_scene.instantiate()
		add_child(main_menu)
