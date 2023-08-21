class_name Vehicle
extends RigidBody3D


@export var max_wheel_torque := 1.0

@export var throttle_speed := 2.0

@export var brake_speed := 4.0

@export var max_steering_angle := deg_to_rad(35.0)

@export var steering_speed := deg_to_rad(90.0)

@export var accept_throttle_input := true

@export var accept_brake_input := true

@export var accept_steering_input := true


var throttle := 0.0

var brake := 0.0

var steering_angle := 0.0


var _speed := 0.0


@onready var _wheels := _find_wheels()

@onready var _front_wheels : Array[Wheel] = [$wheel_fl, $wheel_fr]

@onready var _rear_wheels : Array[Wheel] = [$wheel_rl, $wheel_rr]


func _physics_process(delta : float) -> void:
	_handle_input(delta)
	_apply_input_to_tires()
	_update_speed()


func _integrate_forces(state : PhysicsDirectBodyState3D) -> void:
	for wheel in _wheels:
		wheel.update(state)


func get_speed() -> float:
	return _speed


func _handle_input(delta : float) -> void:
	if accept_throttle_input:
		var acceleration_input := Input.get_axis(&"reverse", &"accelerate")
		throttle = move_toward(throttle, acceleration_input, delta * throttle_speed)

	if accept_brake_input:
		var brake_input := Input.get_action_strength(&"brake")
		brake = move_toward(brake, brake_input, delta * brake_speed)

	if accept_steering_input:
		var steering_input := Input.get_axis(&"steer_right", &"steer_left")
		steering_angle = move_toward(steering_angle, steering_input * max_steering_angle, delta * steering_speed)


func _apply_input_to_tires() -> void:
	for wheel in _rear_wheels:
		wheel.torque = throttle * max_wheel_torque

	for wheel in _wheels:
		wheel.brake = brake

	for wheel in _front_wheels:
		wheel.rotation.y = steering_angle


func _update_speed() -> void:
	_speed = 0.0
	for wheel in _rear_wheels:
		_speed += wheel.get_angular_velocity() * wheel.radius
	_speed /= _rear_wheels.size()


func _find_wheels() -> Array[Wheel]:
	var wheels : Array[Wheel] = []
	for child in get_children():
		if child is Wheel:
			wheels.push_back(child)
	return wheels
