extends RigidBody3D

@onready var feet = $Feet
@export var attack_damage: int = 25  # Damage per attack
@export var attack_range: float = 10  # How close the enemy must be to attack
@onready var interaction_ray = $InteractionRay 
var health = 100  # Додаємо змінну здоров'я

const TARGET_SPEED = 10.0
const TARGET_JUMP = 70.0
const TARGET_GRAVITY = 200.0

var dodge_ready = true
var is_on_floor = true 
var is_on_slope = false

var _pid := Pid3D.new(30.0, 0.05, 2.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	# Attack
	if Input.is_action_just_pressed("attack"):  # Define an "attack" action in InputMap
		_attack()
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# Movement
	var direction = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	).normalized()
	var target_velocity = direction * TARGET_SPEED
	var velocity_error = target_velocity - linear_velocity
	var correction_impulse = _pid.update(velocity_error, delta) * 0.01
	apply_impulse(correction_impulse)
	
	# Jumping logic
	if Input.is_action_just_pressed("jump"): 
		_jump()

func instantiate() -> void:
	pass

func _jump() -> void: 
	if is_on_floor:
			apply_impulse(Vector3(0.0, TARGET_JUMP, 0.0))
			is_on_floor = false  # Ensure the player isn't marked as "on floor" immediately
			print("Jumped")

func _apply_gravity(delta: float) -> void:
	if feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false
		# Apply a stronger gravity impulse to ensure falling  
		apply_impulse(Vector3(0.0, -TARGET_GRAVITY, 0.0) * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Artificial stopping when no movement input
	var move_input = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	# Define stop speed (tweak as necessary)
	var stop_speed = 0.4
	
	if move_input.length() < 0.2:
		state.linear_velocity.x = lerp(state.linear_velocity.x, 0.0, stop_speed)
		state.linear_velocity.z = lerp(state.linear_velocity.z, 0.0, stop_speed)

	# Slope resistance (push against unreasonable slopes)
	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			var contact_normal = state.get_contact_local_normal(i)
			
			# If on floor and slope is too steep (y < 0.9), counteract sliding
			if is_on_floor and contact_normal.y < 0.8:
				apply_central_force(-contact_normal * 20.0)

func take_damage(amount):
	health -= amount
	if health <= 0:
		queue_free()  # Гравець помер

func _attack() -> void:
	print("Player attacked!")
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if global_transform.origin.distance_to(enemy.global_transform.origin) <= attack_range:
			enemy.take_damage(attack_damage)

func _try_interact():
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target.has_method("interact"):
			target.interact()
			print("Взаємодія виконана!")
