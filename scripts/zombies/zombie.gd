extends CharacterBody3D
class_name Zombie

@export var health: int = 100
@export var move_speed: float = 3.0
@export var damage: int = 30
@export var attack_coldown: float = 0.7
@export var knockback_force: float = 5.0 # Скорость отталкивания
@export var toss: float = 5.0 # Высота подброса
@export var slow_move: float = 3.0 # Замедление движения при остановке

@onready var _navigation: NavigationAgent3D = $NavigationAgent3D

enum State {IDLE, PURSUIT, ATTACK}

var _player: CharacterBody3D = null
var _attack_timer: float = 0.0
var _player_in_range: bool = false
var current_state: State = State.IDLE

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
	_navigation.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	_attack_timer -= delta
	
	# Ставим статус
	if not is_instance_valid(_player):
		current_state = State.IDLE
		_player_in_range = false
	elif _player_in_range:
		current_state = State.ATTACK
	else:
		current_state = State.PURSUIT
	
	# Действие в зависимости от статуса
	if current_state == State.IDLE:
		_navigation.velocity = Vector3.ZERO
		velocity.x = move_toward(velocity.x, 0, move_speed * slow_move * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * slow_move * delta)
		move_and_slide()
		return
	elif current_state == State.ATTACK:
		_navigation.velocity = Vector3.ZERO
		_navigation.avoidance_enabled = false
		velocity.x = 0
		velocity.z = 0
		_attack()
		move_and_slide()
	elif current_state == State.PURSUIT:
		_navigation.avoidance_enabled = true
		_pursuit_state()
	

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if current_state == State.ATTACK:
		return
	velocity = safe_velocity
	move_and_slide()

func _pursuit_state() -> void:
	if (_navigation.target_position - _player.global_position).length() > 1:
			_navigation.set_target_position(_player.global_position)
		
	var destination: Vector3 = _navigation.get_next_path_position()
	var local_destination: Vector3 = destination - global_position
	local_destination.y = 0
		
	if local_destination.length_squared() > 0.0001:
		var direction: Vector3 = local_destination.normalized()
		_navigation.velocity = direction * move_speed

func _attack() -> void:
	if _attack_timer > 0.0:
		return
	else:
		_attack_timer = attack_coldown
		_perform_attack()

func _perform_attack():
	if not is_instance_valid(_player):
		return
	_player.take_damage(damage)
	if is_instance_valid(_player):
		var direction: Vector3 = _player.global_position - global_position
		_player.apply_knockback(direction, knockback_force, toss)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	queue_free()
