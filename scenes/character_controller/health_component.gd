extends Node
class_name HealthComponent

signal health_changed(health: float, max_health: float)
signal damaged(amount: float, source_id: int)
signal healed(amount: float)
signal died

const ENVIRONMENT_SOURCE := 0

@export var max_health: float = 100.0 : set = set_max_health
@export var health: float = 100.0 : set = _set_health
@export var allow_self_damage: bool = false
@export var invulnerable: bool = false

@export_group("Regeneration")
@export var regen_amount: float = 0.0
@export var regen_interval: float = 1.0
@export var regen_delay: float = 3.0

var _time_since_damage: float = 0.0
var _regen_timer: float = 0.0

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	set_process(multiplayer.is_server())

func _process(delta: float) -> void:
	if regen_amount <= 0 or is_dead() or health >= max_health:
		return
	_time_since_damage += delta
	if _time_since_damage < regen_delay:
		return
	_regen_timer += delta
	if _regen_timer >= regen_interval:
		_regen_timer = 0.0
		heal(regen_amount)

func damage(amount: float, source_id: int) -> void:
	if not can_take_damage(amount, source_id):
		return
	_time_since_damage = 0.0
	_regen_timer = 0.0
	health -= amount
	damaged.emit(amount, source_id)

func heal(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0 or is_dead():
		return
	health += amount
	healed.emit(amount)

func can_take_damage(amount: float, source_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if amount <= 0:
		return false
	if is_dead() or invulnerable:
		return false
	if source_id == ENVIRONMENT_SOURCE:
		return true
	if source_id == get_owner_id():
		return allow_self_damage
	return source_id == 1 or source_id in multiplayer.get_peers()

func is_dead() -> bool:
	return health <= 0

func get_owner_id() -> int:
	return get_parent().get_multiplayer_authority()

func set_max_health(value: float) -> void:
	max_health = maxf(value, 1.0)
	if health > max_health:
		health = max_health
	health_changed.emit(health, max_health)

func _set_health(value: float) -> void:
	var was_alive := health > 0
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)
	if was_alive and health <= 0:
		died.emit()
