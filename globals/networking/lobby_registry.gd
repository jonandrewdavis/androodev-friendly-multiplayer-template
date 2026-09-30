class_name LobbyRegistry
extends Node
## Publishes and lists lobbies on the ws-tracker-api lobby registry, for backends with no discovery of their own.
## The host heartbeats while published; the server drops lobbies that go silent for ~15s.

const REGISTRY_URL := "https://api.androodev.com/lobbies"
const HEARTBEAT_SECONDS := 5.0

var lobby_id := ""
var host_token := ""
var meta: Dictionary = {}
var heartbeat := Timer.new()

func _ready() -> void:
	heartbeat.wait_time = HEARTBEAT_SECONDS
	heartbeat.timeout.connect(_send_update)
	add_child(heartbeat)

## Lists this lobby on the registry. [param meta] needs [code]app_id, session_id, name, cur_players, max_players, joinable[/code].
func publish(meta_: Dictionary) -> void:
	meta = meta_.duplicate()
	meta.version = ProjectSettings.get_setting("application/config/version", "")
	var sent := meta.duplicate()
	var response: Variant = await _request(REGISTRY_URL, HTTPClient.METHOD_POST, sent)
	if not (response is Dictionary and response.has("lobby_id")):
		return
	lobby_id = response.lobby_id
	host_token = response.host_token
	# Unpublished while the POST was in flight: remove it now instead of letting it linger until the TTL.
	if meta.is_empty():
		unpublish()
		return
	heartbeat.start()
	# Changes made while the POST was in flight (e.g. set_joinable right after hosting) were dropped; send them now.
	if meta != sent:
		_send_update()

## Merges [param changes] into the published metadata and sends them right away.
func update(changes: Dictionary) -> void:
	meta.merge(changes, true)
	_send_update()

func _send_update() -> void:
	if lobby_id.is_empty():
		return
	var response: Variant = await _request("%s/%s" % [REGISTRY_URL, lobby_id], HTTPClient.METHOD_PUT, {"cur_players": meta.cur_players, "joinable": meta.joinable})
	# The server swept us (e.g. after a long stall): publish again.
	if response is Dictionary and response.get("error") == "lobby not found" and not lobby_id.is_empty():
		lobby_id = ""
		publish(meta)

func unpublish() -> void:
	heartbeat.stop()
	meta.clear()
	if lobby_id.is_empty():
		return
	var url := "%s/%s" % [REGISTRY_URL, lobby_id]
	lobby_id = ""
	_request(url, HTTPClient.METHOD_DELETE)
	host_token = ""

## Returns joinable lobbies for [param app_id] as dictionaries with [code]session_id, name, cur_players, max_players[/code].
func list(app_id: String) -> Array:
	var query := "?app_id=%s&version=%s" % [app_id.uri_encode(), str(ProjectSettings.get_setting("application/config/version", "")).uri_encode()]
	var response: Variant = await _request(REGISTRY_URL + query, HTTPClient.METHOD_GET)
	return response if response is Array else []

func _request(url: String, method: HTTPClient.Method, body: Variant = null) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not host_token.is_empty():
		headers.append("Authorization: Bearer " + host_token)
	if http.request(url, headers, method, "" if body == null else JSON.stringify(body)) != OK:
		http.queue_free()
		return null
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		push_warning("Lobby registry request failed: %s" % url)
		return null
	return JSON.parse_string(response[3].get_string_from_utf8())
