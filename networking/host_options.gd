class_name HostOptions
extends Resource
## Defines all of the configuration options needed when hosting a lobby.
## Minimally, this includes a lobby name and a maximum number of players.
## Some [MultiplayerBackend]s may require additional information to host a lobby,
## in that case you should modify this resource to include whatever information you need.


var max_players: int
var lobby_name: String
