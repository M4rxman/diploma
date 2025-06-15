# scripts/mortar_shell.gd - FIXED VERSION with proper launching
class_name Mortar_Shell
extends RigidBody3D

@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 100.0
@export var explosion_force: float = 500.0
@export var fuse_time: float = 4.0  # Auto-explode after time
@export var min_arm_time: float = 0.3  # Minimum time before arming

var armed: bool = false
var launched: bool = false
var target_position: Vector3
var launch_start_time: float

func _ready():
	print("Mortar shell created and ready")
	
	# Physics setup for proper ballistics
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	
	# Start arm timer
	launch_start_time = Time.get_time_dict_from_system().values()[0]
	await get_tree().create_timer(min_arm_time).timeout
	armed = true
	print("Mortar shell armed")
	
	# Auto-explode safety timer
	await get_tree().create_timer(fuse_time - min_arm_time).timeout
	if is_inside_tree():
		print("Mortar shell fuse expired, exploding")
		explode()

func launch_at_target(target_pos: Vector3, launch_force: float = 25.0):
	"""Launch mortar shell at target position - FIXED VERSION"""
	print("Mortar shell launching at target: ", target_pos, " with force: ", launch_force)
	
	target_position = target_pos
	launched = true
	
	# Calculate ballistic trajectory
	var to_target = target_pos - global_position
	var horizontal_distance = Vector2(to_target.x, to_target.z).length()
	var height_diff = to_target.y
	
	# Use physics-based trajectory calculation
	var launch_angle = deg_to_rad(45.0)  # 45 degree launch angle
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	
	# Calculate required velocity using ballistic formula
	var horizontal_distance_factor = horizontal_distance / cos(launch_angle)
	var velocity_magnitude = sqrt((gravity * horizontal_distance_factor) / sin(2 * launch_angle))
	
	# Adjust for height difference
	if height_diff != 0:
		var adjusted_angle = atan2(horizontal_distance, abs(height_diff))
		velocity_magnitude *= 1.1  # Slight boost for height differences
	
	# Calculate launch direction
	var horizontal_direction = Vector3(to_target.x, 0, to_target.z).normalized()
	var launch_direction = horizontal_direction * cos(launch_angle) + Vector3.UP * sin(launch_angle)
	
	# Apply launch velocity
	var launch_velocity = launch_direction * velocity_magnitude
	linear_velocity = launch_velocity
	
	# Add some spin for visual effect and stability
	angular_velocity = Vector3(
		randf_range(-2, 2), 
		randf_range(-3, 3), 
		randf_range(-2, 2)
	)
	
	print("Mortar shell launched with velocity: ", linear_velocity)
	print("Expected to hit near: ", target_pos)

func launch(direction: Vector3, force: float):
	"""Legacy launch method for compatibility"""
	print("Mortar shell using legacy launch method")
	
	launched = true
	linear_velocity = direction * force
	angular_velocity = Vector3(
		randf_range(-2, 2), 
		randf_range(-3, 3), 
		randf_range(-2, 2)
	)
	
	print("Legacy launch - velocity: ", linear_velocity)

func _on_body_entered(body):
	"""Handle collision with other bodies"""
	if not armed or not launched:
		print("Mortar shell hit but not armed/launched yet")
		return
		
	if body == self:
		return
		
	print("Mortar shell hit: ", body.name, " - exploding!")
	explode()

func _physics_process(delta):
	"""Monitor shell trajectory"""
	if launched and is_inside_tree():
		# Check if shell is moving too slowly (stuck)
		if linear_velocity.length() < 1.0:
			var current_time = Time.get_time_dict_from_system().values()[0]
			if current_time - launch_start_time > 2.0:  # Been flying for more than 2 seconds
				print("Mortar shell moving too slowly, exploding")
				explode()
		
		# Check if shell has fallen below reasonable height
		if global_position.y < -10:
			print("Mortar shell fell too far, exploding")
			explode()

func explode():
	"""Handle explosion with area damage"""
	if not is_inside_tree():
		return
		
	print("MORTAR EXPLOSION at: ", global_position)
	
	# Find all bodies within explosion radius
	var explosion_pos = global_position
	var space_state = get_world_3d().direct_space_state
	
	# Use sphere query to find nearby objects
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), explosion_pos)
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	
	var results = space_state.intersect_shape(query)
	print("Explosion found ", results.size(), " objects in blast radius")
	
	# Apply damage and force to all found objects
	for result in results:
		var body = result["collider"]
		if body == self:
			continue
			
		var distance = explosion_pos.distance_to(body.global_position)
		var damage_multiplier = 1.0 - (distance / explosion_radius)
		damage_multiplier = clamp(damage_multiplier, 0.1, 1.0)  # Minimum 10% damage
		
		print("Explosion affecting: ", body.name, " at distance: ", distance, " with multiplier: ", damage_multiplier)
		
		# Apply damage
		if body.has_method("take_damage"):
			var damage = explosion_damage * damage_multiplier
			body.take_damage(int(damage))
			print("Explosion damaged ", body.name, " for ", damage, " damage")
		
		# Apply explosion force
		if body is RigidBody3D:
			var force_direction = (body.global_position - explosion_pos)
			if force_direction.length() > 0:
				force_direction = force_direction.normalized()
			else:
				force_direction = Vector3.UP  # Default upward if same position
			
			var force_magnitude = explosion_force * damage_multiplier
			body.apply_central_impulse(force_direction * force_magnitude)
			print("Applied explosion force to ", body.name, ": ", force_direction * force_magnitude)
	
	# Create visual explosion effect
	_create_explosion_effect()
	
	# Remove the shell
	queue_free()

func _create_explosion_effect():
	"""Create visual explosion effect"""
	print("BOOM! Creating explosion effect at: ", global_position)
	
	# Create multiple particle-like effects
	for i in range(15):
		var particle = RigidBody3D.new()
		var mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.1
		sphere_mesh.height = 0.2
		
		# Random explosion colors
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(
			randf_range(0.8, 1.0),  # Red
			randf_range(0.3, 0.8),  # Green  
			randf_range(0.0, 0.3)   # Blue
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
		particle.angular_velocity = Vector3(
			randf_range(-10, 10),
			randf_range(-10, 10),
			randf_range(-10, 10)
		)
		
		# Clean up particles after a few seconds
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = randf_range(2.0, 4.0)
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(func(): if is_instance_valid(particle): particle.queue_free())
		particle.add_child(cleanup_timer)
		cleanup_timer.start()

# Debug functions
func debug_info():
	"""Print debug information about the shell"""
	print("=== MORTAR SHELL DEBUG ===")
	print("Armed: ", armed)
	print("Launched: ", launched)
	print("Position: ", global_position)
	print("Velocity: ", linear_velocity)
	print("Target: ", target_position)
	print("=========================")

func force_explode():
	"""Force explosion (for debugging)"""
	print("DEBUG: Force exploding mortar shell")
	explode()

# Cleanup
func _exit_tree():
	"""Clean up when shell is removed"""
	print("Mortar shell removed from scene")
