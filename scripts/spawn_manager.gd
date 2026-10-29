extends Node3D

@export var min_radius: float = 6
@export var max_radius: float = 10
@export var max_zombies: int = 10

@onready var _timer: Timer = $Timer

const ZOMBIE_SCENE: Resource = preload("res://scenes/zombies/zombie.tscn")
const GOLDEN_ANGLE: float = PI * (3.0 - sqrt(5.0))
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _spawn_count: int = 0
var _alive_zombie: int = 0
var _navigation_map: RID

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_camera = get_viewport().get_camera_3d()
	_timer.timeout.connect(_on_timeout)
	_navigation_map = get_world_3d().navigation_map

func _on_timeout() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	
	if _alive_zombie < max_zombies:
		var angle: float = wrapf(_spawn_count * GOLDEN_ANGLE, 0.0, TAU)
		var R: float = randf_range(min_radius, max_radius)
		var x: float = _player.global_position.x + R * cos(angle)
		var z: float = _player.global_position.z + R * sin(angle)
		var vector_of_spawn: Vector3 = Vector3(x, 0, z)
		var vector_valid: Vector3 = NavigationServer3D.map_get_closest_point(
			_navigation_map, vector_of_spawn
		)
		var distance: float = Vector2(x - vector_valid.x, z - vector_valid.z).length()
		_spawn_count += 1
		#if distance < 0.6 and not _camera.is_position_in_frustum(vector_valid):
		if distance < 0.6:
			_spawn_zombies(vector_valid)

func _spawn_zombies(vector: Vector3) -> void:
	var zombie: CharacterBody3D = ZOMBIE_SCENE.instantiate()
	zombie.tree_exited.connect(_decrement_alive_zombie)
	add_child(zombie)
	zombie.global_position = vector
	_alive_zombie += 1

func _decrement_alive_zombie():
	_alive_zombie -= 1
