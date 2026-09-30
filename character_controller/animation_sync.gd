extends AnimationTree
## Replicates the state machine's current state from the authority to puppets.

## Written by the authority, replicated to peers (on change).
@export var anim_state : StringName = &""
## Horizontal speed, written by the authority, replicated to peers.
## Puppets feed it to the Speed_Scaler so each animation gets its own scale.
@export var ground_speed : float = 0.0

@onready var speed_scaler : Node = $Speed_Scaler
@onready var playback : AnimationNodeStateMachinePlayback = get("parameters/playback")
var _applied_state : StringName = &""
## Puppet-side smoothed copy of ground_speed, so playback speed doesn't flicker between packets.
var _smoothed_speed : float = 0.0

func _ready() -> void:
	if not is_multiplayer_authority():
		_make_puppet_tree()
		speed_scaler.set_process(false)

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

## Puppets get their own copy of the state machine with auto-advance disabled,
## so stale local variables can't drive transitions.
func _make_puppet_tree() -> void:
	var sm : AnimationNodeStateMachine = tree_root.duplicate(true)
	for i in sm.get_transition_count():
		var t := sm.get_transition(i)
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		t.advance_expression = ""
	tree_root = sm
	playback = get("parameters/playback")
