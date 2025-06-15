# scripts/mortar_shell.gd - Completely rewritten
class_name Mortar_Shell
extends RigidBody3D

@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 100.0
@export var explosion_force: float = 500.0
@export var fuse_time: float = 3.0  # Auto-explode after time

var armed: bool = false
var arm_delay: float = 0.2
var target_position: Vector3

func _ready():
	# Physics setup
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 5
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Arm after delay
	await get_tree().create_timer(arm_delay).timeout
	armed = true
	
	# Auto-explode after fuse time
	await get_tree().create_timer(fuse_time).timeout
	if is_inside_tree():
		explode()

func launch_at_target(target_pos: Vector3, launch_force: float = 25.0):
	"""Launch mortar shell at target position"""
	target_position = target_pos
	
	# Calculate simple arc trajectory
	var to_target = target_pos - global_position
	var horizontal_distance = Vector2(to_target.x, to_target.z).length()
	var height_diff = to_target.y
	
	# Simple parabolic trajectory calculation
	var launch_angle = deg_to_rad(45.0)  # 45 degree launch angle
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	
	# Calculate required velocity
	var velocity_magnitude = sqrt(gravity * horizontal_distance / sin(2 * launch_angle))
	
	# Calculate launch direction
	var horizontal_direction = Vector3(to_target.x, 0, to_target.z).normalized()
	var launch_direction = horizontal_direction * cos(launch_angle) + Vector3.UP * sin(launch_angle)
	
	# Apply launch velocity
	linear_velocity = launch_direction * velocity_magnitude
	
	# Add some spin for visual effect
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	
	print("Mortar launched to: ", target_pos, " with velocity: ", linear_velocity)

func _on_body_entered(body):
	"""Handle collision with other bodies"""
	if not armed:
		return
		
	if body == self:
		return
		
	print("Mortar shell hit: ", body.name)
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
			print("Explosion damaged ", body.name, " for ", damage, " damage")
		
		# Apply explosion force
		if body is RigidBody3D:
			var force_direction = (body.global_position - explosion_pos).normalized()
			var force_magnitude = explosion_force * damage_multiplier
			body.apply_central_impulse(force_direction * force_magnitude)
	
	# Create visual explosion effect (simple)
	_create_explosion_effect()
	
	# Remove the shell
	queue_free()

func _create_explosion_effect():
	"""Create simple explosion visual effect"""
	# You can add particle effects here later
	print("BOOM! Explosion at: ", global_position)
	
	# For now, just a simple flash effect could be added
