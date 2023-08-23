class_name PacejkaNormalized
extends Resource


@export var B := 0.1818 :
	set(value):
		B = value
		emit_changed()

@export var C := 1.5 :
	set(value):
		C = value
		emit_changed()

@export var D := 4400.0 :
	set(value):
		D = value
		emit_changed()

@export var E := -2.0 :
	set(value):
		E = value
		emit_changed()

@export var x_scale := 100.0 :
	set(value):
		x_scale = value
		emit_changed()

@export var x_min := 0.85 :
	set(value):
		x_min = value
		emit_changed()

@export var x_max := 7.5 :
	set(value):
		x_max = value
		emit_changed()


func evaluate(x : float) -> float:
	var Bx := B * signf(x) * clampf(absf(x), x_min, x_max)
	return D * sin(C * atan(Bx - E * (Bx - atan(Bx))))


func find_optimum(steps := 4) -> float:
	var x := x_scale
	for i in steps:
		var derivative := _dr(x)
		if is_zero_approx(derivative):
			break
		x = x - _r(x) / derivative
	return x


# _r is the part of the formula derivative that must be 0 to find the optimum
# NOTE: this is _not_ the complete derivative!
func _r(x : float) -> float:
	var Bx := B * x
	return (1 - E) * Bx + E * atan(Bx) - tan(PI / (2.0 * C))


# _dr is the derivative of _r; needed for Newton-Raphson
func _dr(x : float) -> float:
	var Bx := B * x
	return B * E * (1.0 / (Bx * Bx + 1) - 1) + B
