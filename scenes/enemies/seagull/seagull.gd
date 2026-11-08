extends StaticBody3D

enum State { FLYING, LANDING, LANDED, TAKING_OFF }

@export var fly_speed: float = 6.0
@export var sky_height: float = 15.0
@export var roam_radius: float = 30.0
@export var turn_rate: float = 0.45
@export var idle_time_range: Vector2 = Vector2(8.0, 25.0)
@export var fly_time_range: Vector2 = Vector2(10.0, 20.0)

const FLAP_DURATION := 1.0
const CLEARANCE_RADIUS := 1.5
const WAYPOINT_RADIUS := 8.0
const FINAL_APPROACH := 2.0
const HUMAN_AVOID_RADIUS := 20.0

@onready var animation_player: AnimationPlayer = $"exported-model/AnimationPlayer"
@onready var alert_area_human: Area3D = %AlertAreaHuman
@onready var alert_area: Area3D = %AlertArea

var state: State = State.LANDED
var home: Vector3
var target: Vector3
var yaw: float = 0.0
var state_timer: float = 0.0
var waypoint_timer: float = 0.0
var flap_timer: float = 0.0
var flapping_for: float = 0.0

var speed_mult: float = 1.0
var turn_mult: float = 1.0
var height_offset: float = 0.0
var flap_mult: float = 1.0
var idle_mult: float = 1.0
var cruise_speed: float = 1.0


func _ready() -> void:
	if not multiplayer.is_server():
		alert_area_human.monitoring = false
		alert_area.monitoring = false
		set_physics_process(false)
		return
	home = global_position
	yaw = rotation.y
	speed_mult = randf_range(0.8, 1.25)
	turn_mult = randf_range(0.75, 1.25)
	height_offset = randf_range(-4.0, 5.0)
	flap_mult = randf_range(0.7, 1.5)
	idle_mult = randf_range(0.6, 1.6)
	cruise_speed = speed_mult
	flap_timer = randf_range(0.0, 3.0)
	alert_area_human.body_entered.connect(_on_human_entered)
	state_timer = randf_range(0.5, 6.0)


func _physics_process(delta: float) -> void:
	match state:
		State.TAKING_OFF:
			_set_anim(&"Flap")
			if _steer_to(target, fly_speed * speed_mult, delta, 2.0):
				_start_flying()
		State.FLYING:
			_update_flap(delta, 2.0, 5.0)
			waypoint_timer -= delta
			if _steer_to(target, fly_speed * cruise_speed, delta) or waypoint_timer <= 0.0:
				_next_waypoint()
			state_timer -= delta
			if state_timer <= 0.0:
				if randf() < 0.3:
					state_timer = randf_range(4.0, 10.0)
					return
				var spot = _pick_landing_spot()
				if spot != null:
					target = spot
					state = State.LANDING
					state_timer = 0.5
				else:
					state_timer = 2.0
		State.LANDING:
			_update_flap(delta, 5.0, 10.0)
			state_timer -= delta
			if state_timer <= 0.0:
				state_timer = 0.5
				if _human_near(target):
					_start_flying()
					return
			if _steer_to(target, fly_speed * speed_mult * 0.8, delta):
				state = State.LANDED
				state_timer = randf_range(idle_time_range.x, idle_time_range.y) * idle_mult
		State.LANDED:
			_set_anim(&"Idle")
			state_timer -= delta
			if state_timer <= 0.0:
				_take_off()


func _on_human_entered(body: Node3D) -> void:
	if state == State.LANDED and body is CharacterBody3D:
		state_timer = randf_range(0.0, 0.6)


func _take_off() -> void:
	state = State.TAKING_OFF
	var dir_yaw := yaw + randf_range(-0.5, 0.5)
	target = global_position + Vector3(sin(dir_yaw), 0, cos(dir_yaw)) * randf_range(15.0, 25.0)
	target.y = home.y + sky_height + height_offset


func _start_flying() -> void:
	state = State.FLYING
	state_timer = randf_range(fly_time_range.x, fly_time_range.y)
	_next_waypoint()


func _next_waypoint() -> void:
	target = home + _random_offset()
	target.y = home.y + sky_height + height_offset + randf_range(-3.0, 3.0)
	cruise_speed = speed_mult * randf_range(0.75, 1.15)
	waypoint_timer = randf_range(6.0, 14.0)


func _steer_to(to: Vector3, speed: float, delta: float, climb_boost: float = 1.0) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	var dist := flat.length()
	var landing := state == State.LANDING

	if dist > 0.05:
		var rate := turn_rate * turn_mult
		if landing:
			rate *= clampf(10.0 / dist, 1.0, 3.0)
		yaw = rotate_toward(yaw, atan2(flat.x, flat.z), rate * delta)
		rotation.y = yaw

	if landing and dist < FINAL_APPROACH:
		global_position = global_position.move_toward(to, speed * delta)
		return global_position.distance_to(to) < 0.05

	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var dy := to.y - global_position.y
	var vertical := clampf(absf(dy) * speed / maxf(dist, 0.5), 0.0, speed * climb_boost)
	global_position += forward * speed * delta
	global_position.y = move_toward(global_position.y, to.y, vertical * delta)

	if landing:
		return false
	if state == State.TAKING_OFF:
		return absf(dy) < 1.0
	return dist < WAYPOINT_RADIUS and absf(dy) < 1.0


func _update_flap(delta: float, min_gap: float, max_gap: float) -> void:
	if flapping_for > 0.0:
		flapping_for -= delta
		_set_anim(&"Flap")
		return
	_set_anim(&"Glide")
	flap_timer -= delta
	if flap_timer <= 0.0:
		flapping_for = FLAP_DURATION * randf_range(0.6, 1.8)
		flap_timer = randf_range(min_gap, max_gap) * flap_mult


func _random_offset() -> Vector3:
	var v := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * roam_radius
	return Vector3(v.x, 0, v.y)


func _pick_landing_spot() -> Variant:
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = CLEARANCE_RADIUS
	for i in 10:
		var p := home + _random_offset()
		var from := Vector3(p.x, home.y + sky_height + 20.0, p.z)
		var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0)
		ray.exclude = [get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85:
			continue
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = sphere
		shape_query.transform = Transform3D(Basis(), hit.position + Vector3.UP * (CLEARANCE_RADIUS + 0.1))
		shape_query.exclude = [get_rid()]
		if space.intersect_shape(shape_query, 1).is_empty() and not _human_near(hit.position):
			return hit.position
	return null


func _human_near(point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = HUMAN_AVOID_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), point)
	query.collision_mask = alert_area_human.collision_mask
	query.exclude = [get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		if result.collider is CharacterBody3D:
			return true
	return false


func _set_anim(anim: StringName) -> void:
	if animation_player.current_animation != anim:
		animation_player.play(anim, 0.3)
