# item/Supplies.gd - Fixed supplies with automatic pickup and simple box shape
extends RigidBody3D

class_name Supplies

@export var heal_amount: int = 30
@export var ammo_amount: int = 15
@export var pickup_radius: float = 2.0

var player_in_range: bool = false
var pickup_area: Area3D
var bob_tween: Tween

signal picked_up(heal_amount: int, ammo_amount: int)

func _ready():
	setup_visual()
	setup_physics()
	setup_pickup_area()
	start_animations()
	
	# Add to supplies group for UI tracking
	add_to_group("supplies")
	
	# Auto-destroy after 30 seconds if not picked up
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.one_shot = true
	timer.timeout.connect(_fade_out_and_destroy)
	add_child(timer)
	timer.start()

func setup_visual():
	"""Create a simple rotating box visual"""
	# Main supply box
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 0.8, 0.8)  # Smaller box
	
	# Create material - bright green supply box
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 0.2)  # Bright green
	material.emission = Color(0.1, 0.4, 0.1) * 0.5
	material.emission_energy = 0.6
	material.metallic = 0.2
	material.roughness = 0.6
	
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.name = "MainMesh"
	add_child(mesh_instance)
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.8, 0.8)
	collision.shape = box_shape
	collision.name = "MainCollision"
	add_child(collision)
	
	# Add a simple glowing outline effect
	create_glow_effect()

func create_glow_effect():
	"""Add a subtle glow effect around the supply box"""
	var glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.3, 0.8, 0.3)
	glow_light.light_energy = 1.2
	glow_light.omni_range = 3.0
	glow_light.position = Vector3(0, 0.2, 0)
	glow_light.name = "GlowLight"
	add_child(glow_light)

func setup_physics():
	"""Set up physics properties for ground-level spawning"""
	mass = 1.5
	gravity_scale = 1.0  # Normal gravity to fall to ground
	linear_damp = 2.0
	angular_damp = 1.0  # Allow some rotation
	
	# Set collision layers
	collision_layer = 4  # Supplies layer
	collision_mask = 1   # Collide with ground and walls
	
	# Small initial random rotation for variety
	angular_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-2.0, 2.0),
		randf_range(-1.0, 1.0)
	)

func setup_pickup_area():
	"""Set up the automatic pickup detection area"""
	pickup_area = Area3D.new()
	pickup_area.name = "PickupArea"
	
	# Set collision layers for pickup detection
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 2  # Player layer
	
	var area_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = pickup_radius
	area_collision.shape = sphere_shape
	area_collision.name = "PickupCollision"
	pickup_area.add_child(area_collision)
	
	add_child(pickup_area)
	
	# Connect signals for automatic pickup
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.body_exited.connect(_on_body_exited)

func start_animations():
	"""Start the gentle rotation animation"""
	# Continuous gentle rotation around Y axis
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(self, "rotation:y", rotation.y + PI * 2, 3.0)

func _on_body_entered(body):
	"""Handle when a body enters pickup range - automatic pickup"""
	if body.is_in_group("player"):
		player_in_range = true
		print("Player entered supply range - auto-picking up...")
		
		# Immediate automatic pickup
		pickup()

func _on_body_exited(body):
	"""Handle when a body exits pickup range"""
	if body.is_in_group("player"):
		player_in_range = false

func pickup():
	"""Handle the automatic pickup action"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var health_given = 0
	var ammo_given = 0
	
	# Give health if player needs it
	if player.has_method("heal") and player.get("health") and player.get("max_health"):
		if player.health < player.max_health:
			var health_needed = player.max_health - player.health
			health_given = min(heal_amount, health_needed)
			player.heal(health_given)
	elif player.get("health") and player.get("max_health"):
		# Direct health assignment if no heal method
		if player.health < player.max_health:
			var health_needed = player.max_health - player.health
			health_given = min(heal_amount, health_needed)
			player.health = min(player.max_health, player.health + health_given)
	
	# Give ammo if player needs it
	if player.has_method("add_ammo") and player.get("ammo") and player.get("max_ammo"):
		if player.ammo < player.max_ammo:
			var ammo_needed = player.max_ammo - player.ammo
			ammo_given = min(ammo_amount, ammo_needed)
			player.add_ammo(ammo_given)
	elif player.get("ammo") and player.get("max_ammo"):
		# Direct ammo assignment if no add_ammo method
		if player.ammo < player.max_ammo:
			var ammo_needed = player.max_ammo - player.ammo
			ammo_given = min(ammo_amount, ammo_needed)
			player.ammo = min(player.max_ammo, player.ammo + ammo_given)
	
	# Show pickup message
	var message_parts = []
	if health_given > 0:
		message_parts.append("+" + str(health_given) + " Health")
	if ammo_given > 0:
		message_parts.append("+" + str(ammo_given) + " Ammo")
	
	if message_parts.size() > 0:
		print("Auto-picked up supplies: " + " & ".join(message_parts))
		picked_up.emit(health_given, ammo_given)
		create_pickup_effect()
		queue_free()
	else:
		print("Health and ammo are already full - supplies not needed!")

func create_pickup_effect():
	"""Create visual effect when picked up"""
	# Create mixed colored particles for both health and ammo
	for i in range(10):
		var particle = MeshInstance3D.new()
		var cube = BoxMesh.new()
		cube.size = Vector3(0.1, 0.1, 0.1)
		cube.material = StandardMaterial3D.new()
		
		# Alternate between health (green) and ammo (yellow) colored particles
		if i % 2 == 0:
			cube.material.albedo_color = Color.GREEN  # Health color
		else:
			cube.material.albedo_color = Color.YELLOW  # Ammo color
		
		particle.mesh = cube
		
		get_parent().add_child(particle)
		particle.global_position = global_position + Vector3(0, 0.5, 0)
		
		# Animate particles in a burst pattern
		var tween = create_tween()
		var random_dir = Vector3(
			randf_range(-1, 1), 
			randf_range(0.5, 2), 
			randf_range(-1, 1)
		).normalized()
		
		tween.parallel().tween_property(particle, "global_position", 
			global_position + random_dir * 2, 1.0)
		tween.parallel().tween_property(particle, "scale", Vector3.ZERO, 1.0)
		tween.parallel().tween_property(particle, "rotation", 
			Vector3(randf() * PI * 2, randf() * PI * 2, randf() * PI * 2), 1.0)
		tween.tween_callback(particle.queue_free)

func _fade_out_and_destroy():
	"""Fade out the item before destroying it"""
	print("Supplies expiring...")
	
	# Fade out effect
	var fade_tween = create_tween()
	fade_tween.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 1.5)
	
	# Fade material
	if has_node("MainMesh"):
		var mesh = get_node("MainMesh")
		var material = mesh.mesh.material as StandardMaterial3D
		if material:
			fade_tween.parallel().tween_property(material, "albedo_color", 
				Color(material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, 0.0), 1.5)
	
	fade_tween.tween_callback(queue_free)

# Static method to create supplies at a position (improved for ground spawning)
static func create_supplies_at(position: Vector3, parent: Node) -> Supplies:
	"""Static method to easily create supplies at ground level"""
	var supplies = Supplies.new()
	parent.add_child(supplies)
	
	# Spawn slightly above ground level to allow physics to settle
	var spawn_pos = position
	spawn_pos.y = max(spawn_pos.y, 2.0)  # Ensure minimum height of 2 units
	supplies.global_position = spawn_pos
	
	print("Supplies created at: ", spawn_pos)
	return supplies

# Interaction method for compatibility (now automatic)
func interact():
	"""Legacy interaction method - now handled automatically"""
	pickup()
