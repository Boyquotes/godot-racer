class_name SpringConstraint
extends Node


@export var anchor_1 : Node3D

@export var anchor_2 : Node3D

@export var stiffness := 1.0


@onready var _rest_length := anchor_1.global_position.distance_to(anchor_2.global_position)


func _physics_process(_delta : float) -> void:
	var offset := anchor_2.global_position - anchor_1.global_position
	var length := offset.length()
	var force_magnitude := stiffness * (length - _rest_length)


	var direction := offset / length

	var body_1 : RigidBody3D = anchor_1.get_parent()
	body_1.apply_force(
		force_magnitude * direction,
		anchor_1.global_position - body_1.global_position
	)

	var body_2 : RigidBody3D = anchor_2.get_parent()
	body_2.apply_force(
		-force_magnitude * direction,
		anchor_2.global_position - body_2.global_position
	)
	#print(-force_magnitude * direction, ", ", anchor_2.global_position - body_2.global_position)
