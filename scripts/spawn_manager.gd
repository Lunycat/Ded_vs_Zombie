extends Node3D

@export var min_radius: float = 6
@export var max_radius: float = 10
@export var max_zombies: int = 10

@onready var _timer: Timer = $Timer

const ZOMBIE_SCENE: Resource = preload("res://scenes/zombies/zombie.tscn")
const GOLDEN_ANGLE: float = PI * (3.0 - sqrt(5.0))
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _angle: float = 0
var _spawn_count: int = 0
var _alive_zombie: int = 0
var _R: float = 0
var _navigation_map: RID

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_camera = get_viewport().get_camera_3d()
	_timer.timeout.connect(_on_timeout)
	_navigation_map = get_world_3d().navigation_map

func _on_timeout() -> void:
	if not is_instance_valid(_player):
		return
	
	if _alive_zombie < max_zombies:
		_angle = wrapf(_spawn_count * GOLDEN_ANGLE, 0.0, TAU)
		_R = randf_range(min_radius, max_radius)
		var x: float = _player.global_position.x + _R * cos(_angle)
		var z: float = _player.global_position.z + _R * sin(_angle)
		var y: float = _get_ground_y(x, z)
		var vector_of_spawn: Vector3 = Vector3(x, y, z)
		var vector_valid: Vector3 = NavigationServer3D.map_get_closest_point(
			_navigation_map, vector_of_spawn
		)
		var distance: float = vector_of_spawn.distance_to(vector_valid)
		if distance < 0.6 and not _camera.is_position_in_frustum(vector_valid):
			_spawn_zombies(vector_valid)

func _spawn_zombies(vector: Vector3) -> void:
	var zombie: CharacterBody3D = ZOMBIE_SCENE.instantiate()
	_spawn_count += 1
	_alive_zombie += 1
	zombie.global_position = vector
	zombie.tree_exited.connect(_decrement_alive_zombie)
	add_child(zombie)

func _get_ground_y(x: float, z: float) -> float:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(x, 100, z),
		Vector3(x, -100, z),
		1,
		[self]
	)
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		return result.position.y
	
	return 0.0

func _decrement_alive_zombie():
	_alive_zombie -= 1
