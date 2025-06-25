## Mortar_Shell handles projectile behavior, armed state, and explosion effects.
## Inherits RigidBody3D to leverage physics for movement and collisions.
class_name Mortar_Shell
extends RigidBody3D

## Radius within which entities are affected by explosion.
@export var explosion_radius: float = 10.0
## Base damage dealt at center of explosion.
@export var explosion_damage: float = 200.0
## Maximum force applied to rigid bodies from explosion.
@export var explosion_force: float = 500.0
## Time in seconds before shell auto-detonates.
@export var fuse_time: float = 4.0
## Initial launch speed magnitude.
@export var launch_speed: float = 30.0

## Whether shell is armed and will explode on impact.
var armed: bool = false
## Delay before shell becomes armed (seconds).
var arm_delay: float = 0.3
## World position of the intended target.
var target_position: Vector3
## Tracks if shell has been launched.
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


## Legacy launch method for arbitrary direction.
## @param direction: Unit vector direction.
## @param force: Speed magnitude.
func launch(direction: Vector3, force: float):
	"""Legacy launch method for compatibility"""
	has_launched = true
	linear_velocity = direction * force
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	print("Mortar launched with legacy method - Velocity: ", linear_velocity)


## Called on collision with another body.
## Only triggers explosion if armed and launched.
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


## Performs explosion: damage, force, visual effect, then frees shell.
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
			print(
				"Explosion damaged ",
				body.name,
				" for ",
				damage,
				" damage (multiplier: ",
				damage_multiplier,
				")"
			)

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


## Spawns simple particle bodies for visual explosion.
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
			randf_range(0.8, 1.0), randf_range(0.3, 0.8), randf_range(0.0, 0.3)  # Red  # Green  # Blue
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
			randf_range(-10, 10), randf_range(5, 15), randf_range(-10, 10)
		)
		particle.linear_velocity = explosion_velocity

		# Auto-cleanup particles
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 2.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(
			func():
				if is_instance_valid(particle):
					particle.queue_free()
		)
		particle.add_child(cleanup_timer)
		cleanup_timer.start()


## Optional debug hook for trajectory visualization.
func _physics_process(delta):
	"""Debug trajectory"""
	if has_launched and is_inside_tree():
		# Optional: Add trail effect or debug info
		pass
