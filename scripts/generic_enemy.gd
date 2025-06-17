# scripts/generic_enemy.gd - Enhanced with visual effects
extends RigidBody3D

@onready var feet = $Feet
@onready var nav_agent = $NavigationAgent3D
@export var ai_is_active = true

@export var TARGET_SPEED := 4.0
const TARGET_JUMP = 15.0
const TARGET_GRAVITY = 200.0
@export var MAX_HEALTH := 40

# Combat settings
@export var attack_damage := 15
@export var attack_range := 1.0
@export var attack_cooldown := 1.5
@export var knockback_force := 3.0

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
var max_stuck_time: float = 2.0

# Combat timing
var last_attack_time: float = 0.0
var last_jump_time: float = 0.0

# Death handling
var is_dying: bool = false

# IMPORTANT: Death signal for wave management
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
	
	# Add to enemies group for wave management
	add_to_group("enemies")
	
	print("Enemy initialized at: ", global_position, " with proper collision")

func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	_apply_gravity(delta)
	
	if not target or not ai_is_active:
		return
	
	# Check if target is dead
	if target.get("is_dead") and target.is_dead:
		return
	
	# Simple direct movement towards player
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Attack if close enough
	if distance_to_target <= attack_range:
		_try_attack()
		return
	
	# Move directly towards player
	var direction_to_player = (target.global_position - global_position)
	direction_to_player.y = 0
	direction_to_player = direction_to_player.normalized()
	
	if direction_to_player.length() > 0.1:
		# Check if we need to jump
		if _should_jump_to_target():
			_attempt_jump_to_target()
		
		# Apply movement force towards player
		var target_velocity = direction_to_player * TARGET_SPEED
		target_velocity.y = linear_velocity.y
		
		var velocity_error = target_velocity - linear_velocity
		velocity_error.y = 0
		
		var correction_impulse = _pid.update(velocity_error, delta) * 0.01
		apply_impulse(correction_impulse)
		
		# Face the player
		look_at(global_position + direction_to_player, Vector3.UP)
	
	_check_if_stuck(delta)

func _should_jump_to_target() -> bool:
	if not is_on_floor:
		return false
	
	var current_time = Time.get_time_dict_from_system()["second"]
	var time_since_last_jump = current_time - last_jump_time
	if time_since_last_jump < jump_cooldown:
		return false
	
	var target_pos = target.global_position
	var my_pos = global_position
	
	var height_difference = target_pos.y - my_pos.y
	if height_difference < jump_height_threshold:
		return false
	
	var horizontal_distance = Vector2(target_pos.x - my_pos.x, target_pos.z - my_pos.z).length()
	return horizontal_distance <= max_jump_distance

func _attempt_jump_to_target():
	if not is_on_floor:
		return
	
	var target_pos = target.global_position
	var direction_to_target = (target_pos - global_position).normalized()
	direction_to_target.y = 0
	
	var jump_force = Vector3.UP * TARGET_JUMP + direction_to_target * TARGET_SPEED * 0.3
	apply_impulse(jump_force)
	
	is_on_floor = false
	last_jump_time = Time.get_time_dict_from_system()["second"]

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
	"""Visual effect when enemy attacks"""
	var tween = create_tween()
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)
	
	# Create slash effect
	var slash = MeshInstance3D.new()
	var slash_mesh = TorusMesh.new()
	slash_mesh.inner_radius = 0.5
	slash_mesh.outer_radius = 0.8
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 0.7)
	material.emission_enabled = true
	material.emission = Color(1, 0, 0)
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash_mesh.material = material
	
	slash.mesh = slash_mesh
	add_child(slash)
	slash.position = Vector3(0, 0.5, -0.5)
	slash.rotation.x = deg_to_rad(90)
	
	# Animate the slash
	var slash_tween = create_tween()
	slash_tween.parallel().tween_property(slash, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
	slash_tween.parallel().tween_property(material, "albedo_color", Color(1, 0, 0, 0), 0.2)
	slash_tween.tween_callback(slash.queue_free)

func _check_if_stuck(delta: float):
	var current_pos = global_position
	var movement = current_pos.distance_to(last_target_position)
	
	if movement < 0.1:
		stuck_timer += delta
		if stuck_timer > max_stuck_time:
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
	if is_dying:
		return
		
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	
	# Visual damage feedback
	_show_damage_effect()

	if health <= 0:
		die()

func _show_damage_effect():
	"""Visual effect when enemy takes damage"""
	# Flash red
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var original_material = mesh.material_override
			var flash_material = original_material.duplicate()
			mesh.material_override = flash_material
			
			var tween = create_tween()
			tween.tween_property(flash_material, "albedo_color", Color.WHITE, 0.1)
			tween.tween_property(flash_material, "albedo_color", Color.RED, 0.1)
			tween.tween_callback(func(): mesh.material_override = original_material)
	
	# Create damage particles
	var particles = GPUParticles3D.new()
	add_child(particles)
	particles.position = Vector3(0, 0.5, 0)
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.initial_velocity_min = 1.0
	process_mat.initial_velocity_max = 3.0
	process_mat.angular_velocity_min = -180.0
	process_mat.angular_velocity_max = 180.0
	process_mat.scale_min = 0.05
	process_mat.scale_max = 0.15
	process_mat.color = Color.RED
	particles.process_material = process_mat
	
	var blood_mesh = SphereMesh.new()
	blood_mesh.radial_segments = 4
	blood_mesh.height = 0.1
	blood_mesh.radius = 0.05
	
	var blood_material = StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.8, 0, 0)
	blood_mesh.material = blood_material
	
	particles.draw_pass_1 = blood_mesh
	
	# Clean up particles
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func die() -> void:
	if is_dying:
		return
		
	is_dying = true
	print("Enemy defeated! Emitting death signal...")
	
	# CRITICAL: Emit death signal for wave management
	died.emit()
	
	# Create death effect
	_create_death_effect()
	
	# Visual death animation
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	
	# Remove from enemies group immediately
	remove_from_group("enemies")
	
	# Disable collision and AI
	collision_layer = 0
	collision_mask = 0
	ai_is_active = false
	
	# Queue free after animation
	tween.tween_callback(queue_free)

func _create_death_effect():
	"""Create visual effect when enemy dies"""
	"""Create simple explosion visual effect"""
	print("BOOM! Explosion at: ", global_position)
	
	# Create particles instead of persistent light
	for i in range(8):
		var particle = RigidBody3D.new()
		var mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.1
		sphere_mesh.height = 0.2
		
		# Random explosion colors
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(
			randf_range(0.8, 1.0),  # Red
			randf_range(0.3, 0.4),  # Green  
			randf_range(0.0, 0.2)   # Blue
		)
		material.emission = material.albedo_color * 2.0
		sphere_mesh.material = material
		
		mesh_instance.mesh = sphere_mesh
		particle.add_child(mesh_instance)
		
		# Add collision
		var collision = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.1
		collision.shape = sphere_shape
		particle.add_child(collision)
		
		# Add to scene
		get_tree().current_scene.add_child(particle)
		particle.global_position = global_position
		
		# Random explosion velocity
		var explosion_velocity = Vector3(
			randf_range(-10, 10),
			randf_range(5, 15),
			randf_range(-10, 10)
		)
		particle.linear_velocity = explosion_velocity
		
		# Auto-cleanup particles
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 2.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(func(): 
			if is_instance_valid(particle): 
				particle.queue_free()
		)
		particle.add_child(cleanup_timer)
		cleanup_timer.start()
		

# AI control methods for testing
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

# Force death for debugging
func force_die():
	"""Force enemy to die - useful for testing wave completion"""
	print("DEBUG: Force killing enemy")
	health = 0
	die()
