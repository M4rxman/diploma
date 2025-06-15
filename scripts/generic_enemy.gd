# scripts/generic_enemy.gd - Properly using NavigationAgent3D
extends RigidBody3D

@onready var feet = $Feet
@onready var nav_agent = $NavigationAgent3D
@onready var mesh_instance = $MeshInstance3D
@export var ai_is_active = true

@export var TARGET_SPEED := 2.0
const TARGET_JUMP = 40.0
const TARGET_GRAVITY = 150.0
@export var MAX_HEALTH := 100

var target: Node3D
var is_on_floor = true 
var health: int = MAX_HEALTH
var move_timer: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown: float = 2.0

signal died

func _ready() -> void:
	# Physics setup - NORMAL collision, not giant
	gravity_scale = 1.0
	linear_damp = 3.0  # Higher damping to prevent sliding
	angular_damp = 10.0
	sleeping = false
	can_sleep = false
	
	# Normal collision settings
	collision_layer = 4  # Enemy layer
	collision_mask = 1   # Collide with ground only
	
	add_to_group("enemies")
	
	# Ensure mesh is visible and normal color
	if mesh_instance:
		mesh_instance.visible = true
		# Reset material to default red enemy color
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.2, 0.2, 1)  # Red
		material.metallic = 0.3
		material.roughness = 0.7
		mesh_instance.material_override = material
	
	# Wait for scene setup
	await get_tree().process_frame
	await get_tree().process_frame
	
	_find_player()
	
	# Setup NavigationAgent3D properly
	if nav_agent:
		# Wait for navigation to be ready
		call_deferred("_setup_navigation")
	
	# Setup feet
	if feet:
		feet.target_position = Vector3(0, -1.0, 0)
		feet.enabled = true
		feet.collision_mask = 1  # Ground only
	
	print("Enemy initialized at: ", global_position, " with proper collision")

func _setup_navigation():
	"""Setup navigation agent after scene is ready"""
	if not nav_agent:
		return
		
	# Wait for navigation map to be ready
	await NavigationServer3D.map_changed
	await get_tree().process_frame
	
	# Configure navigation agent
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 2.0
	nav_agent.path_max_distance = 20.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	nav_agent.height = 1.0
	nav_agent.max_speed = TARGET_SPEED
	nav_agent.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_EDGECENTERED
	
	print("Enemy navigation setup complete")

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		print("Enemy found player: ", target.name)
		return
	
	target = get_tree().current_scene.find_child("Player", true, false)
	if target:
		print("Enemy found player by search: ", target.name)
		return
	
	print("Enemy could not find player!")
	ai_is_active = false

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	if not target or not ai_is_active:
		return
	
	if not is_instance_valid(target):
		_find_player()
		return
	
	move_timer += delta
	attack_timer += delta
	
	var distance_to_player = global_position.distance_to(target.global_position)
	
	# Attack if close enough
	if distance_to_player < 2.0 and attack_timer >= attack_cooldown:
		_attack_player()
		attack_timer = 0.0
		return
	
	# Update navigation target every 0.3 seconds
	if move_timer >= 0.3:
		move_timer = 0.0
		if nav_agent and distance_to_player > 2.5:
			nav_agent.target_position = target.global_position
	
	# Move using NavigationAgent3D
	if distance_to_player > 2.5:
		_navigate_to_player(delta)

func _navigate_to_player(delta: float):
	"""Use NavigationAgent3D to move toward player"""
	if not nav_agent:
		return
	
	# Check if we have a valid path
	if nav_agent.is_navigation_finished():
		return
	
	# Get next position from navigation
	var next_position = nav_agent.get_next_path_position()
	var current_position = global_position
	
	# Calculate direction to next waypoint
	var direction = (next_position - current_position).normalized()
	direction.y = 0  # Only move horizontally
	
	if direction.length() > 0.1:
		# Apply movement force
		var movement_impulse = direction * TARGET_SPEED * 50.0 * delta
		apply_central_impulse(movement_impulse)
		
		# Rotate to face movement direction
		var look_direction = direction
		if look_direction.length() > 0.1:
			var target_transform = transform.looking_at(global_position + look_direction, Vector3.UP)
			transform = transform.interpolate_with(target_transform, delta * 5.0)

func _attack_player():
	"""Attack the player when close"""
	if not target or not is_instance_valid(target):
		return
	
	var distance = global_position.distance_to(target.global_position)
	if distance < 2.5:
		if target.has_method("take_damage"):
			target.take_damage(20)
			print("Enemy attacked player for 20 damage!")
			
			# Knockback player
			if target is RigidBody3D:
				var knockback_dir = (target.global_position - global_position).normalized()
				target.apply_central_impulse(knockback_dir * 200.0)

func _apply_gravity(delta: float) -> void:
	if feet and feet.is_colliding():
		is_on_floor = true
		# Prevent bouncing
		if linear_velocity.y < 0:
			linear_velocity.y = 0
	else:
		is_on_floor = false
		apply_central_impulse(Vector3.DOWN * TARGET_GRAVITY * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Limit velocity to prevent crazy movement
	var max_velocity = TARGET_SPEED * 1.5
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	
	# Flash red when damaged
	if mesh_instance:
		var tween = create_tween()
		var original_material = mesh_instance.material_override
		
		# Flash red
		var red_material = StandardMaterial3D.new()
		red_material.albedo_color = Color.RED
		mesh_instance.material_override = red_material
		
		tween.tween_interval(0.1)
		tween.tween_callback(func(): mesh_instance.material_override = original_material)
	
	# Small knockback when damaged
	if target and is_instance_valid(target):
		var knockback_dir = (global_position - target.global_position).normalized()
		apply_central_impulse(knockback_dir * 100.0)
	
	if health <= 0:
		die()

func die() -> void:
	print("Enemy defeated!")
	died.emit()
	
	# Death animation
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(self, "rotation", Vector3(0, PI * 2, 0), 0.5)
	tween.tween_callback(queue_free)

# AI control methods
func _set_ai_to_false() -> void:
	ai_is_active = false

func _set_ai_to_true() -> void:
	ai_is_active = true
	_find_player()

func _get_ai_status() -> bool:
	return ai_is_active

# Wave system methods
func set_health(new_health: int):
	health = new_health
	MAX_HEALTH = new_health

func set_damage(new_damage: int):
	pass

func set_speed(new_speed: float):
	TARGET_SPEED = new_speed
	if nav_agent:
		nav_agent.max_speed = new_speed
