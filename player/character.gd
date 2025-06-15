# player/character.gd - Fixed movement section
extends RigidBody3D

@onready var feet = $Feet  
@onready var interaction_ray = $InteractionRay 
@onready var weapon_system = $WeaponManager

@export var mortar_shell_scene: PackedScene
@export var mortar_launch_angle: float = 45.0
@export var mortar_min_range: float = 10.0
@export var mortar_max_range: float = 80.0
@onready var launch_point = $"."

var health := 100
var max_health := 100
var ammo := 30  # Starting ammo
var max_ammo := 30

const TARGET_SPEED := 10.0
const TARGET_JUMP := 70.0
const TARGET_GRAVITY := 200.0

var dodge_ready = true
var is_on_floor = true 
var _pid := Pid3D.new(30.0, 0.05, 2.0)

signal health_changed(new_health: int, max_health: int)
signal ammo_changed(new_ammo: int, max_ammo: int)

func _ready() -> void:
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 5.0
	
	add_to_group("player")
	
	if not launch_point:
		launch_point = Marker3D.new()
		launch_point.name = "LaunchPoint"
		launch_point.position = Vector3(0, 1.5, 0.5)
		add_child(launch_point)
	
	if weapon_system:
		weapon_system.mortar_shell_scene = mortar_shell_scene
		weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	# Emit initial values
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, max_ammo)

func _physics_process(delta: float) -> void:
	_update_floor_detection()
	_apply_gravity(delta)
	
	# Fire current weapon
	if Input.is_action_just_pressed("attack"):
		if weapon_system and ammo > 0:
			weapon_system.fire()
			ammo -= 1
			ammo_changed.emit(ammo, max_ammo)
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# FIXED MOVEMENT - Corrected the direction mapping
	var direction = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	).normalized()
	
	# Apply movement
	if direction.length() > 0.1:
		var target_velocity = direction * TARGET_SPEED
		target_velocity.y = linear_velocity.y
		
		var velocity_error = Vector3(
			target_velocity.x - linear_velocity.x,
			0.0,
			target_velocity.z - linear_velocity.z
		)
		
		var correction_impulse = _pid.update(velocity_error, delta) * 0.01
		apply_impulse(correction_impulse)
	
	# Jumping logic
	if Input.is_action_just_pressed("jump"): 
		_jump()

func _update_floor_detection():
	if feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false

func _jump() -> void: 
	if is_on_floor:
		apply_impulse(Vector3.UP * TARGET_JUMP)
		is_on_floor = false
		print("Jumped")

func _apply_gravity(delta: float) -> void:
	if not is_on_floor:
		apply_central_impulse(Vector3.DOWN * TARGET_GRAVITY * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# FIXED MOVEMENT INPUT - Corrected the direction mapping
	var move_input = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	
	if move_input.length() < 0.1:
		var stop_speed = 0.4
		state.linear_velocity.x = lerp(state.linear_velocity.x, 0.0, stop_speed)
		state.linear_velocity.z = lerp(state.linear_velocity.z, 0.0, stop_speed)

func take_damage(amount):
	health -= amount
	health = max(0, health)  # Clamp to 0
	health_changed.emit(health, max_health)
	print("Player took ", amount, " damage. Health: ", health)
	if health <= 0:
		print("Player died!")
		# You can add death logic here

func heal(amount):
	health += amount
	health = min(max_health, health)  # Clamp to max
	health_changed.emit(health, max_health)
	print("Player healed ", amount, ". Health: ", health)

func add_ammo(amount):
	ammo += amount
	ammo = min(max_ammo, ammo)  # Clamp to max
	ammo_changed.emit(ammo, max_ammo)
	print("Player gained ", amount, " ammo. Ammo: ", ammo)

func _try_interact():
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target.has_method("interact"):
			target.interact()
			print("Взаємодія виконана!")

func _on_weapon_changed(weapon_type):
	print("Weapon changed to: ", weapon_type)

# Mortar firing functions
func _fire_mortar_at_cursor():
	if not mortar_shell_scene:
		print("Mortar shell scene not assigned!")
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("No camera found!")
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 2000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		_fire_mortar_at_position(result.position)
	else:
		print("No target found under cursor!")

func _fire_mortar_at_position(target_pos: Vector3):
	if not mortar_shell_scene:
		return
	
	var distance = global_position.distance_to(target_pos)
	
	if distance < mortar_min_range:
		print("Target too close! Min range: ", mortar_min_range)
		return
	elif distance > mortar_max_range:
		print("Target too far! Max range: ", mortar_max_range)
		return
	
	var shell = mortar_shell_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	shell.global_position = launch_point.global_position
	
	var launch_velocity = _calculate_mortar_trajectory(target_pos)
	
	if launch_velocity.length() > 0:
		var look_direction = Vector3(target_pos.x - global_position.x, 0, target_pos.z - global_position.z).normalized()
		if look_direction.length() > 0:
			look_at(global_position + look_direction, Vector3.UP)
		
		if shell.has_method("launch"):
			shell.launch(launch_velocity.normalized(), launch_velocity.length())
		else:
			print("Mortar shell missing launch method!")
			shell.queue_free()
			return
		
		var recoil = -look_direction * 2.0
		apply_impulse(recoil)
		
		print("Mortar fired! Target: ", target_pos, " Distance: ", distance)
	else:
		print("Cannot calculate trajectory!")
		shell.queue_free()

func _calculate_mortar_trajectory(target_pos: Vector3) -> Vector3:
	var start_pos = launch_point.global_position
	var displacement = target_pos - start_pos
	var horizontal_distance = Vector2(displacement.x, displacement.z).length()
	var vertical_distance = displacement.y
	
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var angle_rad = deg_to_rad(mortar_launch_angle)
	
	var velocity_squared = (gravity * horizontal_distance * horizontal_distance) / (2.0 * cos(angle_rad) * cos(angle_rad) * (horizontal_distance * tan(angle_rad) - vertical_distance))
	
	if velocity_squared <= 0:
		angle_rad = deg_to_rad(70.0)
		velocity_squared = (gravity * horizontal_distance * horizontal_distance) / (2.0 * cos(angle_rad) * cos(angle_rad) * (horizontal_distance * tan(angle_rad) - vertical_distance))
		
		if velocity_squared <= 0:
			return Vector3.ZERO
	
	var velocity = sqrt(velocity_squared)
	var horizontal_dir = Vector3(displacement.x, 0, displacement.z).normalized()
	var launch_direction = (horizontal_dir * cos(angle_rad) + Vector3.UP * sin(angle_rad)).normalized()
	
	return launch_direction * velocity
