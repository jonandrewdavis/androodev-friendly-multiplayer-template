## GGT_GameConfig autoload
extends Node

const CONFIG_FILE_PATH = &"user://settings.cfg"

var config = ConfigFile.new()

signal resolution_scale_changed

const SUPPORTED_LOCALES = {
	"en": "English",
	"it": "Italiano",
	#"ja": "日本語",
	#"zh": "简体中文",
	#"ar": "العربية",
	#"ru": "Русский",
}

enum AudioBus {
	MASTER,
	SFX,
	BGM
}

const FPS_MAX_HARD_CAP = 400

const DEFAULT_USERNAME = "Player"
const DEFAULT_PLAYER_COLOR = Color.WHITE

func _ready() -> void:
	if FileAccess.file_exists(CONFIG_FILE_PATH):
		var err = config.load(CONFIG_FILE_PATH)
		if err != OK:
			reset()
			return
	else:
		reset()

	_apply_settings()


func reset() -> void:
	initialize_default_file()
	config.save(CONFIG_FILE_PATH)
	_apply_settings()


func persist() -> void:
	config.save(CONFIG_FILE_PATH)


func revert_to(cfg: ConfigFile) -> void:
	config.parse(cfg.encode_to_text())
	_apply_settings()


func initialize_default_file() -> void:
	config.set_value("audio", "master", 0.0)
	config.set_value("audio", "sfx", 0.0)
	config.set_value("audio", "music", 0.0)
	config.set_value("gfx", "resolution_scale", 1.0)
	config.set_value("gfx", "fps_limit", 60)
	if not OS.has_feature('web'):
		config.set_value("gfx", "fullscreen", true)
		config.set_value("gfx", "vsync", true)

	var os_locale = OS.get_locale_language()
	if os_locale in SUPPORTED_LOCALES:
		config.set_value("game", "locale", os_locale)
	else:
		config.set_value("game", "locale", "en")


func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioBus.MASTER, config.get_value("audio", "master", AudioServer.get_bus_volume_db(AudioBus.MASTER)))
	AudioServer.set_bus_volume_db(AudioBus.SFX, config.get_value("audio", "sfx", AudioServer.get_bus_volume_db(AudioBus.SFX)))
	AudioServer.set_bus_volume_db(AudioBus.BGM, config.get_value("audio", "music", AudioServer.get_bus_volume_db(AudioBus.BGM)))

	set_resolution_scale(config.get_value("gfx", "resolution_scale", 1.0))

	var fps_limit: int = config.get_value("gfx", "fps_limit", 60)
	Engine.max_fps = fps_limit if fps_limit > 0 else FPS_MAX_HARD_CAP

	TranslationServer.set_locale(config.get_value("game", "locale", "en"))

	if not OS.has_feature('web'):
		var window_id = get_window().get_window_id()
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if config.get_value("gfx", "vsync", true) else DisplayServer.VSYNC_DISABLED,
			window_id
		)
		get_window().mode = Window.MODE_FULLSCREEN if config.get_value("gfx", "fullscreen", true) else Window.MODE_WINDOWED


#region setters
func set_master_volume(v: float) -> void:
	config.set_value("audio", "master", v)
	AudioServer.set_bus_volume_db(AudioBus.MASTER, v)


func set_sfx_volume(v: float) -> void:
	config.set_value("audio", "sfx", v)
	AudioServer.set_bus_volume_db(AudioBus.SFX, v)


func set_music_volume(v: float) -> void:
	config.set_value("audio", "music", v)
	AudioServer.set_bus_volume_db(AudioBus.BGM, v)


func set_resolution_scale(v: float) -> void:
	config.set_value("gfx", "resolution_scale", v)
	get_tree().root.scaling_3d_scale = v
	if get_node_or_null("/root/DebugMenu"):
		get_node_or_null("/root/DebugMenu").call_deferred("update_settings_label")
	resolution_scale_changed.emit()


func set_vsync(v: bool) -> void:
	config.set_value("gfx", "vsync", v)
	var window_id = get_window().get_window_id()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED,
		window_id
	)


func set_fps_limit(v: int) -> void:
	config.set_value("gfx", "fps_limit", v)
	Engine.max_fps = v if v > 0 else FPS_MAX_HARD_CAP


func set_fullscreen(v: bool) -> void:
	config.set_value("gfx", "fullscreen", v)
	get_window().mode = Window.MODE_FULLSCREEN if v else Window.MODE_WINDOWED


func set_locale(locale: String) -> void:
	config.set_value("game", "locale", locale)
	TranslationServer.set_locale(locale)


func set_username(new_username: String) -> void:
	config.set_value("character", "username", new_username.strip_edges())


func set_player_color(new_color: Color) -> void:
	config.set_value("character", "color", new_color)


func reset_character() -> void:
	set_username(DEFAULT_USERNAME)
	set_player_color(DEFAULT_PLAYER_COLOR)
#endregion


#region getters
func get_resolution_scale() -> float:
	return float(config.get_value("gfx", "resolution_scale"))


func get_locale() -> String:
	return config.get_value("game", "locale", "en")


func get_username() -> String:
	var username: String = config.get_value("character", "username", DEFAULT_USERNAME)
	return username if not username.is_empty() else DEFAULT_USERNAME


func get_player_color() -> Color:
	return config.get_value("character", "color", DEFAULT_PLAYER_COLOR)
#endregion
