class_name Pacejka94Lateral
extends Resource


# Source: https://www.edy.es/dev/docs/pacejka-94-parameters-explained-a-comprehensive-guide/


@export var a0 := 1.4

@export var a2 := 1100.0

@export var a3 := 1100.0

@export var a4 := 10.0

@export var a7 := -2.0

@export var max_load := 13000


func evaluate(slip_angle : float, tire_load : float) -> float:
	var Fz := clampf(tire_load, 1.0, max_load) / 1000.0
	var C := a0
	var D := Fz * a2
	var BCD := a3 * sin(atan(Fz / a4) * 2.0)
	var B := BCD / (C * D)
	var E := a7
	var x := rad_to_deg(slip_angle)
	var Bx := B * x
	#print({ B = B, C = C, D = D, E = E })
	return D * sin(C * atan(Bx - E * (Bx - atan(Bx))))
