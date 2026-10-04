extends CharacterBody3D

@export var added_velocity : Vector3 = Vector3.ZERO
@onready var camera: Camera3D = %Camera

@export var movement_allowed : bool = true
## Determines if the player can control the camera, disable when you want to move the camera manually
@export var camera_control_allowed : bool = true
## Determines if the character will face the direction of movement or face the camera point, first-person will override this
@export var body_faces_movement : bool = true
@export var jump_allowed : bool = true
@export var gravity_affected : bool = true
@export var sprint_allowed : bool = true
@export var crouch_allowed : bool = true
@export var swimming_allowed : bool = true
@export var sinks_in_water : bool = false
##Determines if the player can enter noclip mode
@export var noclip_allowed : bool = true
##Determines if a player can stop their momentum by letting go of movement while midair 
@export var midair_deceleration : bool = false
##If the player can strafe
@export var strafing_allowed : bool = true
##If the player can strafe midair, strafing_allowed being disabled will override this
@export var air_strafing_allowed : bool = true
#If the player will automatically jump upon touching the floor while the jump input is held down
@export var hold_jump : bool = false
@export var toggle_sprint : bool = false
@export var toggle_crouch : bool = false
@export var invert_mouse : bool = false


# CRITICAL: Think about how we want to stop accepting inputs and resume them
# TODO: is it this, or another mechanism, and then does the UI change instead?
@export var mouse_lock : bool = true


@onready var moving : bool = false
@onready var jumping : bool = false
@onready var sprinting : bool = false
@onready var noclipping : bool = false
@onready var floating : bool = false
@onready var swimming : bool = false
@onready var previous_swimming_state : bool = false
@onready var crouching : bool = false

@export_group("Attributes")
@export var base_speed : float = 3.5
@export var sprint_increase : float = 0.6
@export var crouch_speed_decrease : float = 0.5
@export var crouch_animation_time : float = 0.075
@export var water_speed_decrease : float = 0.25
#Speed multiplier used internally for things like sprinting, if you want to give the player boosts use the exported multiplier instead.
@onready var base_speed_multiplier : float = 1.0
#Speed modifier to be used externally, for things such as gear and items
@export var speed_multiplier : float = 1.0
## Lerp rates (per second): roughly 1 / time to reach 63% of target speed
@export var friction : float = 7.5
@export var sprint_friction : float = 6.5
@export var acceleration : float = 8.0
@export var sprint_acceleration : float = 3.5
@export var air_acceleration : float = 6.0
## Max horizontal speed the player can steer to while midair
@export var air_speed : float = 3.2
@export var jump_power : float = 6.5
## Upward gravity is divided by this when jump is released early (lower = shorter hops)
@export var jump_cut_multiplier : float = 0.5
@export var model_rotation_speed : float = 6.5
#Amount of times a player can jump
@export var max_jumps : int = 1
@onready var jumps_remaining : int
##Time where the player is still allowed to jump after leaving a platform
@export var coyote_time : float = 0.2
@onready var coyote_time_timer : float

## Soft clamp for velocity, can be exceeded but counterfources will be applied.
@export var max_speed : float = 30
@export var look_sensitivity : float = 0.002
@export var max_vertical_look_angle : float = 85

## Gets the velocity the character intends to go at, even if it doesn't actually move.
@onready var desired_velocity : Vector3
## Similar to desired_velocity but ignores added velocity.
@onready var raw_desired_velocity : Vector3

signal jumped
signal landed

@export_group("Network")
## Written by the authority, replicated to peers. Puppets interpolate toward these.
@export var sync_position : Vector3
@export var sync_rotation_y : float
## Interpolation rate (per second) for puppets. Higher = snappier, lower = smoother but laggier.
@export var interp_speed : float = 15.0
## Puppets snap instead of lerping when further than this from the synced position (teleports, respawns).
@export var snap_distance : float = 3.0

#Used to connect to the input system, uses ui inputs as a fallback
@export_group("Inputs")
@export var mapped_inputs : Dictionary [String, String] = {
	"Left": "Move_Left",
	"Right": "Move_Right",
	"Forward": "Move_Forward",
	"Backward": "Move_Backward",
	"Jump": "Jump",
	"Sprint": "Sprint",
	"Noclip": "Noclip",
	"Crouch": "Crouch",
	"Look_Up": "Look_Up",
	"Look_Down": "Look_Down",
	"Look_Left": "Look_Left",
	"Look_Right": "Look_Right",
	"Zoom_Out": "Zoom_Out",
	"Zoom_In": "Zoom_In"
	
}
## Object references
@onready var head : SpringArm3D = $Head
@onready var perspective_handler : Node = $Head/Camera/Perspective_Handler
@onready var collider : CollisionShape3D = $Collider 


## Debounce vars
@onready var stored_sprint_state : bool = false
@onready var stored_crouch_state : bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	jumps_remaining = max_jumps
	coyote_time_timer = coyote_time
	check_mappings()

	if not is_multiplayer_authority():
		set_process(false)
		set_process_input(false)
		position = sync_position
		rotation.y = sync_rotation_y
	else:
		# Client processing
		camera.current = true
		sync_position = position
		sync_rotation_y = rotation.y

func _unhandled_input(_event: InputEvent) -> void:
	#Toggle noclip mode
	if noclip_allowed and Input.is_action_just_pressed(mapped_inputs["Noclip"]):
		if not noclipping:
			enable_noclip()
		else:
			disable_noclip()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_interpolate_remote(delta)
		return

	coyote_time_timer -= delta
		
	if is_on_floor():
		jumping = false
		landed.emit()
		jumps_remaining = max_jumps
		coyote_time_timer = coyote_time
		
	#Changes velocity to move the player
	if movement_allowed:
		#Removes a jump if falling off of a ledge
		if (jumps_remaining == max_jumps and not is_on_floor() and coyote_time_timer <= 0):
			jumps_remaining -= 1
		#Apply jump velocity
		if jump_allowed and (is_on_floor() or (coyote_time_timer > 0 and jumps_remaining > 0) and not swimming and not floating):
			if (Input.is_action_just_pressed(mapped_inputs["Jump"]) or (Input.is_action_pressed(mapped_inputs["Jump"]) and hold_jump == true)):
				velocity.y = jump_power
				jumps_remaining -= 1
				jumped.emit()
				jumping = true
		elif swimming or floating:
			if Input.is_action_pressed(mapped_inputs["Jump"]):
				if noclipping:
					velocity.y += (jump_power * 0.05)
				else:
					#Float upwards
					velocity.y += (jump_power * 0.015)
					
		
		#Apply gravity to velocity
		if gravity_affected:
			#Breaks some player velocity relatively when hitting water
			if swimming == true and previous_swimming_state == false:
				#print("Water dampening.")
				velocity -= (-(velocity * get_gravity() * (velocity.length() * 0.75)) * delta)
			if swimming and sinks_in_water and not noclipping:
				#print("Sink")
				#print((get_gravity() * 0.1) * delta)
				velocity += (get_gravity() * 0.1) * delta
			elif not is_on_floor() and not floating:
				#Rising gravity is increased when jump is released early, for variable jump height
				var gravity : Vector3 = get_gravity()
				if velocity.y > 0 and jumping and not Input.is_action_pressed(mapped_inputs["Jump"]):
					gravity /= jump_cut_multiplier
				velocity += gravity * delta
				
		
		var input_direction : Vector2 = Input.get_vector(mapped_inputs["Left"], mapped_inputs["Right"], mapped_inputs["Forward"], mapped_inputs["Backward"])
		
		if is_on_floor():
			if strafing_allowed == false:
				input_direction.x = 0
		else:
			if air_strafing_allowed == false or strafing_allowed == false:
				input_direction.x = 0
		
		
		var current_acceleration : float = acceleration
		var current_friction : float = friction
		var target_speed : float = base_speed
		if sprinting:
			current_acceleration = sprint_acceleration
			current_friction = sprint_friction
		var crouch_slow : float = (crouch_speed_decrease * int(crouching))
		var water_slow : float = (water_speed_decrease * int(swimming))
		var base_slow : float = crouch_slow + water_slow

		# Changes acceleration and crouch slow based on being in the air and crouch state
		if not is_on_floor() and not swimming:
			current_acceleration = air_acceleration
			target_speed = air_speed
			crouch_slow = 0
		elif noclipping:
			current_acceleration = 1000
			crouch_slow = 0
			current_friction = 5000
		#Lerp weights, clamped so high rates don't overshoot
		var accel_weight : float = minf(current_acceleration * delta, 1.0)
		var friction_weight : float = minf(current_friction * delta, 1.0)

		
		var movement_vector : Vector3
		if perspective_handler.camera_dolly > perspective_handler.first_person_threshold and body_faces_movement == true:
			if input_direction != Vector2.ZERO:
				var new_basis : Basis = head.global_transform.basis
				new_basis.z.y = 0
				new_basis.z = new_basis.z.normalized()
				new_basis.x.y = 0
				new_basis.x = new_basis.x.normalized() #Scrubs some axis off the basis that cause the player to move slower when the camera looks down
				movement_vector = (new_basis * Vector3(input_direction.x, 0, input_direction.y))
				var target_rotation : float = Vector3.FORWARD.signed_angle_to(movement_vector, up_direction)
				rotation.y = rotate_toward(rotation.y, target_rotation, model_rotation_speed * delta)
		else:
			movement_vector = (transform.basis * Vector3(input_direction.x, 0, input_direction.y))

		#print(movement_vector)
		if movement_vector and (floating or swimming):
			movement_vector = (head.global_basis * Vector3(input_direction.x, 0, input_direction.y))
			#Workaround for moving cancelling y velocity, there is probably a better way to do this.
			var stored_vel_y : float = velocity.y
			velocity = velocity.lerp(movement_vector * base_speed * (base_speed_multiplier - base_slow) * speed_multiplier, accel_weight)
			velocity.y = stored_vel_y
		elif movement_vector:
			var target_velocity : Vector3 = movement_vector * target_speed * (base_speed_multiplier - base_slow) * speed_multiplier
			velocity.x = lerp(velocity.x, target_velocity.x, accel_weight)
			velocity.z = lerp(velocity.z, target_velocity.z, accel_weight)
		elif is_on_floor() or midair_deceleration == true:
			velocity.x = lerp(velocity.x, 0.0, friction_weight)
			velocity.z = lerp(velocity.z, 0.0, friction_weight)
			#Snap tiny residual velocity to zero since lerp never fully reaches it
			if Vector2(velocity.x, velocity.z).length() < 0.05:
				velocity.x = 0
				velocity.z = 0
		
		#Vertical friction to prevent sliding in noclip
		#velocity.y = move_toward(velocity.y, 0, (friction * 0.01) * delta)
		
		##Hard speed capping
		velocity.x = clamp(velocity.x, -max_speed, max_speed)
		velocity.z = clamp(velocity.z, -max_speed, max_speed)
		velocity.y = clamp(velocity.y, -max_speed, max_speed)
		##Soft speed capping
		if velocity.x > max_speed:
			velocity.x -= (friction * delta)
		if velocity.y > max_speed:
			velocity.y -= (friction * delta)
		elif noclipping:
			velocity.y = move_toward(velocity.y, 0, 11 * delta)
		if velocity.z > max_speed:
			velocity.z -= (friction * delta)
		#print(velocity.length())
				
	else:
		velocity.x = 0
		velocity.y = 0
	
	raw_desired_velocity = velocity
	velocity += added_velocity
	desired_velocity = velocity

	added_velocity = Vector3.ZERO

	#Stick to slopes/stairs while grounded, but don't snap back down mid-jump
	floor_snap_length = 0.0 if jumping else 1.0
	move_and_slide()
	
	#Sets previous state variables
	#print("Setting previous variable states")
	previous_swimming_state = swimming

	sync_position = position
	sync_rotation_y = rotation.y

## Puppets ease toward the last replicated transform instead of jumping to each packet.
func _interpolate_remote(delta: float) -> void:
	#Frame-rate independent lerp weight
	var weight : float = 1.0 - exp(-interp_speed * delta)
	if position.distance_to(sync_position) > snap_distance:
		position = sync_position
	else:
		position = position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_rotation_y, weight)

func enable_noclip() -> void:
	if noclip_allowed:
		noclipping = true
		collider.disabled = true
		floating = true
		velocity = Vector3.ZERO

func disable_noclip() -> void:
	if noclip_allowed:
		noclipping = false
		collider.disabled = false
		floating = false

## Chunks for unassigned input actions

func check_mappings() -> void:
	
	if movement_allowed:
		for current_mapping in mapped_inputs:
			if not InputMap.has_action(mapped_inputs[current_mapping]):
				push_warning("No " + str(mapped_inputs[current_mapping]) + " InputAction found, disabling controls")
				movement_allowed = false
