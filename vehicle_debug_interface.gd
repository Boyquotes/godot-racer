extends Control


@export var vehicle : Vehicle


@onready var _throttle_plot : TimeSeriesPlot = %throttle_plot

@onready var _brake_plot : TimeSeriesPlot = %brake_plot

@onready var _steering_plot : TimeSeriesPlot = %steering_plot

@onready var _speed_plot : TimeSeriesPlot = %speed_plot

@onready var _throttle_slider : Slider = %throttle_slider

@onready var _brake_slider : Slider = %brake_slider

@onready var _steering_slider : Slider = %steering_slider


func _ready() -> void:
	_steering_slider.min_value = -vehicle.max_steering_angle
	_steering_slider.max_value = vehicle.max_steering_angle


func _physics_process(_delta : float) -> void:
	_throttle_plot.push_value(vehicle.throttle * 100.0)
	_brake_plot.push_value(vehicle.brake * 100.0)
	_steering_plot.push_value(rad_to_deg(vehicle.steering_angle))
	_speed_plot.push_value(vehicle.get_speed() * 3.6)

	if not is_equal_approx(_throttle_slider.value, vehicle.throttle):
		_throttle_slider.value = vehicle.throttle

	if not is_equal_approx(_brake_slider.value, vehicle.brake):
		_brake_slider.value = vehicle.brake

	if not is_equal_approx(_steering_slider.value, -vehicle.steering_angle):
		_steering_slider.value = -vehicle.steering_angle


func _on_throttle_slider_value_changed(value : float) -> void:
	vehicle.throttle = value


func _on_throttle_slider_drag_started() -> void:
	pass


func _on_steering_slider_value_changed(value : float) -> void:
	vehicle.steering_angle = -value
