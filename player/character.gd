# player/character.gd - Fixed death system
extends RigidBody3D

@onready var feet = $Feet  
@onready var interaction_ray = $InteractionRay 
@onready var weapon_system = $WeaponManager
@onready var mesh_instance = $MeshInstance3D

@export var mortar_shell_scene: PackedScene
@export var mortar_launch_angle: float = 45.0
@export var mortar_min_range: float = 5.0
@export var mortar_max_range: float = 50.0
@onready var launch_point = $"."

var health := 100
var max_health := 100
var ammo := 30
var max_ammo := 30

const TARGET_SPEED := 10.0
const TARGET_JUMP := 15.0
const TARGET_GRAVITY := 200.0

var dodge_ready = true
var is_on_floor = true 
var _pid := Pid3D.new(30.0, 0.05, 2.0)
var jump_buffer_time := 0.0
var is_dead := false  # Track death state

signal health_changed(new_health: int, max_health: int)
signal ammo_changed(new_ammo: int, max_ammo: int)
signal player_died

func _ready() -> void:
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 5.0
	
	sleeping = false
	can_sleep = false
	
	add_to_group("player")
	
	# Character visibility fix
	if mesh_instance:
		mesh_instance.visible = true
		mesh_instance.layers = 2
		mesh_instance.sorting_use_aabb_center = true
		mesh_instance.sorting_offset = 10.0
		print("Character mesh setup - Visible:", mesh_instance.visible)
	
	if feet:
		feet.target_position = Vector3(0, -0.6, 0)
		feet.enabled = true
		feet.collision_mask = 1
	
	if not launch_point:
		launch_point = Marker3D.new()
		launch_point.name = "LaunchPoint"
		launch_point.position = Vector3(0, 1.5, 0.5)
		add_child(launch_point)
	
	if weapon_system:
		weapon_system.mortar_shell_scene = mortar_shell_scene
		weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, max_ammo)
	
	print("Player initialized at position: ", global_position)

func _physics_process(delta: float) -> void:
	# Don't process if dead
	if is_dead:
		return
		
	_update_floor_detection()
	_apply_gravity(delta)
	
	if jump_buffer_time > 0:
		jump_buffer_time -= delta
	
	# Fire current weapon
	if Input.is_action_just_pressed("attack"):
		if weapon_system and ammo > 0:
			weapon_system.fire()
			ammo -= 1
			ammo_changed.emit(ammo, max_ammo)
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# Movement
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
	
	# Jump input with buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_time = 0.2
	
	if jump_buffer_time > 0 and is_on_floor:
		_jump()
		jump_buffer_time = 0

func _update_floor_detection():
	if feet and feet.is_colliding():
		is_on_floor = true
		var collision_point = feet.get_collision_point()
		
		var min_height = collision_point.y + 0.5
		if global_position.y < min_height:
			global_position.y = min_height
			if linear_velocity.y < 0:
				linear_velocity.y = 0
	else:
		is_on_floor = false

func _jump() -> void:
	if is_on_floor:
		linear_velocity.y = 0
		apply_impulse(Vector3.UP * TARGET_JUMP)
		is_on_floor = false
		print("Jumped with force: ", TARGET_JUMP)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor:
		apply_central_impulse(Vector3.DOWN * TARGET_GRAVITY * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_dead:
		return
		
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
	# Prevent damage spam when already dead
	if is_dead:
		return
		
	health -= amount
	health = max(0, health)
	health_changed.emit(health, max_health)
	print("Player took ", amount, " damage. Health: ", health)
	
	if health <= 0 and not is_dead:
		die()

func die():
	"""Handle player death properly"""
	if is_dead:
		return  # Already dead
		
	is_dead = true
	print("Player died!")
	player_died.emit()
	
	# Stop physics processing
	set_physics_process(false)
	
	# Visual death effect
	if mesh_instance:
		var tween = create_tween()
		tween.parallel().tween_property(mesh_instance, "modulate", Color.RED, 0.5)
		tween.parallel().tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), 1.0)

func respawn(spawn_position: Vector3):
	"""Respawn the player"""
	is_dead = false
	health = max_health
	ammo = max_ammo
	
	# Reset visuals
	scale = Vector3.ONE
	if mesh_instance:
		mesh_instance.modulate = Color.WHITE
	
	# Reset position
	global_position = spawn_position + Vector3(0, 2, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Re-enable physics
	set_physics_process(true)
	
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, max_ammo)
	
	print("Player respawned at: ", global_position)

func heal(amount):
	if is_dead:
		return
		
	health += amount
	health = min(max_health, health)
	health_changed.emit(health, max_health)
	print("Player healed for ", amount, ". Health: ", health)

func add_ammo(amount):
	if is_dead:
		return
		
	ammo += amount
	ammo = min(max_ammo, ammo)
	ammo_changed.emit(ammo, max_ammo)
	print("Player gained ", amount, " ammo. Ammo: ", ammo)

func _try_interact():
	if is_dead:
		return
		
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target.has_method("interact"):
			target.interact()

func _on_weapon_changed(weapon_type):
	print("Weapon changed to: ", weapon_type)

# Mortar system
func _fire_mortar_at_cursor():
	if is_dead or not mortar_shell_scene:
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if not result:
		print("No target found!")
		return
	
	var target_position = result.position
	var distance = global_position.distance_to(target_position)
	
	if distance < mortar_min_range:
		print("Target too close! Distance: ", distance)
		return
	if distance > mortar_max_range:
		print("Target too far! Distance: ", distance)
		return
	
	var shell = mortar_shell_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	shell.global_position = global_position + Vector3(0, 1, 0)
	
	shell.launch_at_target(target_position)
	
	var recoil_direction = (global_position - target_position).normalized()
	recoil_direction.y = 0
	apply_central_impulse(recoil_direction * 100.0)
	
	print("Mortar fired at: ", target_position, " Distance: ", distance)
