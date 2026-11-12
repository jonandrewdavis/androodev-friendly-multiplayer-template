extends Node3D

@onready var player : CharacterBody3D = get_parent()
@onready var nameplate : Label3D = %Nameplate
@onready var player_mesh: MeshInstance3D = $GeneralSkeleton/PlayerMesh

@export var player_color : Color = Color.WHITE:
	set(value):
		player_color = value
		if is_node_ready():
			_apply_player_color()

@export var username : String = "":
	set(value):
		username = value
		if is_node_ready():
			_apply_username()

func _ready():
	GGT_GameConfig.signal_persist.connect(_apply_config)

# TODO: we should move these off the plaeyr?
func _apply_config():
	player_color = GGT_GameConfig.get_player_color()
	username = GGT_GameConfig.get_username()
	_apply_player_color()
	_apply_username()

## Written by the authority from the character settings, replicated on change.
## NOTE: requires `resource_local_to_scene` on the material to be TRUE, or it'll effect all instances!!
func _apply_player_color() -> void:
	var _material : StandardMaterial3D = player_mesh.get_surface_override_material(0)
	#material.albedo_color = player_color

func _apply_username() -> void:
	nameplate.text = username
