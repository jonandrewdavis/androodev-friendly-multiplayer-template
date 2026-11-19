extends Node
## [b]World acts as a global coordinator. It is a scene.[/b][br][br]
## The scene root has MultiplayerSpawners that must be present in the scene tree before
## joining a multipalyer session. Handles listening to signals to spawn entities.

# TODO: Should we consider naming this "Global"? or is "World" good enough


@onready var level_handler: LevelHandler = %LevelHandler
@onready var player_spawner: PlayerSpawner = %PlayerSpawner
@onready var prop_spawner: PropSpawner = %PropSpawner

const MAIN_MENU = preload("uid://c2gocuhw2o7py")
const IN_GAME_MENU = preload("uid://barl4q1kugrmm")

func _ready() -> void:
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	MultiplayerService.game_exited.connect(_on_game_exited)
	multiplayer.server_disconnected.connect(MultiplayerService.leave_game)
	multiplayer.connection_failed.connect(MultiplayerService.leave_game)
	

func _on_lobby_joined() -> void:
	# Always transition to the in game menu.
	# The "MultiplayerService.game_exited" will send them back to the main menu if something fails.
	get_tree().change_scene_to_file(IN_GAME_MENU.resource_path)

	# If we are the server, we must set up the World and indicate we're ready to be joined.
	if multiplayer.is_server():
		# Waiting for the level.
		var first_level_in_list = LevelHandler.LEVEL_DICT.keys()[0]
		await level_handler.spawn_level(first_level_in_list)

		player_spawner.spawn_player(1)
		MultiplayerService.set_joinable(true) # Ready.

func clear() -> void:
	level_handler.clear_level()
	player_spawner.clear_players()
	prop_spawner.clear_props()

func _on_game_exited() -> void:
	clear()
	get_tree().change_scene_to_file(MAIN_MENU.resource_path)
