# Combines work from https://github.com/mom0367/Godot-3D-Game-Template/blob/master/character_controller/speed_scaler.gd
extends AnimationTree
class_name AnimationSync

# TODO: We could make a list of required animations and have them fed to the Tree, allowing better "bring your own"

const MOVEMENT := &"Movement"
const WALK_SCALE := "parameters/Movement/Walk/Character_Speed_Scale/scale"
const SPRINT_SCALE := "parameters/Movement/Sprint/Character_Speed_Scale/scale"
const CROUCH_WALK_SCALE := "parameters/Movement/Crouch Walk/Character_Speed_Scale/scale"
const WALK_BLEND := "parameters/Movement/Walk/Walk/blend_position"
const MIN_BLEND_SPEED := 0.1

@export var anim_state : StringName = &""
@export var ground_speed : float = 0.0
@export var walk_blend : Vector2 = Vector2.UP

@export_group("Stride Speed")
@export var walk_speed : float = 3.0
@export var sprint_speed : float = 6.8
@export var crouch_speed : float = 1.5

@export_group("Walk Blend")
@export var walk_blend_smoothing : float = 10.0

@onready var player : CharacterBody3D = owner.get_parent()

var _smoothed_speed : float = 0.0
var _smoothed_blend : Vector2 = Vector2.UP
var _applied_state : StringName = &""

func _ready() -> void:
	advance_expression_base_node = get_path_to(player)
	var animation_player : AnimationPlayer = get_node(anim_player)
	animation_player.playback_default_blend_time = 0.2
	if not is_multiplayer_authority():
		_make_puppet_tree()

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		ground_speed = Vector2(player.velocity.x, player.velocity.z).length()
		anim_state = get_current_state(MOVEMENT)
		walk_blend = walk_blend.lerp(_get_walk_direction(), 1.0 - exp(-walk_blend_smoothing * delta))
		_apply_speed_scaler(ground_speed)
		set(WALK_BLEND, walk_blend)
	else:
		var weight : float = 1.0 - exp(-player.interp_speed * delta)
		_smoothed_speed = lerpf(_smoothed_speed, ground_speed, weight)
		_smoothed_blend = _smoothed_blend.lerp(walk_blend, weight)
		_apply_speed_scaler(_smoothed_speed)
		set(WALK_BLEND, _smoothed_blend)
		_apply_remote_state()

func _get_walk_direction() -> Vector2:
	var local_velocity : Vector3 = player.global_basis.inverse() * player.velocity
	var direction := Vector2(local_velocity.x, -local_velocity.z)
	if direction.length() < MIN_BLEND_SPEED:
		return walk_blend
	return direction.normalized()

@rpc("authority", "call_local", "reliable")
func fire_oneshot(oneshot: StringName) -> void:
	set(_param(oneshot, "request"), AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

@rpc("authority", "call_local", "reliable")
func fade_out_oneshot(oneshot: StringName) -> void:
	set(_param(oneshot, "request"), AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

@rpc("authority", "call_local", "reliable")
func travel(state_machine: StringName, state: StringName) -> void:
	_playback(state_machine).travel(state)

func is_oneshot_active(oneshot: StringName) -> bool:
	return get(_param(oneshot, "active"))

func get_current_state(state_machine: StringName) -> StringName:
	return _playback(state_machine).get_current_node()

func _playback(state_machine: StringName) -> AnimationNodeStateMachinePlayback:
	return get(_param(state_machine, "playback"))

func _param(node: StringName, property: String) -> String:
	return "parameters/%s/%s" % [node, property]

func _apply_speed_scaler(speed: float) -> void:
	set(WALK_SCALE, speed / walk_speed)
	set(SPRINT_SCALE, speed / sprint_speed)
	set(CROUCH_WALK_SCALE, speed / crouch_speed)

func _apply_remote_state() -> void:
	if anim_state == &"" or anim_state == _applied_state:
		return
	if _applied_state == &"":
		_playback(MOVEMENT).start(anim_state)
	else:
		_playback(MOVEMENT).travel(anim_state)
	_applied_state = anim_state

# AnimationTrees running on non-authorities (aka "puppets") will have
# stale or incorrect values. This duplicates the tree and assures
# the latest values from the authority are sent from _apply_remote_state
func _make_puppet_tree() -> void:
	var root : AnimationNodeBlendTree = tree_root.duplicate(true)
	var movement : AnimationNodeStateMachine = root.get_node(MOVEMENT)
	for i in movement.get_transition_count():
		var transition := movement.get_transition(i)
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		# Clear out expressions, so the tree never advances on it's own.
		transition.advance_expression = ""
	# Replace the whole thing on remotes
	tree_root = root
