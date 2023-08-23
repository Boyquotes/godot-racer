class_name Pacejka94Longitudinal
extends Resource


# Source: https://www.edy.es/dev/docs/pacejka-94-parameters-explained-a-comprehensive-guide/


@export var b0 := 1.5

@export var b2 := 1100.0

@export var b4 := 300.0

@export var b8 := -2.0

@export var max_load := 13000


func evaluate(slip_ratio : float, tire_load : float) -> float:
	var Fz := clampf(tire_load, 1.0, max_load) / 1000.0
	var C := b0
	var D := Fz * b2
	var BCD := b4 * Fz
	var B := BCD / (C * D)
	var E := b8
	var x := slip_ratio * 100.0
	var Bx := B * x
	return D * sin(C * atan(Bx - E * (Bx - atan(Bx))))


func print_params(reference_load := 4000.0) -> void:
	var Fz := reference_load / 1000.0
	var C := b0
	var D := Fz * b2
	var BCD := b4 * Fz
	var B := BCD / (C * D)
	var E := b8
	print({ B = B, C = C, D = D, E = E })
