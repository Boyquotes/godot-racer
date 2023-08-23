class_name PacejkaCombination
extends Resource


@export var longitudinal : PacejkaNormalized :
	set(value):
		if longitudinal != null:
			longitudinal.changed.disconnect(_on_changed)
		longitudinal = value
		if longitudinal != null:
			longitudinal.changed.connect(_on_changed)
		emit_changed()

@export var lateral : PacejkaNormalized :
	set(value):
		if lateral != null:
			lateral.changed.disconnect(_on_changed)
		lateral = value
		if lateral != null:
			lateral.changed.connect(_on_changed)
		emit_changed()


var _longitudinal_optimum := 1.0

var _lateral_optimum := 1.0

var _optimum_available := false


func evaluate(slip_velocity : Vector2, debug_print := false) -> Vector2:
	# NOTE: normalize must be called before evaluation
	assert(_optimum_available)

	var dimensionless := slip_velocity / Vector2(_longitudinal_optimum, _lateral_optimum)

	var length := dimensionless.length()
	if is_zero_approx(length):
		return Vector2.ZERO

	if debug_print:
		#print(slip_velocity)
		#print(length * Vector2(_longitudinal_optimum, _lateral_optimum))
		pass

	return Vector2(
		dimensionless.x / length * longitudinal.evaluate(length * _longitudinal_optimum),
		dimensionless.y / length * lateral.evaluate(length * _lateral_optimum),
	)


func normalize() -> void:
	if not _optimum_available:
		_on_changed()


func _on_changed() -> void:
	if longitudinal != null and lateral != null:
		_longitudinal_optimum = longitudinal.find_optimum()
		_lateral_optimum = lateral.find_optimum()
		_optimum_available = true
	else:
		_longitudinal_optimum = 1.0
		_lateral_optimum = 1.0
		_optimum_available = false
