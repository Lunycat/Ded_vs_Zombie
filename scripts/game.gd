extends Node3D

var _player: CharacterBody3D = null
@onready var _timer: Timer = $Timer

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_timer.wait_time = 0.333
	_timer.autostart = true

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	print(_player._health)
