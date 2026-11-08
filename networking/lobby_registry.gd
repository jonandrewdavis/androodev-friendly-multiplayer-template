class_name LobbyRegistry
extends Node
## Publicly lists a hosted session. Sends the whole listing on every change and heartbeat; the server upserts it by [member host_token].

const REGISTRY_URL := "https://api.androodev.com/lobbies"
const HEARTBEAT_SECONDS := 5.0

var listing: Dictionary = {}
## Chosen by the host on each publish; proves ownership of the listing to the server.
var host_token := ""
var heartbeat := Timer.new()

func _ready() -> void:
	heartbeat.wait_time = HEARTBEAT_SECONDS
	heartbeat.timeout.connect(_send)
	add_child(heartbeat)

func publish(listing_: Dictionary) -> void:
	listing = listing_.duplicate()
	listing.version = _version()
	host_token = Crypto.new().generate_random_bytes(16).hex_encode()
	heartbeat.start()
	_send()

## Merges [param changes] into the listing and sends it right away. Does nothing while unpublished.
func update(changes: Dictionary) -> void:
	if listing.is_empty():
		return
	listing.merge(changes, true)
	_send()

func unpublish() -> void:
	heartbeat.stop()
	if listing.is_empty():
		return
	listing.clear()
	_request(REGISTRY_URL, HTTPClient.METHOD_DELETE)

func list(app_id: String) -> Array:
	var query := "?app_id=%s&version=%s" % [app_id.uri_encode(), _version().uri_encode()]
	var response: Variant = await _request(REGISTRY_URL + query, HTTPClient.METHOD_GET)
	return response if response is Array else []

func _send() -> void:
	_request(REGISTRY_URL, HTTPClient.METHOD_PUT, listing)

func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

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
