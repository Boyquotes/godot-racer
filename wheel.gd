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

@export var damping_compression := 0.83

@export var damping_relaxation := 0.88

@export var pacejka_combination : PacejkaCombination


var torque := 0.0

var brake := 0.0


var _ray_hit := {}

var _contact_velocity := Vector3.ZERO

var _spring_velocity := 0.0

var _spring_force := 0.0

var _tire_load := 0.0

var _supported_mass := 0.0

var _slip_velocity := Vector2.ZERO

var _slip_ratio := 0.0

var _slip_angle := 0.0

var _grip := Vector2.ZERO

var _angular_velocity := 0.0

var _brake_torque := 0.0


@onready var _hub : Node3D = $hub

@onready var _vehicle := get_parent() as RigidBody3D

@onready var _ray_query := _create_ray_query()

@onready var _space_state := get_world_3d().direct_space_state


func _ready() -> void:
	assert(global_transform.basis.get_scale() == Vector3.ONE)

	pacejka_combination.normalize()

	if Engine.is_editor_hint():
		_update_in_editor()
	else:
		_hub.position.y = -spring_rest_length


func update_suspension(vehicle_state : PhysicsDirectBodyState3D) -> void:
	_update_hub_position(vehicle_state)
	_update_spring_force(vehicle_state)
	_apply_spring_force(vehicle_state)


func update_tire(vehicle_state : PhysicsDirectBodyState3D, supported_mass : float) -> void:
	_supported_mass = supported_mass
	_apply_slip_forces(vehicle_state)
	_update_visual_rotation(vehicle_state)


func is_in_contact() -> bool:
	return not _ray_hit.is_empty()


func get_angular_velocity() -> float:
	return _angular_velocity


func get_slip_velocity() -> Vector2:
	return _slip_velocity


func get_grip() -> Vector2:
	return _grip


func get_tire_load() -> float:
	return _tire_load


func get_vehicle() -> RigidBody3D:
	return _vehicle


func _apply_slip_forces(vehicle_state : PhysicsDirectBodyState3D) -> void:
	if not is_in_contact():
		_slip_velocity.x = 0.0
		_slip_velocity.y = 0.0
		_angular_velocity += vehicle_state.step * torque / inertia
		return

	var contact_position : Vector3 = _ray_hit.position
	var contact_normal : Vector3 = _ray_hit.normal

	var lateral_direction := global_transform.basis.x
	var longitudinal_direction := contact_normal.cross(lateral_direction).normalized()

	var longitudinal_velocity := _contact_velocity.dot(longitudinal_direction)
	var lateral_velocity := _contact_velocity.dot(lateral_direction)

	var num_substeps := 4
	var delta := vehicle_state.step / num_substeps
	var traction_force := Vector2.ZERO
	for i in num_substeps:
		_angular_velocity += delta * torque / inertia

		_slip_velocity.x = longitudinal_velocity - _angular_velocity * radius
		_slip_velocity.y = lateral_velocity

		_slip_ratio = -_slip_velocity.x / maxf(0.001, longitudinal_velocity)
		_slip_angle = -atan(lateral_velocity / longitudinal_velocity) if not is_zero_approx(longitudinal_velocity) else 0.0

		#var friction := pacejka_combination.evaluate(_slip_velocity)
		var friction := pacejka_combination.evaluate(Vector2(
			_slip_ratio,
			_slip_angle
		), name == "wheel_rr")
		var local_traction_force := _tire_load * friction

		# calculate the resistive force limit that will not negate the sign of slip_velocity.x
		var max_angular_deceleration := -_slip_velocity.x / (radius * delta)
		var max_resistive_torque := max_angular_deceleration * inertia
		var max_resistive_force := max_resistive_torque / radius

		#var original_traction_force := local_traction_force.x

		if local_traction_force.x / max_resistive_force > 1.0:
			local_traction_force.x = max_resistive_force

		traction_force += local_traction_force / num_substeps

		#var original_angular_velocity := _angular_velocity

		var resistive_torque := local_traction_force.x * radius
		_angular_velocity -= delta * resistive_torque / inertia

		#if name == "wheel_rr":
		#	print("w: ", original_angular_velocity, " | u: ", longitudinal_velocity, " | F: ", original_traction_force, " | F_max: ", max_resistive_force, " | F_fin: ", local_traction_force.x, " | w_fin: ", _angular_velocity)

	_grip = -traction_force / _tire_load
	#if name == "wheel_rr":
	#	print(torque, " / ", traction_force.x * radius)

	var global_traction_force := traction_force.x * longitudinal_direction + traction_force.y * lateral_direction
	vehicle_state.apply_force(global_traction_force, contact_position - vehicle_state.transform.origin)


func _update_hub_position(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var original_spring_length := -_hub.position.y

	var min_spring_length := spring_rest_length - travel
	var max_spring_length := spring_rest_length + travel

	# apply gravity and spring force to wheel
	var global_up := global_transform.basis.y
	var gravity := vehicle_state.total_gravity.dot(global_up)
	# FIXME: applying the spring force results in large displacements causing the
	#        wheel to oscillate between the bottom-out and contact positions;
	#        use analytical solution of the mass-spring-damper system?
	#        (https://en.wikipedia.org/wiki/Mass-spring-damper_model)
	#        /use multiple substeps?
	#var acceleration := gravity - _spring_force / mass
	var acceleration := gravity
	_hub.position.y += vehicle_state.step * acceleration

	var new_spring_length := clampf(-_hub.position.y, min_spring_length, max_spring_length)

	# check for collision and update spring length
	_cast_ray(vehicle_state, new_spring_length + radius)
	if is_in_contact():
		var hit_distance := global_position.distance_to(_ray_hit.position)
		new_spring_length = hit_distance - radius

	_hub.position.y = -new_spring_length

	# compute change in spring length
	_spring_velocity = (new_spring_length - original_spring_length) / vehicle_state.step


func _update_spring_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var new_spring_displacement := -_hub.position.y - spring_rest_length
	_spring_force = -spring_stiffness * new_spring_displacement
	var damping := damping_relaxation if _spring_velocity > 0.0 else damping_compression
	_spring_force -= damping * _spring_velocity

	_tire_load = _spring_force - mass * vehicle_state.total_gravity.dot(global_transform.basis.y)


func _apply_spring_force(vehicle_state : PhysicsDirectBodyState3D) -> void:
	var force_direction := global_transform.basis.y
	vehicle_state.apply_force(_spring_force * force_direction, global_position - vehicle_state.transform.origin)


func _update_visual_rotation(vehicle_state : PhysicsDirectBodyState3D) -> void:
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
