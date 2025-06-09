extends RigidBody3D

@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 50.0
@export var explosion_force: float = 1000.0

# Preload explosion effect scene (create this separately)
# @export var explosion_effect_scene: PackedScene

var initial_velocity: Vector3
var armed: bool = false
var arm_time: float = 0.1  # Time before shell can explode

func _ready():
	# Set up the rigidbody for projectile behavior
	gravity_scale = 1.0
	continuous_cd = true  # Important for fast projectiles
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Arm the shell after a short delay
	await get_tree().create_timer(arm_time).timeout
	armed = true
	
	# Optional: Destroy after timeout if it doesn't hit anything
	await get_tree().create_timer(10.0).timeout
	queue_free()

func launch(direction: Vector3, force: float):
	"""Launch the mortar shell in a given direction with specified force"""
	# Apply initial impulse
	initial_velocity = direction.normalized() * force
	apply_central_impulse(initial_velocity)
	
	# Orient the shell to face its velocity direction
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)
	
	# Optional: Apply some spin for realism
	apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 10.0)

func calculate_launch_velocity(target_position: Vector3, launch_angle: float = 45.0) -> Vector3:
	"""Calculate launch velocity needed to hit target position at given angle"""
	var start_pos = global_position
	var displacement = target_position - start_pos
	var horizontal_distance = Vector2(displacement.x, displacement.z).length()
	var vertical_distance = displacement.y
	
	# Physics calculation for projectile motion
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var angle_rad = deg_to_rad(launch_angle)
	
	# Calculate initial velocity needed
	var velocity = sqrt((gravity * horizontal_distance * horizontal_distance) / 
		(2.0 * cos(angle_rad) * cos(angle_rad) * 
		(horizontal_distance * tan(angle_rad) - vertical_distance)))
	
	# Calculate launch direction
	var horizontal_dir = Vector3(displacement.x, 0, displacement.z).normalized()
	var launch_dir = (horizontal_dir * cos(angle_rad) + Vector3.UP * sin(angle_rad)).normalized()
	
	return launch_dir * velocity

func _on_body_entered(body):
	if armed and body != self:
		explode()

func explode():
	"""Handle explosion logic"""
	# Get all bodies in explosion radius
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = explosion_radius
	query.transform = Transform3D(Basis(), global_position)
	
	var results = space_state.intersect_shape(query)
	
	# Apply damage and force to nearby objects
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			# Calculate damage falloff based on distance
			var distance = global_position.distance_to(body.global_position)
			var damage_multiplier = 1.0 - (distance / explosion_radius)
			damage_multiplier = clamp(damage_multiplier, 0.0, 1.0)
			body.take_damage(explosion_damage * damage_multiplier)
		
		# Apply explosion force to RigidBody3D objects
		if body is RigidBody3D:
			var force_direction = (body.global_position - global_position).normalized()
			var force_distance = global_position.distance_to(body.global_position)
			var force_multiplier = 1.0 - (force_distance / explosion_radius)
			force_multiplier = clamp(force_multiplier, 0.0, 1.0)
			body.apply_central_impulse(force_direction * explosion_force * force_multiplier)
	
	# Spawn explosion effect
	# if explosion_effect_scene:
	#     var explosion = explosion_effect_scene.instantiate()
	#     get_tree().current_scene.add_child(explosion)
	#     explosion.global_position = global_position
	
	# Camera shake (if you have a camera shake system)
	# CameraShake.shake(0.5, 10.0)
	
	# Play explosion sound
	# AudioManager.play_3d_sound("explosion", global_position)
	
	# Remove the shell
	queue_free()

# Optional: Visual debug for trajectory
func _draw_trajectory_preview(launch_velocity: Vector3, steps: int = 30):
	"""Draw predicted trajectory (for debugging/aiming)"""
	var points = []
	var pos = global_position
	var vel = launch_velocity
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * Vector3.DOWN
	var time_step = 0.1
	
	for i in range(steps):
		points.append(pos)
		vel += gravity * time_step
		pos += vel * time_step
	
	# You would need to implement actual line drawing
	# This is just to show the calculation
	return points
