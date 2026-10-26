extends CharacterBody3D
class_name Zombie

@export var health: int = 100
@export var move_speed: float = 3.0
@export var damage: int = 30
@export var attack_coldown: float = 0.7
@export var knockback_force: float = 5.0 # Скорость отталкивания
@export var toss: float = 5.0 # Высота подброса

@onready var _navigation: NavigationAgent3D = $NavigationAgent3D

var _player: CharacterBody3D = null
var _attack_timer: float = 0.0
var _player_in_range: bool = false

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	$Area3D.body_entered.connect(func(body): 
		if body.is_in_group("player"):
			_player_in_range = true
	)
	$Area3D.body_exited.connect(func(body):
		if body.is_in_group("player"):
			_player_in_range = false
	)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	_attack_timer -= delta
	
	if not is_instance_valid(_player):
		_player_in_range = false
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	
	if _player_in_range:
		velocity.x = 0
		velocity.z = 0
		_attack()
	else:
		if (_navigation.target_position - _player.position).length() > 1:
			_navigation.set_target_position(_player.global_position)
		
		var destination: Vector3 = _navigation.get_next_path_position()
		var local_destination: Vector3 = destination - global_position
		local_destination.y = 0
		
		if local_destination.length_squared() > 0.0001:
			var direction: Vector3 = local_destination.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
	
	move_and_slide()

func _attack() -> void:
	if _attack_timer > 0.0:
		return
	else:
		_attack_timer = attack_coldown
		_perform_attack()

func _perform_attack():
	_player.take_damage(damage)
	var direction: Vector3 = _player.global_position - global_position
	_player.apply_knockback(direction, knockback_force, toss)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	queue_free()
