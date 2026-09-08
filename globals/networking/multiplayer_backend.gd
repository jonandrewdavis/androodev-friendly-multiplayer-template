@abstract
class_name MultiplayerBackend
extends Node
## [b]Custom logic for hosting and joining multiplayer lobbies.[/b]


@warning_ignore_start('unused_signal')
signal lobby_found(address: Variant, cur_players: int, max_players: int)
signal lobby_joined
signal join_lobby_failed(reason: String)
@warning_ignore_restore('unused_signal')


## Host a lobby using the given [param options].
## Minimally these include a maximum number of players and a lobby name,
## but the class can be modified to include whatever data is needed by your chosen [MultiplayerBackend].
@abstract
func host_game(options: HostOptions) -> void


## Join a lobby at the given [param address].
## [param address] is meant to be generic since some [MultiplayerBackend]s will accept
## [String]s while others will accept [int]s or other types.
@abstract
func join_game(address: Variant) -> void


@abstract
func leave_game() -> void


@abstract
func fetch_lobby_list() -> void


func _close_peer() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.get_multiplayer_peer().close()
		multiplayer.set_multiplayer_peer(null)


## Many multiplayer backends will have a method to prevent other players from joining.
## At a bare minimum, we should set a flag that we can return to for [method get_joinable].
@abstract
func set_joinable(joinable: bool) -> void


## Called by the server when a peer connects to validate that we are expecting joins.
## If we aren't, then we can kick that peer.
@abstract
func get_joinable() -> bool


## Generates or retrieves a unique identifier for the peer given by [param peer_id].
## The uid is the way this particular [MultiplayerBackend] distinguishes between different peers
## outside of the context of Godot HLM.
@abstract
func get_uid(peer_id: int) -> Variant


## Generates or retrieves the username for the peer given by [param peer_id].
@abstract
func get_username(peer_id: int) -> String
