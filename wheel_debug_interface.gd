extends Control


const MAX_POINTS := 256


@export var wheel : Wheel


@onready var _vehicle_weight := _get_vehicle_weight()

@onready var _angular_velocity_plot : TimeSeriesPlot = %angular_velocity_plot

@onready var _slip_velocity_x_plot : TimeSeriesPlot = %slip_velocity_x_plot

@onready var _slip_velocity_y_plot : TimeSeriesPlot = %slip_velocity_y_plot

@onready var _tire_load_plot : TimeSeriesPlot = %tire_load_plot

@onready var _pacejka_longitudinal_plot : TimeSeriesPlot = %pacejka_longitudinal_plot

@onready var _pacejka_lateral_plot : TimeSeriesPlot = %pacejka_lateral_plot

@onready var _pacejka_load_slider : Slider = %pacejka_load_slider

@onready var _pacejka_load_spin_box : SpinBox = %pacejka_load_spin_box


var _pacejka_load := 0.0 :
	set(value):
		if is_equal_approx(value, _pacejka_load):
			return

		_pacejka_load = value

		_on_pacejka_load_changed()


func _ready() -> void:
	_pacejka_load_slider.max_value = _vehicle_weight
	_pacejka_load_spin_box.max_value = _vehicle_weight

	_pacejka_load = 0.25 * _vehicle_weight


func _physics_process(_delta : float) -> void:
	_angular_velocity_plot.push_value(wheel.get_angular_velocity())
	#var slip_velocity := wheel.get_slip_velocity()
	var slip_velocity := wheel.get_grip()
	_slip_velocity_x_plot.push_value(slip_velocity.x)
	_slip_velocity_y_plot.push_value(slip_velocity.y)
	_tire_load_plot.push_value(wheel.get_tire_load())


func _on_pacejka_load_changed() -> void:
	_plot_pacejka_longitudinal()
	_plot_pacejka_lateral()

	_pacejka_load_slider.value = _pacejka_load
	_pacejka_load_spin_box.value = _pacejka_load


func _plot_pacejka_longitudinal() -> void:
	_pacejka_longitudinal_plot.clear_data()
	_pacejka_longitudinal_plot.data_range_upper = 1.25 * _pacejka_load

	for i in _pacejka_longitudinal_plot.max_data_points:
		var x := lerpf(0.0, 5.0, float(i) / (_pacejka_longitudinal_plot.max_data_points - 1))
		var value := _pacejka_load * wheel.pacejka_combination.evaluate(Vector2(x, 0.0)).x
		_pacejka_longitudinal_plot.push_value(value)


func _plot_pacejka_lateral() -> void:
	_pacejka_lateral_plot.clear_data()
	_pacejka_lateral_plot.data_range_upper = 1.25 * _pacejka_load

	for i in _pacejka_lateral_plot.max_data_points:
		var x := lerpf(0.0, PI, float(i) / (_pacejka_lateral_plot.max_data_points - 1))
		var value := _pacejka_load * wheel.pacejka_combination.evaluate(Vector2(0.0, x)).y
		_pacejka_lateral_plot.push_value(value)


func _get_vehicle_weight() -> float:
	var vehicle := wheel.get_vehicle()
	var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var weight := gravity * vehicle.mass
	return weight


func _on_pacejka_load_slider_value_changed(value : float) -> void:
	_pacejka_load = value


func _on_pacejka_load_spin_box_value_changed(value: float) -> void:
	_pacejka_load = value
