extends Node
## [b]World acts as a global coordinator. It is a scene.[/b][br][br]
## The scene root has MultiplayerSpawners that must be present in the scene tree before
## joining a multipalyer session. Handles listening to signals to spawn entities.

const MAIN_MENU = "res://menu/menu.tscn"
const IN_GAME_MENU = "res://menu/in_game_menu/in_game_menu.tscn"

var target_scene := ""
var moving_to_target := false

@onready var level_handler: LevelHandler = %LevelHandler
@onready var player_spawner: PlayerSpawner = %PlayerSpawner
@onready var prop_spawner: PropSpawner = %PropSpawner



func _ready() -> void:
	MultiplayerService.lobby_joined.connect(_on_lobby_joined)
	MultiplayerService.game_exited.connect(_on_game_exited)
	multiplayer.server_disconnected.connect(MultiplayerService.leave_game)
	multiplayer.connection_failed.connect(MultiplayerService.leave_game)
	

func _on_lobby_joined() -> void:
	# Always transition to the in game menu.
	# The "MultiplayerService.game_exited" will send them back to the main menu if something fails.
	GGT.change_scene(IN_GAME_MENU)

	# If we are the server, we must set up the World and indicate we're ready to be joined.
	if multiplayer.is_server():
		# Waiting for the level.
		var first_level_in_list = LevelHandler.LEVEL_DICT.keys()[0]
		await level_handler.spawn_level(first_level_in_list)

		player_spawner.spawn_player(1)
		MultiplayerService.set_joinable(true) # Ready.

func clear_all() -> void:
	level_handler.clear()
	player_spawner.clear()
	prop_spawner.clear()


func _on_game_exited() -> void:
	clear_all()
	GGT.change_scene(MAIN_MENU)
