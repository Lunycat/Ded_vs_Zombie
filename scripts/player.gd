extends CharacterBody3D

enum State {NORMAL, KNOCKBACK}

@export var max_distance_mouse: float = 50.0
@export var max_distance_attack: float = 100.0
@export var attack_coldown: float = 0.6
@export var SPEED: float = 6.0
@export var JUMP_VELOCITY: float = 4.5
@export var max_health: int = 100
# Скорость гасания отталкивания
@export var knockback_friction: float = 13.0

@onready var _visual_pivot: Node3D = $VisualPivot
@onready var _gun: Gun = $VisualPivot/Gun

var _camera: Camera3D = null
var _health: int = 0;
var _knockback_velocity: Vector3 = Vector3.ZERO
var _current_state: State = State.NORMAL
var _attack_timer: float = 0.0
var _tracer_material: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("player")
	_health = max_health
	_camera = get_viewport().get_camera_3d()
	_camera.call_deferred("look_at", self.global_position + Vector3(0, 1, 0))
	_init_tracer_material()

func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	_move_activity(delta)
	
	if not is_on_floor():
		_use_gravity(delta)

	_change_state()
	_action_depending_on_state(delta)
	move_and_slide()

func _init_tracer_material() -> void:
	_tracer_material = StandardMaterial3D.new()
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1.0, 0.024, 0.18, 1.0)
	_tracer_material.emission_enabled = true
	_tracer_material.emission = Color(1.0, 0.024, 0.18, 1.0)
	_tracer_material.emission_energy_multiplier = 2.0
	_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _use_gravity(delta: float) -> void:
	velocity += get_gravity() * delta

func _change_state() -> void:
	if _knockback_velocity.length() > 0.0001:
		_current_state = State.KNOCKBACK
	else:
		_current_state = State.NORMAL

func _action_depending_on_state(delta: float) -> void:
	if _current_state == State.KNOCKBACK:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		
		var friction_mul: float = 1.0 if is_on_floor() else 0.1
		_knockback_velocity = _knockback_velocity.move_toward(
			Vector3.ZERO, knockback_friction * friction_mul * delta
		)
	elif _current_state == State.NORMAL:
		_knockback_velocity = Vector3.ZERO
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		# Компенсация сжатия по Z: камера наклонена, поэтому 1 м в мире по Z
		# на экране выглядит короче. Делим input_dir.y на sin(угол подъёма камеры),
		# чтобы скорость на экране была одинаковой во всех направлениях.
		var sin_phi: float = -_camera.global_transform.basis.y.z
		sin_phi = maxf(sin_phi, 0.01)  # защита от деления на 0, если камера горизонтальна
		var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y / sin_phi)
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0, SPEED * 10.0 * delta)

func take_damage(damage: int) -> void:
	_health -= damage
	if _health <= 0:
		_die()

func apply_knockback(direction: Vector3, force: float, toss: float) -> void:
	direction.y = 0
	_knockback_velocity = direction.normalized() * force
	velocity.y = toss

func _move_activity(delta: float) -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = _camera.project_ray_origin(mouse_position)
	var ray_normal: Vector3 = _camera.project_ray_normal(mouse_position)
	var ray_end: Vector3 = ray_origin + ray_normal * max_distance_mouse
	var target: Vector3 = _get_ground_position(ray_origin, ray_end)
	
	if target == Vector3.INF:
		return
	
	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_attack(target)
		_attack_timer = attack_coldown
	
	# Расстояние от персонажа до метки на экране
	var to_target: Vector3 = target - _visual_pivot.global_position
	to_target.y = 0

	if to_target.length_squared() < 0.01:
		return
	
	# Насколько градусов нужно повернуться по вертикальной оси
	_visual_pivot.rotation.y = atan2(-to_target.x, -to_target.z)

func _get_ground_position(ray_origin: Vector3, ray_end: Vector3) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		1 | 3,
		[self]
	)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.INF

func _attack(target: Vector3) -> void:
	var muzzle: Vector3 = _gun.get_node("Muzzle").global_position
	var direction: Vector3 = (target - muzzle).normalized()
	var end_position: Vector3 = muzzle + direction * max_distance_attack
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(muzzle, end_position, 13, [self])
	var hit: Dictionary = space_state.intersect_ray(query)
	
	if not hit.is_empty():
		var collider = hit.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(_gun.damage)
		_spawn_tracer(muzzle, hit.position)
	else:
		_spawn_tracer(muzzle, end_position)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var distance: float = from.distance_to(to)
	if distance < 0.01:
		return
	
	var tracer: MeshInstance3D = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, distance)
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.material_override = _tracer_material.duplicate()
	
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP)
	
	var mat: StandardMaterial3D = tracer.material_override as StandardMaterial3D
	var tween: Tween = tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(tracer.queue_free)

func _die() -> void:
	queue_free()
