extends AnimationTree
## Replicates the state machine's current state from the authority to puppets.
@export var anim_state : StringName = &""

## Ground speed, written by the authority, replicated to peers by MultiplayerSynchronizer.
## Feeds into the Speed_Scaler so each animation gets its own scale.
@export var ground_speed : float = 0.0
@onready var speed_scaler : Node = $Speed_Scaler
@onready var playback : AnimationNodeStateMachinePlayback = get("parameters/playback")

## Puppet-side smoothed copy of ground_speed, so playback speed doesn't flicker between packets.
var _smoothed_speed : float = 0.0
var _applied_state : StringName = &""

func _ready() -> void:
	var current_animation_player: AnimationPlayer = get_node(anim_player)
	current_animation_player.playback_default_blend_time = 0.2

	if not is_multiplayer_authority():
		_make_puppet_tree()

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		anim_state = playback.get_current_node()
		ground_speed = speed_scaler.get_ground_speed()
	else:
		_apply_remote_state(delta)

func _apply_remote_state(delta: float) -> void:
	_smoothed_speed = lerpf(_smoothed_speed, ground_speed, 1.0 - exp(-owner.interp_speed * delta))
	speed_scaler.apply(_smoothed_speed)
	if anim_state == &"" or anim_state == _applied_state:
		return

	# First sync (spawn / late join) snaps; afterwards travel so crossfades play.
	if _applied_state == &"":
		playback.start(anim_state)
	else:
		playback.travel(anim_state)
	_applied_state = anim_state

## Because the AnimationTree has local variables that can run or be stale on remote peers (puppets),
## we duplicate the tree and disabled auto-advance, so stale local variables can't drive transitions.
func _make_puppet_tree() -> void:
	var tree : AnimationNodeStateMachine = tree_root.duplicate(true)
	for i in tree.get_transition_count():
		var transition := tree.get_transition(i)
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		transition.advance_expression = ""
	tree_root = tree
	playback = get("parameters/playback")
