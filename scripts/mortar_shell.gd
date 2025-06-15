# scripts/mortar_shell.gd - Improved targeting and physics
class_name Mortar_Shell
extends RigidBody3D

@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 100.0
@export var explosion_force: float = 500.0
@export var fuse_time: float = 4.0  # Increased fuse time
@export var launch_speed: float = 25.0

var armed: bool = false
var arm_delay: float = 0.3
var target_position: Vector3
var has_launched: bool = false

func _ready():
	# Physics setup
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	print("Mortar shell created")
	
	# Arm after delay
	await get_tree().create_timer(arm_delay).timeout
	armed = true
	print("Mortar shell armed")
	
	# Auto-explode after fuse time
	await get_tree().create_timer(fuse_time).timeout
	if is_inside_tree():
		print("Mortar shell fuse expired, exploding")
		explode()

func launch_at_target(target_pos: Vector3, force: float = 25.0):
	"""Launch mortar shell at target position using ballistic trajectory"""
	target_position = target_pos
	has_launched = true
	
	print("Launching mortar at target: ", target_pos, " from: ", global_position)
	
	# Calculate ballistic trajectory
	var to_target = target_pos - global_position
	var horizontal_distance = Vector2(to_target.x, to_target.z).length()
	var height_diff = to_target.y
	
	# Use 45-degree launch angle for good arc
	var launch_angle = deg_to_rad(45.0)
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	
	print("Horizontal distance: ", horizontal_distance, " Height diff: ", height_diff)
	
	# Calculate required velocity for ballistic trajectory
	var velocity_magnitude = sqrt((gravity * horizontal_distance) / sin(2 * launch_angle))
	
	# Adjust for height difference
	if height_diff != 0:
		velocity_magnitude *= 1.1  # Slight boost for height differences
	
	# Calculate launch direction
	var horizontal_direction = Vector3(to_target.x, 0, to_target.z).normalized()
	var launch_direction = horizontal_direction * cos(launch_angle) + Vector3.UP * sin(launch_angle)
	
	# Apply launch velocity
	linear_velocity = launch_direction * velocity_magnitude
	
	# Add some spin for visual effect
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))
	
	print("Launch velocity: ", linear_velocity, " (magnitude: ", velocity_magnitude, ")")

func launch(direction: Vector3, force: float):
	"""Legacy launch method for compatibility"""
	has_launched = true
	linear_velocity = direction * force
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	print("Mortar launched with legacy method - Velocity: ", linear_velocity)

func _on_body_entered(body):
	"""Handle collision with other bodies"""
	if not armed or not has_launched:
		return
		
	if body == self:
		return
	
	# Don't explode on the player who fired it immediately
	if body.is_in_group("player"):
		# Only explode if shell has been flying for a bit
		if get_physics_process_delta_time() * Engine.get_process_frames() < 1.0:
			return
		
	print("Mortar shell hit: ", body.name, " - exploding")
	explode()

func explode():
	"""Handle explosion"""
	if not is_inside_tree():
		return
		
	print("Mortar shell exploding at: ", global_position)
	
	# Find all bodies within explosion radius
	var explosion_pos = global_position
	var space_state = get_world_3d().direct_space_state
	
	# Use area query to find nearby objects
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), explosion_pos)
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	
	var results = space_state.intersect_shape(query)
	
	print("Explosion found ", results.size(), " potential targets")
	
	# Apply damage and force to all found objects
	for result in results:
		var body = result["collider"]
		if body == self:
			continue
			
		var distance = explosion_pos.distance_to(body.global_position)
		var damage_multiplier = 1.0 - (distance / explosion_radius)
		damage_multiplier = clamp(damage_multiplier, 0.0, 1.0)
		
		# Apply damage
		if body.has_method("take_damage"):
			var damage = explosion_damage * damage_multiplier
			body.take_damage(int(damage))
			print("Explosion damaged ", body.name, " for ", damage, " damage (multiplier: ", damage_multiplier, ")")
		
		# Apply explosion force
		if body is RigidBody3D:
			var force_direction = (body.global_position - explosion_pos).normalized()
			if force_direction.length() == 0:
				force_direction = Vector3.UP  # If exactly on top, push upward
			var force_magnitude = explosion_force * damage_multiplier
			body.apply_central_impulse(force_direction * force_magnitude)
			print("Applied explosion force to ", body.name, ": ", force_direction * force_magnitude)
	
	# Create visual explosion effect
	_create_explosion_effect()
	
	# Remove the shell
	queue_free()

func _create_explosion_effect():
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

func _physics_process(delta):
	"""Debug trajectory"""
	if has_launched and is_inside_tree():
		# Optional: Add trail effect or debug info
		pass
