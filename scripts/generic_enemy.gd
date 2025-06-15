# scripts/generic_enemy.gd - Fixed enemy AI that actually chases player
extends RigidBody3D

@onready var feet = $Feet
@onready var nav_agent = $NavigationAgent3D
@export var ai_is_active = true

@export var TARGET_SPEED := 4.0
const TARGET_JUMP = 15.0  # Reduced jump force
const TARGET_GRAVITY = 200.0
@export var MAX_HEALTH := 40

# Combat settings - reduced knockback and damage
@export var attack_damage := 15
@export var attack_range := 2.0
@export var attack_cooldown := 1.5
@export var knockback_force := 3.0  # Reduced knockback

# Jumping logic settings
@export var jump_height_threshold := 1.5
@export var jump_cooldown := 2.0
@export var max_jump_distance := 5.0

var target: Node3D
var is_on_floor = true 
var _pid := Pid3D.new(25.0, 0.1, 1.0)
var health: int = MAX_HEALTH
var last_target_position: Vector3
var stuck_timer: float = 0.0
var max_stuck_time: float = 2.0  # Reduced stuck time

# Combat timing
var last_attack_time: float = 0.0
var last_jump_time: float = 0.0

signal died

func _ready() -> void:
	# Find player target
	target = get_tree().get_first_node_in_group("player")
	if not target:
		target = GameManagerGlobal.get_player()
	
	if not target:
		print("Enemy: No player found! Disabling AI.")
		ai_is_active = false
		return
	
	print("Enemy found player: ", target.name)
	
	# Set up navigation agent
	if not has_node("NavigationAgent3D"):
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
	
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range
	nav_agent.path_max_distance = 3.0
	nav_agent.avoidance_enabled = true
	
	# Set up feet raycast
	if feet:
		feet.target_position = Vector3(0, -1.2, 0)
		feet.enabled = true
	
	last_target_position = global_position
	print("Enemy initialized at: ", global_position, " with proper collision")

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	if not target or not ai_is_active:
		return
	
	# Check if target is dead
	if target.get("is_adead") and target.is_dead:
		return
	
	# Simple direct movement towards player - more reliable than navigation
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Attack if close enough
	if distance_to_target <= attack_range:
		_try_attack()
		return
	
	# Move directly towards player
	var direction_to_player = (target.global_position - global_position)
	direction_to_player.y = 0  # Keep horizontal
	direction_to_player = direction_to_player.normalized()
	
	if direction_to_player.length() > 0.1:
		# Check if we need to jump
		if _should_jump_to_target():
			_attempt_jump_to_target()
		
		# Apply movement force towards player
		var target_velocity = direction_to_player * TARGET_SPEED
		target_velocity.y = linear_velocity.y  # Preserve Y velocity
		
		var velocity_error = target_velocity - linear_velocity
		velocity_error.y = 0  # Don't control Y with PID
		
		var correction_impulse = _pid.update(velocity_error, delta) * 0.01
		apply_impulse(correction_impulse)
		
		# Face the player
		look_at(global_position + direction_to_player, Vector3.UP)
	
	# Check if stuck (simplified)
	_check_if_stuck(delta)

func _should_jump_to_target() -> bool:
	if not is_on_floor:
		return false
	
	# Check jump cooldown
	var current_time = Time.get_time_dict_from_system()["second"]
	var time_since_last_jump = current_time - last_jump_time
	if time_since_last_jump < jump_cooldown:
		return false
	
	var target_pos = target.global_position
	var my_pos = global_position
	
	# Check if target is significantly higher
	var height_difference = target_pos.y - my_pos.y
	if height_difference < jump_height_threshold:
		return false
	
	# Check if target is within reasonable jump distance
	var horizontal_distance = Vector2(target_pos.x - my_pos.x, target_pos.z - my_pos.z).length()
	return horizontal_distance <= max_jump_distance

func _attempt_jump_to_target():
	if not is_on_floor:
		return
	
	var target_pos = target.global_position
	var direction_to_target = (target_pos - global_position).normalized()
	direction_to_target.y = 0
	
	# Apply jump with forward momentum
	var jump_force = Vector3.UP * TARGET_JUMP + direction_to_target * TARGET_SPEED * 0.3
	apply_impulse(jump_force)
	
	is_on_floor = false
	last_jump_time = Time.get_time_dict_from_system()["second"]
	
	print("Enemy jumping towards target!")

func _try_attack():
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - last_attack_time < attack_cooldown:
		return
	
	if target and target.has_method("take_damage"):
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			target.take_damage(attack_damage)
			last_attack_time = current_time
			
			# Apply minimal knockback to target
			if target is RigidBody3D:
				var knockback_direction = (target.global_position - global_position).normalized()
				knockback_direction.y = 0
				target.apply_impulse(knockback_direction * knockback_force)
			
			print("Enemy attacked player for ", attack_damage, " damage!")
			_show_attack_effect()

func _show_attack_effect():
	var tween = create_tween()
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)

func _check_if_stuck(delta: float):
	var current_pos = global_position
	var movement = current_pos.distance_to(last_target_position)
	
	if movement < 0.1:
		stuck_timer += delta
		if stuck_timer > max_stuck_time:
			# Try to unstick with a small jump
			if is_on_floor:
				apply_impulse(Vector3.UP * TARGET_JUMP * 0.5)
				print("Enemy: Trying to unstick with jump")
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	
	last_target_position = current_pos

func _apply_gravity(delta: float) -> void:
	if feet and feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false
		apply_central_impulse(Vector3(0.0, -TARGET_GRAVITY, 0.0) * delta)

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	
	# Visual feedback
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		var tween = create_tween()
		tween.tween_method(_flash_red, 0.0, 1.0, 0.2)

	if health <= 0:
		die()

func _flash_red(progress: float):
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var material = mesh.material_override as StandardMaterial3D
			if material:
				var flash_intensity = sin(progress * PI * 4) * 0.5 + 0.5
				material.emission = Color.RED * flash_intensity

func die() -> void:
	print("Enemy defeated!")
	died.emit()
	
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(queue_free)

# AI control methods
func _set_ai_to_false() -> void:
	ai_is_active = false
	print("Enemy AI disabled")
	
func _set_ai_to_true() -> void:
	ai_is_active = true
	print("Enemy AI enabled")
	
func _get_ai_status() -> bool:
	return ai_is_active

# Wave system methods
func set_health(new_health: int):
	health = new_health
	MAX_HEALTH = new_health

func set_damage(new_damage: int):
	attack_damage = new_damage

func set_speed(new_speed: float):
	TARGET_SPEED = new_speed
