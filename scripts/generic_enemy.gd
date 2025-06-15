# scripts/generic_enemy.gd
extends RigidBody3D

@onready var feet = $Feet
@onready var nav_agent = $NavigationAgent3D
@export var ai_is_active = true  # Default to true

@export var TARGET_SPEED := 4.0
const TARGET_JUMP = 40.0  # Reduced jump force
const TARGET_GRAVITY = 200.0
@export var MAX_HEALTH := 100

var target: Node3D  # The player reference
var is_on_floor = true 
var _pid := Pid3D.new(25.0, 0.1, 1.0)
var health: int = MAX_HEALTH
var last_target_position: Vector3
var stuck_timer: float = 0.0
var max_stuck_time: float = 3.0

signal died

func _ready() -> void:
	# Auto-find the player in the scene
	target = get_tree().get_first_node_in_group("player")
	if not target:
		print("Enemy: No player found in 'player' group!")
		# Try GameManagerGlobal as fallback
		target = GameManagerGlobal.get_player()
	
	if not target:
		print("Enemy: Still no player found! Disabling AI.")
		ai_is_active = false
		return
	
	print("Enemy: Found player target: ", target.name)
	
	# Set up navigation agent
	if not has_node("NavigationAgent3D"):
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
	
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 2.0  # Stop a bit away from player
	nav_agent.path_max_distance = 3.0
	nav_agent.avoidance_enabled = true
	
	# Set up feet raycast
	if feet:
		feet.target_position = Vector3(0, -1.0, 0)
		feet.enabled = true
	
	last_target_position = global_position

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	if not target or not ai_is_active:
		return
	
	# Check if we're stuck
	_check_if_stuck(delta)
	
	# Update navigation target
	nav_agent.target_position = target.global_position
	
	if nav_agent.is_navigation_finished():
		# We've reached the player - maybe attack?
		_attack_player()
		return
	
	# Get movement direction
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Only move horizontally, let gravity handle Y
	direction.y = 0
	direction = direction.normalized()
	
	if direction.length() > 0.1:
		var target_velocity = direction * TARGET_SPEED
		target_velocity.y = linear_velocity.y  # Preserve Y velocity
		
		var velocity_error = target_velocity - linear_velocity
		velocity_error.y = 0  # Don't control Y with PID
		
		var correction_impulse = _pid.update(velocity_error, delta) * 0.01
		apply_impulse(correction_impulse)
		
		# Face the movement direction
		if direction.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
	
	# Jump if needed (less frequently)
	var distance_to_target = global_position.distance_to(target.global_position)
	if is_on_floor and distance_to_target > 3.0 and randf() < 0.1:  # 10% chance per frame
		apply_impulse(Vector3(0.0, TARGET_JUMP, 0.0))
		is_on_floor = false

func _check_if_stuck(delta: float):
	"""Check if enemy is stuck and try to unstick"""
	var current_pos = global_position
	var movement = current_pos.distance_to(last_target_position)
	
	if movement < 0.1:  # Not moving much
		stuck_timer += delta
		if stuck_timer > max_stuck_time:
			# Try to unstick by jumping or moving randomly
			var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			apply_impulse(random_direction * TARGET_SPEED * 0.5)
			if is_on_floor:
				apply_impulse(Vector3.UP * TARGET_JUMP * 0.5)
			stuck_timer = 0.0
			print("Enemy: Trying to unstick")
	else:
		stuck_timer = 0.0
	
	last_target_position = current_pos

func _attack_player():
	"""Simple attack when close to player"""
	if target and global_position.distance_to(target.global_position) < 2.0:
		if target.has_method("take_damage"):
			target.take_damage(10)
			print("Enemy attacked player!")

func _apply_gravity(delta: float) -> void:
	if feet and feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false
		apply_central_impulse(Vector3(0.0, -TARGET_GRAVITY, 0.0) * delta)

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	
	# Visual feedback - flash red or something
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		var tween = create_tween()
		tween.tween_method(_flash_red, 0.0, 1.0, 0.2)

	if health <= 0:
		die()

func _flash_red(progress: float):
	"""Simple red flash effect"""
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			# You can add red tinting here if needed
			pass

func die() -> void:
	print("Enemy defeated!")
	died.emit()
	
	# Simple death effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

func _set_ai_to_false() -> void:
	ai_is_active = false
	print("Enemy AI disabled")
	
func _set_ai_to_true() -> void:
	ai_is_active = true
	print("Enemy AI enabled")
	
func _get_ai_status() -> bool:
	return ai_is_active

# Methods for wave system
func set_health(new_health: int):
	health = new_health
	MAX_HEALTH = new_health

func set_damage(new_damage: int):
	# Store damage for attacks
	pass

func set_speed(new_speed: float):
	TARGET_SPEED = new_speed
