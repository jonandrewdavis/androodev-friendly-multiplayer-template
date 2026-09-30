extends AnimationTree
## Replicates the state machine's current state from the authority to puppets.

## Written by the authority, replicated to peers (on change).
@export var anim_state : StringName = &""
## Written by the authority, replicated to peers.
@export var speed_scale : float = 1.0

const SPEED_SCALE_PARAMS : Array[String] = [
	"parameters/Walk/Character_Speed_Scale/scale",
	"parameters/Sprint/Character_Speed_Scale/scale",
	"parameters/Crouch Walk/Character_Speed_Scale/scale",
]

@onready var playback : AnimationNodeStateMachinePlayback = get("parameters/playback")
var _applied_state : StringName = &""

func _ready() -> void:
	if not is_multiplayer_authority():
		_make_puppet_tree()
		$Speed_Scaler.set_process(false)

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		anim_state = playback.get_current_node()
		speed_scale = get(SPEED_SCALE_PARAMS[0])
	else:
		_apply_remote_state()

func _apply_remote_state() -> void:
	for param in SPEED_SCALE_PARAMS:
		set(param, speed_scale)
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
