# TODO: These all expect AnimationTree as a fed node,
# This should all be put together some how and referenced much more neatly
extends Node
class_name OneShotHandler

# TODO: Death, respawn, etc.
const UPPER_BODY := "parameters/UpperBody/request"
const BOW_HOLD := "parameters/BowHold/request"
const BOW_HOLD_ACTIVE := "parameters/BowHold/active"
const BOW_PLAYBACK := "parameters/BowStateMachine/playback"

@onready var player_controller : Node = get_parent().get_parent()
@export var animation_tree : AnimationTree

func _ready():
	player_controller.signal_oneshot.connect(func(param_name: StringName, oneshot_mode: AnimationNodeOneShot.OneShotRequest): play_oneshot_remote.rpc(param_name, oneshot_mode))
	# Runs on every peer, so the fade-out needs no extra network message.
	animation_tree.animation_finished.connect(func(anim_name: StringName): if anim_name == &"Bow_Release": _fade_out_upper_body())

@rpc("authority", "call_local", "reliable")
func play_oneshot_remote(param_string: StringName, oneshot_mode: AnimationNodeOneShot.OneShotRequest) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		push_error('RPC called without a .rpc')
		return
	animation_tree.set(param_string, oneshot_mode)

## True when the bow state machine is sitting in the hold, i.e. ready to fire.
func is_bow_held() -> bool:
	var playback : AnimationNodeStateMachinePlayback = animation_tree.get(BOW_PLAYBACK)
	return animation_tree.get(BOW_HOLD_ACTIVE) and playback.get_current_node() == &"Bow_Pull_Hold"

## Authority only. Plays Bow_Release inside BowStateMachine on all peers.
func fire_bow() -> void:
	travel_bow_remote.rpc(&"Bow_Release")

## Authority only. Cancels the draw without firing.
func cancel_bow() -> void:
	cancel_bow_remote.rpc()

@rpc("authority", "call_local", "reliable")
func travel_bow_remote(state: StringName) -> void:
	var playback : AnimationNodeStateMachinePlayback = animation_tree.get(BOW_PLAYBACK)
	playback.travel(state)

@rpc("authority", "call_local", "reliable")
func cancel_bow_remote() -> void:
	_fade_out_upper_body()

func _fade_out_upper_body() -> void:
	animation_tree.set(UPPER_BODY, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
