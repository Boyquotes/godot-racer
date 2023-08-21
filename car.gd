extends VehicleBody3D


@export var max_engine_force := 2000.0

@export var max_brake_force := 50.0

@export var max_steering_angle := deg_to_rad(20.0)

@export var steering_speed := deg_to_rad(135.0)


@onready var _engine_sound : AudioStreamPlayer3D = $engine_sound


func _physics_process(delta : float) -> void:
	var acceleration_input := Input.get_axis(&"reverse", &"accelerate")
	engine_force = acceleration_input * max_engine_force

	var brake_input := Input.get_action_strength(&"brake")
	brake = brake_input * max_brake_force

	var steering_input := Input.get_axis(&"steer_right", &"steer_left")
	steering = move_toward(steering, steering_input * max_steering_angle, delta * steering_speed)

	var speed := linear_velocity.dot(global_transform.basis.z)
	_engine_sound.pitch_scale = maxf(0.5, remap(absf(speed), 0.0, 100.0, 0.5, 10.0))
