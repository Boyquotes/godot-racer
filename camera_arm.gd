extends Node3D


@export var stiffness := 0.1


@onready var _target : Node3D = get_parent()

@onready var _offset := global_position - _target.global_position


func _ready() -> void:
	top_level = true
	_physics_process(0.0)


func _physics_process(_delta : float) -> void:
	var ideal_position := _target.global_position + _offset.rotated(Vector3.UP, _target.global_rotation.y)
	var interpolated_position := global_position.lerp(ideal_position, stiffness)
	look_at_from_position(interpolated_position, _target.global_position)
