extends CharacterBody3D

@export var SPEED: float = 6.0
@export var JUMP_VELOCITY: float = 4.5
@export var max_health: int = 100
@export var knockback_friction: float = 13.0 # Скорость гасания отталкивания

var _health: int = 0;
var _knockback_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	_health = max_health

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _knockback_velocity.length() > 0.0001:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		
		var friction_mul: float = 1.0 if is_on_floor() else 0.1
		_knockback_velocity = _knockback_velocity.move_toward(
			Vector3.ZERO, knockback_friction * friction_mul * delta
		)
	else:
		_knockback_velocity = Vector3.ZERO
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if is_on_floor():
			if direction:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED * 10.0 * delta)
				velocity.z = move_toward(velocity.z, 0, SPEED * 10.0 * delta)
		else:
			if direction:
				velocity.x = move_toward(velocity.x, direction.x * SPEED, SPEED * 2.0 * delta)
				velocity.z = move_toward(velocity.z, direction.z * SPEED, SPEED * 2.0 * delta)

	move_and_slide()

func take_damage(damage: int) -> void:
	_health -= damage
	if _health <= 0:
		_die()

func apply_knockback(direction: Vector3, force: float, toss: float) -> void:
	direction.y = 0
	_knockback_velocity = direction.normalized() * force
	velocity.y = toss

func _die() -> void:
	queue_free()
