class_name Wheel
extends Node3D


@export var radius := 0.25

@export var mass := 0.25

@export var inertia := 0.75

@export var max_brake_torque := 1600.0

@export var travel := 0.125 :
	set(value):
		travel = value
		_update_in_editor()

@export var spring_rest_length := 0.325 :
	set(value):
		spring_rest_length = value
		_update_in_editor()

@export var spring_stiffness := 10.0

@export var damping := 1.0

@export var pacejka_longitudinal : Pacejka94Longitudinal

@export var pacejka_lateral : Pacejka94Lateral


var torque := 0.0

var brake := 0.0


var _ray_hit := {}

var _contact_velocity := Vector3.ZERO

var _spring_velocity := 0.0

var _spring_force := 0.0

var _tire_load := 0.0

var _slip_ratio := 0.0

var _slip_angle := 0.0

var _angular_velocity := 0.0

var _brake_torque := 0.0


@onready var _hub : Node3D = $hub

@onready var _vehicle := get_parent() as RigidBody3D

@onready var _ray_query := _create_ray_query()

@onready var _space_state := get_world_3d().direct_space_state


func _ready() -> void:
	assert(global_transform.basis.get_scale() == Vector3.ONE)

	if Engine.is_editor_hint():
		_update_in_editor()
	else:
		_hub.position.y = -spring_rest_length


func update(vehicle_state : PhysicsDirectBodyState3D) -> void:
	_update_hub_position(vehicle_state)

	_update_spring_force(vehicle_state)
	_apply_spring_force(vehicle_state)
	_apply_longitudinal_force(vehicle_state)
	_apply_lateral_force(vehicle_state)

	_update_rotation(vehicle_state)


func is_in_contact() -> bool:
	return not _ray_hit.is_empty()


func get_angular_velocity() -> float:
	return _angular_velocity


func get_slip_ratio() -> float:
	return _slip_ratio


func get_slip_angle() -> float:
	return _slip_angle


func get_tire_load() -> float:
	return _tire_load


func get_vehicle() -> RigidBody3D:
	return _vehicle


func _apply_longitudinal_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	_brake_torque = -signf(_angular_velocity) * brake * max_brake_torque if not is_zero_approx(_angular_velocity) else 0.0
	_angular_velocity += vehicle_state.step * (torque + _brake_torque) / inertia

	if is_in_contact():
		var contact_position : Vector3 = _ray_hit.position
		var contact_normal : Vector3 = _ray_hit.normal

		var lateral_direction := global_transform.basis.x
		var longitudinal_direction := contact_normal.cross(lateral_direction).normalized()

		var num_substeps := 4
		var delta := vehicle_state.step / num_substeps
		var total_traction_force := 0.0
		for i in num_substeps:
			_slip_ratio = _compute_slip_ratio()
			var traction_force := pacejka_longitudinal.evaluate(_slip_ratio, _tire_load)
			var traction_torque := traction_force * radius
			_angular_velocity -= delta * traction_torque / inertia
			total_traction_force += traction_force / num_substeps

		vehicle_state.apply_force(
			total_traction_force * longitudinal_direction,
			contact_position - vehicle_state.transform.origin
		)


func _compute_slip_ratio() -> float:
	if not is_in_contact():
		return signf(_angular_velocity)

	var contact_normal : Vector3 = _ray_hit.normal
	var lateral_direction := global_transform.basis.x
	var longitudinal_direction := contact_normal.cross(lateral_direction).normalized()
	var wheel_velocity := _angular_velocity * radius
	var ground_velocity := _contact_velocity.dot(longitudinal_direction)
	var slip_ratio := (
		clampf((wheel_velocity - ground_velocity) / absf(ground_velocity), -1.0, 1.0)
		if not is_zero_approx(ground_velocity) else
		signf(wheel_velocity)
	)
	if ground_velocity < 5.0:
		var optimal_slip_ratio := signf(slip_ratio) * 0.1
		var interpolation_weight := clampf((5.0 - absf(ground_velocity)) / 2.0, 0.0, 1.0)
		slip_ratio = lerpf(slip_ratio, optimal_slip_ratio, interpolation_weight)
	return slip_ratio


func _apply_lateral_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	_slip_angle = _compute_slip_angle()
	if is_zero_approx(_slip_angle):
		return

	var lateral_direction := global_transform.basis.x
	var lateral_force := pacejka_lateral.evaluate(_slip_angle, _tire_load) * lateral_direction

	var contact_position : Vector3 = _ray_hit.position
	vehicle_state.apply_force(lateral_force, contact_position - vehicle_state.transform.origin)


func _compute_slip_angle() -> float:
	if not is_in_contact():
		return 0.0

	var contact_normal : Vector3 = _ray_hit.normal

	var lateral_direction := global_transform.basis.x
	var longitudinal_direction := contact_normal.cross(lateral_direction).normalized()

	var lateral_velocity := _contact_velocity.dot(lateral_direction)
	var longitudinal_velocity := _contact_velocity.dot(longitudinal_direction)

	#var slip_angle := -atan2(lateral_velocity, longitudinal_velocity)
	var slip_angle := -atan(lateral_velocity / longitudinal_velocity) if not is_zero_approx(longitudinal_velocity) else 0.0
	return slip_angle


func _update_hub_position(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var original_spring_length := -_hub.position.y

	var min_spring_length := spring_rest_length - travel
	var max_spring_length := spring_rest_length + travel

	# apply gravity and spring force to wheel
	var global_up := global_transform.basis.y
	var gravity := vehicle_state.total_gravity.project(global_up)
	# FIXME: applying the spring force results in large displacements causing the
	#        wheel to oscillate between the bottom-out and contact positions;
	#        use analytical solution of the mass-spring-damper system?
	#        (https://en.wikipedia.org/wiki/Mass-spring-damper_model)
	#var wheel_spring_force := -_spring_force * global_up
	#var acceleration := gravity + wheel_spring_force / mass
	var acceleration := gravity
	_hub.global_position += vehicle_state.step * acceleration

	var new_spring_length := clampf(-_hub.position.y, min_spring_length, max_spring_length)

	# check for collision and update spring length
	_cast_ray(vehicle_state, new_spring_length + radius)
	if is_in_contact():
		var hit_distance := global_position.distance_to(_ray_hit.position)
		new_spring_length = hit_distance - radius

	_hub.position.y = -new_spring_length

	# compute change in spring length
	_spring_velocity = new_spring_length - original_spring_length


func _update_spring_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var new_spring_displacement := -_hub.position.y - spring_rest_length
	_spring_force = -spring_stiffness * new_spring_displacement
	_spring_force -= damping * _spring_velocity

	_tire_load = _spring_force - mass * vehicle_state.total_gravity.dot(global_transform.basis.y)


func _apply_spring_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var force_direction := global_transform.basis.y
	vehicle_state.apply_force(_spring_force * force_direction, global_position - vehicle_state.transform.origin)


func _update_rotation(vehicle_state : PhysicsDirectBodyState3D) -> void:
	_hub.rotate_x(-vehicle_state.step * _angular_velocity)


func _cast_ray(vehicle_state : PhysicsDirectBodyState3D, length : float) -> void:
	_ray_query.from = global_position
	_ray_query.to = global_position - length * global_transform.basis.y
	_ray_hit = _space_state.intersect_ray(_ray_query)

	_contact_velocity = vehicle_state.get_velocity_at_local_position(_ray_hit.position) if is_in_contact() else Vector3.ZERO


func _create_ray_query() -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.new()
	if _vehicle != null:
		query.exclude = [_vehicle]
	return query


func _update_in_editor() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_hub.position.y = -spring_rest_length - travel


# @onready var _skid_sound : AudioStreamPlayer3D = $skid_sound
#
#
# func _physics_process(_delta : float) -> void:
# 	#var skid := 1.0 - get_skidinfo()
# 	var skid := 0.0 # TODO
# 	if skid > 0.2:
# 		if not _skid_sound.playing:
# 			_skid_sound.play()
# 		_skid_sound.volume_db = linear_to_db(skid * skid)
# 	elif _skid_sound.playing:
# 		_skid_sound.stop()
