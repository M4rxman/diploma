# item/Supplies.gd - Complete unified supplies item
extends RigidBody3D

class_name Supplies

@export var heal_amount: int = 30
@export var ammo_amount: int = 15
@export var pickup_radius: float = 2.5

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
	
	# Auto-destroy after 45 seconds if not picked up
	var timer = Timer.new()
	timer.wait_time = 45.0
	timer.one_shot = true
	timer.timeout.connect(_fade_out_and_destroy)
	add_child(timer)
	timer.start()

func setup_visual():
	"""Create the visual representation of the supplies crate"""
	# Main crate body
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.5)
	
	# Create material - military green crate
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.2)  # Military green
	material.emission = Color(0.1, 0.3, 0.1) * 0.3
	material.emission_energy = 0.4
	material.metallic = 0.1
	material.roughness = 0.8
	
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.name = "MainMesh"
	add_child(mesh_instance)
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = box_shape
	collision.name = "MainCollision"
	add_child(collision)
	
	## Add medical cross symbol (health indicator)
	#create_cross_symbol(Vector3(0, 0.35, 0.51), Vector3(0.3, 0.08, 0.02), Color.RED)
	#create_cross_symbol(Vector3(0, 0.35, 0.51), Vector3(0.08, 0.3, 0.02), Color.RED)
	
	## Add ammo box symbol (ammo indicator)
	#create_ammo_symbol(Vector3(0, 0.35, -0.51))
	
	# Add corner reinforcements for crate look
	create_corner_details()
	
	# Add a glowing outline effect
	create_glow_effect()

func create_cross_symbol(pos: Vector3, size: Vector3, color: Color):
	"""Create a cross symbol for health indication"""
	var cross_mesh = MeshInstance3D.new()
	var cross_box = BoxMesh.new()
	cross_box.size = size
	cross_box.material = StandardMaterial3D.new()
	cross_box.material.albedo_color = color
	cross_box.material.emission = color * 0.5
	cross_mesh.mesh = cross_box
	cross_mesh.position = pos
	cross_mesh.name = "HealthCross"
	add_child(cross_mesh)

func create_ammo_symbol(pos: Vector3):
	"""Create an ammo symbol for ammunition indication"""
	# Create bullet-like shapes
	for i in range(3):
		var bullet_mesh = MeshInstance3D.new()
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.height = 0.15
		cylinder_mesh.top_radius = 0.03
		cylinder_mesh.bottom_radius = 0.03
		cylinder_mesh.material = StandardMaterial3D.new()
		cylinder_mesh.material.albedo_color = Color(0.7, 0.6, 0.1)  # Brass color
		cylinder_mesh.material.metallic = 0.8
		bullet_mesh.mesh = cylinder_mesh
		bullet_mesh.position = pos + Vector3((i - 1) * 0.08, 0, 0)
		bullet_mesh.name = "AmmoBullet" + str(i)
		add_child(bullet_mesh)

func create_corner_details():
	"""Add corner reinforcements to make it look like a supply crate"""
	var corner_positions = [
		Vector3(0.45, 0.25, 0.45), Vector3(-0.45, 0.25, 0.45),
		Vector3(0.45, 0.25, -0.45), Vector3(-0.45, 0.25, -0.45)
	]
	
	for i in range(corner_positions.size()):
		var pos = corner_positions[i]
		var corner = MeshInstance3D.new()
		var corner_mesh = BoxMesh.new()
		corner_mesh.size = Vector3(0.1, 0.5, 0.1)
		corner_mesh.material = StandardMaterial3D.new()
		corner_mesh.material.albedo_color = Color(0.15, 0.4, 0.15)  # Darker green
		corner_mesh.material.metallic = 0.3
		corner.mesh = corner_mesh
		corner.position = pos
		corner.name = "Corner" + str(i)
		add_child(corner)

func create_glow_effect():
	"""Add a subtle glow effect around the crate"""
	var glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.3, 0.8, 0.3)
	glow_light.light_energy = 0.8
	glow_light.omni_range = 4.0
	glow_light.position = Vector3(0, 0.5, 0)
	glow_light.name = "GlowLight"
	add_child(glow_light)

func setup_physics():
	"""Set up physics properties"""
	mass = 2.0  # Heavier than individual items
	gravity_scale = 0.3  # Float more gently
	linear_damp = 3.0  # More stability
	angular_damp = 4.0
	
	# Add some initial random rotation for variety
	angular_velocity = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 0.5)
	)

func setup_pickup_area():
	"""Set up the pickup detection area"""
	pickup_area = Area3D.new()
	pickup_area.name = "PickupArea"
	
	var area_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = pickup_radius
	area_collision.shape = sphere_shape
	area_collision.name = "PickupCollision"
	pickup_area.add_child(area_collision)
	
	add_child(pickup_area)
	
	# Connect signals
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.body_exited.connect(_on_body_exited)

func start_animations():
	"""Start the floating and rotation animations"""
	# Gentle bobbing motion
	bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", position.y + 0.1, 0.2)
	bob_tween.tween_property(self, "position:y", position.y - 0.1, 0.1)
	
	# Gentle rotation for visibility
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(self, "rotation:y", rotation.y + PI * 2, 4.0)

func _on_body_entered(body):
	"""Handle when a body enters pickup range"""
	if body.is_in_group("player"):
		player_in_range = true
		print("Player near supplies crate - press E to pickup")
		# Scale up slightly to indicate interaction availability
		var scale_tween = create_tween()
		scale_tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.2)

func _on_body_exited(body):
	"""Handle when a body exits pickup range"""
	if body.is_in_group("player"):
		player_in_range = false
		# Scale back to normal
		var scale_tween = create_tween()
		scale_tween.tween_property(self, "scale", Vector3.ONE, 0.2)

func _input(event):
	"""Handle pickup input"""
	if event.is_action_pressed("interact") and player_in_range:
		pickup()

func pickup():
	"""Handle the pickup action"""
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
	
	# Give ammo if player needs it
	if player.has_method("add_ammo") and player.get("ammo") and player.get("max_ammo"):
		if player.ammo < player.max_ammo:
			var ammo_needed = player.max_ammo - player.ammo
			ammo_given = min(ammo_amount, ammo_needed)
			player.add_ammo(ammo_given)
	
	# Show pickup message
	var message_parts = []
	if health_given > 0:
		message_parts.append("+" + str(health_given) + " Health")
	if ammo_given > 0:
		message_parts.append("+" + str(ammo_given) + " Ammo")
	
	if message_parts.size() > 0:
		print("Picked up supplies: " + " & ".join(message_parts))
		picked_up.emit(health_given, ammo_given)
		create_pickup_effect()
		queue_free()
	else:
		print("Health and ammo are already full!")

func create_pickup_effect():
	"""Create visual/audio effect when picked up"""
	# Create mixed colored particles for both health and ammo
	for i in range(15):
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
			global_position + random_dir * 3, 1.2)
		tween.parallel().tween_property(particle, "scale", Vector3.ZERO, 1.2)
		tween.parallel().tween_property(particle, "rotation", 
			Vector3(randf() * PI * 2, randf() * PI * 2, randf() * PI * 2), 1.2)
		tween.tween_callback(particle.queue_free)

func _fade_out_and_destroy():
	"""Fade out the item before destroying it"""
	print("Supplies crate expiring...")
	
	# Fade out effect
	var fade_tween = create_tween()
	fade_tween.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 2.0)
	
	# Fade material
	if has_node("MainMesh"):
		var mesh = get_node("MainMesh")
		var material = mesh.mesh.material as StandardMaterial3D
		if material:
			fade_tween.parallel().tween_property(material, "albedo_color", 
				Color(material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, 0.0), 2.0)
	
	fade_tween.tween_callback(queue_free)

# Static method to create supplies at a position
static func create_supplies_at(position: Vector3, parent: Node) -> Supplies:
	"""Static method to easily create supplies at a specific position"""
	var supplies = Supplies.new()
	parent.add_child(supplies)
	supplies.global_position = position
	return supplies

# Interaction method for compatibility
func interact():
	"""Alternative interaction method"""
	pickup()
