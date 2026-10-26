extends Node3D

@export var min_radius = 10
@export var max_radius = 15

@onready var _player: CharacterBody3D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	pass
