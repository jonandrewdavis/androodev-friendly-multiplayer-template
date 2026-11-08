@tool
class_name BackendSetup
extends RefCounted
## [b]Chooses the multiplayer backend and checks that its setup is in place.[/b][br][br]
## The backend comes from the [constant SETTING] project setting, unless the export has a feature tag
## matching a backend's lowercase label (e.g. [code]tube[/code]), which takes priority.[br][br]
## Backend scripts reference optional addons directly and fail to compile without them,
## so [method get_setup_error] must pass before one is loaded.[br][br]
## To add a backend, extend [enum MultiplayerBackend.Type], [constant LABELS], [constant SCRIPTS],
## [method get_setup_error], and [constant MultiplayerService.ADDRESS_HINTS].

const SETTING := "MultiplayerService/settings/backend"

const LABELS := {
	MultiplayerBackend.Type.OFFLINE: "Offline",
	MultiplayerBackend.Type.ENET: "ENet",
	MultiplayerBackend.Type.NODETUNNEL: "NodeTunnel",
	MultiplayerBackend.Type.STEAM: "Steam",
	MultiplayerBackend.Type.TUBE: "Tube",
	MultiplayerBackend.Type.EOS: "EOS",
}

const SCRIPTS := {
	MultiplayerBackend.Type.OFFLINE: "res://networking/offline_backend.gd",
	MultiplayerBackend.Type.ENET: "res://networking/enet_backend.gd",
	MultiplayerBackend.Type.NODETUNNEL: "res://networking/nodetunnel_backend.gd",
	MultiplayerBackend.Type.STEAM: "res://networking/steam_backend.gd",
	MultiplayerBackend.Type.TUBE: "res://networking/tube_backend.gd",
	MultiplayerBackend.Type.EOS: "res://networking/eos_backend.gd",
}


## The backend this build should start with. If several feature tags match, the first in [constant SCRIPTS] wins.
static func get_configured_type() -> MultiplayerBackend.Type:
	for type: MultiplayerBackend.Type in SCRIPTS:
		if OS.has_feature(LABELS[type].to_lower()):
			return type
	var configured: Variant = LABELS.find_key(ProjectSettings.get_setting(SETTING, LABELS[MultiplayerBackend.Type.OFFLINE]))
	return MultiplayerBackend.Type.OFFLINE if configured == null else configured


## Backends that can run in this build, for debug tools.
static func get_available_types() -> Array[MultiplayerBackend.Type]:
	var available: Array[MultiplayerBackend.Type] = []
	for type: MultiplayerBackend.Type in SCRIPTS:
		if get_setup_error(type).is_empty():
			available.append(type)
	return available


## Returns what is missing for [param type] to run in this build, or an empty string if it can.
static func get_setup_error(type: MultiplayerBackend.Type) -> String:
	match type:
		MultiplayerBackend.Type.ENET:
			if OS.has_feature("web"):
				return "ENet is not available on web exports."
		MultiplayerBackend.Type.NODETUNNEL:
			if not ClassDB.class_exists("NodeTunnelPeer"):
				return "NodeTunnel needs the NodeTunnel addon (addons/nodetunnel), which has no web build."
		MultiplayerBackend.Type.STEAM:
			if not (ClassDB.class_exists("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")):
				return "Steam needs the GodotSteam addon (addons/godotsteam), which has no web build."
		MultiplayerBackend.Type.TUBE:
			if not _has_script_class("TubeClient"):
				return "Tube needs the Tube addon (addons/tube)."
			if not OS.has_feature("web") and not ClassDB.class_exists("WebRTCLibPeerConnection"):
				return "Tube needs the WebRTC native addon (addons/webrtc_native) outside of web exports."
		MultiplayerBackend.Type.EOS:
			if not ClassDB.class_exists("EOSGMultiplayerPeer"):
				return "EOS needs the Epic Online Services addon (addons/epic-online-services-godot), which has no web build."
			for autoload: String in ["HPlatform", "HAuth", "HLobbies"]:
				if not ProjectSettings.has_setting("autoload/" + autoload):
					return "EOS needs the %s autoload. Enable the Epic Online Services plugin." % autoload
	return ""


static func _has_script_class(script_class: String) -> bool:
	return ProjectSettings.get_global_class_list().any(func(entry: Dictionary) -> bool: return entry.class == script_class)
