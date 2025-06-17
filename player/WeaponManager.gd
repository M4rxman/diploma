# player/WeaponManager.gd - Updated with visual effects and proper weapon tracking
extends Node3D

enum WeaponType {
	SWORD,
	PISTOL,
	SHOTGUN,
	MORTAR
}

const WEAPON_STATS = {
	WeaponType.SWORD: {
		"damage": 80,
		"range": 2.0,
		"cooldown": 1.0,
		"knockback": 50.0,
		"color": Color(0, 1, 0),
		"name": "Sword"
	},
	WeaponType.PISTOL: {
		"damage": 25,
		"range": 50.0,
		"cooldown": 0.3,
		"knockback": 10.0,
		"color": Color(1, 1, 0),
		"name": "Pistol"
	},
	WeaponType.SHOTGUN: {
		"damage": 60,
		"range": 20.0,
		"cooldown": 0.8,
		"pellets": 5,
		"spread": 15.0,
		"knockback": 8.0,
		"color": Color(1, 0.5, 0),
		"name": "Shotgun"
	},
	WeaponType.MORTAR: {
		"damage": 200,
		"range": 50.0,
		"cooldown": 2.0,
		"color": Color(1, 0, 0),
		"name": "Mortar"
	}
}

@export var mortar_shell_scene: PackedScene

@onready var sword_hitbox: Area3D = $SwordHitbox
@onready var hitscan_raycast: RayCast3D = $HitscanRaycast
@onready var muzzle_flash: GPUParticles3D = $MuzzleFlash

var current_weapon: WeaponType = WeaponType.PISTOL
var can_fire: bool = true
var owner_body: RigidBody3D
var mesh_instance: MeshInstance3D 


signal weapon_changed(weapon_type: WeaponType)
signal weapon_fired

func _ready():
	owner_body = get_parent()
	mesh_instance = owner_body.get_node("MeshInstance3D")
	
	if sword_hitbox:
		sword_hitbox.body_entered.connect(_on_sword_hit)
		sword_hitbox.monitoring = false
	
	if hitscan_raycast:
		hitscan_raycast.target_position = Vector3(0, 0, -50.0)
		hitscan_raycast.enabled = true
		hitscan_raycast.collision_mask = 0xFFFFFFFF
	
	# Setup muzzle flash if it exists
	if muzzle_flash:
		_setup_muzzle_flash()
	
	switch_weapon(WeaponType.SWORD)

func _setup_muzzle_flash():
	"""Setup the muzzle flash particle system"""
	if not muzzle_flash:
		return
		
	muzzle_flash.emitting = false
	muzzle_flash.amount = 8
	muzzle_flash.lifetime = 0.1
	muzzle_flash.one_shot = true
	
	# Create process material if it doesn't exist
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 0, -1)
	process_mat.initial_velocity_min = 5.0
	process_mat.initial_velocity_max = 10.0
	process_mat.angular_velocity_min = -180.0
	process_mat.angular_velocity_max = 180.0
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.3
	process_mat.color = Color(1, 0.8, 0, 1)
	muzzle_flash.process_material = process_mat
	
	# Create draw pass material
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radial_segments = 4
	sphere_mesh.height = 0.1
	sphere_mesh.radius = 0.05
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.9, 0.3)
	material.emission_enabled = true
	material.emission = Color(1, 0.8, 0)
	material.emission_energy = 3.0
	sphere_mesh.material = material
	
	muzzle_flash.draw_pass_1 = sphere_mesh

func _input(event):
	if event.is_action_pressed("weapon_1"):
		switch_weapon(WeaponType.SWORD)
	elif event.is_action_pressed("weapon_2"):
		switch_weapon(WeaponType.PISTOL)
	elif event.is_action_pressed("weapon_3"):
		switch_weapon(WeaponType.SHOTGUN)
	elif event.is_action_pressed("weapon_4"):
		switch_weapon(WeaponType.MORTAR)

func switch_weapon(weapon_type: WeaponType):
	current_weapon = weapon_type
	var stats = WEAPON_STATS[current_weapon]
	
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.set_shader_parameter("base_color", stats["color"])
	
	print("Switched to: ", stats["name"])
	weapon_changed.emit(current_weapon)

func get_current_weapon_name() -> String:
	"""Get the name of the current weapon for ammo checking"""
	return WEAPON_STATS[current_weapon]["name"].to_upper()

func get_current_weapon_color() -> Color:
	"""Get the color of the current weapon"""
	return WEAPON_STATS[current_weapon]["color"]

func fire():
	if not can_fire:
		return
		
	match current_weapon:
		WeaponType.SWORD:
			_fire_sword()
		WeaponType.PISTOL:
			_fire_pistol()
		WeaponType.SHOTGUN:
			_fire_shotgun()
		WeaponType.MORTAR:
			_fire_mortar()
	
	can_fire = false
	weapon_fired.emit()
	
	await get_tree().create_timer(WEAPON_STATS[current_weapon]["cooldown"]).timeout
	can_fire = true

func _fire_sword():
	if not sword_hitbox:
		return
	
	var wall_check = _check_for_wall_in_front(WEAPON_STATS[WeaponType.SWORD]["range"])
	if wall_check:
		print("Sword blocked by wall")
		return
	
	print("Firing sword!")
	sword_hitbox.monitoring = true

	# Thrust effect
	var tween = create_tween()
	var thrust_direction = -owner_body.transform.basis.z * 0.3
	tween.tween_property(owner_body, "position", owner_body.position + thrust_direction, 0.1)
	tween.tween_property(owner_body, "position", owner_body.position, 0.1)
	
	_create_sword_swing_effect()
	
	await get_tree().create_timer(0.2).timeout
	sword_hitbox.monitoring = false
	

func _create_sword_swing_effect():
	"""Create a visual effect for sword swing"""
	var swing_effect = MeshInstance3D.new()
	var arc_mesh = TorusMesh.new()
	arc_mesh.set_ring_segments(16)
	arc_mesh.inner_radius = 1.5
	arc_mesh.outer_radius = 2.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 0, 0.5)
	material.emission_enabled = true
	material.emission = Color(0, 1, 0)
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_mesh.material = material
	
	swing_effect.mesh = arc_mesh
	owner_body.add_child(swing_effect)
	swing_effect.position = Vector3(0, 0, -1)
	swing_effect.rotation.x = deg_to_rad(90)
	
	# Animate the swing
	var tween = create_tween()
	tween.parallel().tween_property(swing_effect, "scale", Vector3(1.5, 1.5, 1.5), 0.3)
	tween.parallel().tween_property(material, "albedo_color", Color(0, 1, 0, 0), 0.3)
	tween.tween_callback(swing_effect.queue_free)

func _check_for_wall_in_front(range: float) -> bool:
	var space_state = owner_body.get_world_3d().direct_space_state
	var start_pos = owner_body.global_position + Vector3(0, 0.5, 0)
	var end_pos = start_pos + (-owner_body.transform.basis.z * range)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [owner_body]
	query.collision_mask = 1  # Only check static bodies/walls
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _on_sword_hit(body):
	print("Sword hit: ", body.name)
	
	if body.has_method("take_damage"):
		body.take_damage(WEAPON_STATS[WeaponType.SWORD]["damage"])
		print("Sword dealt ", WEAPON_STATS[WeaponType.SWORD]["damage"], " damage to ", body.name)
		_create_hit_effect(body.global_position, Color.RED)
	
	if body is RigidBody3D:
		var knockback_dir = (body.global_position - owner_body.global_position).normalized()
		body.apply_central_impulse(knockback_dir * WEAPON_STATS[WeaponType.SWORD]["knockback"])


func _fire_pistol():
	if not hitscan_raycast:
		return
	
	print("Firing pistol!")
	
	# Show muzzle flash
	_show_muzzle_flash(Color.YELLOW)
	
	var target = _find_best_target()
	if target:
		_aim_raycast_at_target(target)
	else:
		hitscan_raycast.rotation = Vector3.ZERO
	
	hitscan_raycast.force_raycast_update()
	
	if hitscan_raycast.is_colliding():
		var hit_body = hitscan_raycast.get_collider()
		print("Pistol hit: ", hit_body.name)
		
		if hit_body.has_method("take_damage"):
			hit_body.take_damage(WEAPON_STATS[WeaponType.PISTOL]["damage"])
			print("Pistol dealt ", WEAPON_STATS[WeaponType.PISTOL]["damage"], " damage to ", hit_body.name)
			
			# Small knockback
			if hit_body is RigidBody3D:
				var knockback_dir = (hit_body.global_position - owner_body.global_position).normalized()
				hit_body.apply_central_impulse(knockback_dir * WEAPON_STATS[WeaponType.PISTOL]["knockback"])
		
		var hit_point = hitscan_raycast.get_collision_point()
		_create_hit_effect(hit_point, Color.YELLOW)
		print("Hit at: ", hit_point)
	else:
		print("Pistol missed")

func _fire_shotgun():
	var stats = WEAPON_STATS[WeaponType.SHOTGUN]
	var spread_angle = deg_to_rad(stats["spread"])
	var pellet_count = stats["pellets"]

	print("Shotgun firing ", pellet_count, " pellets with ", stats["damage"], " damage each")

	_show_muzzle_flash(Color.ORANGE, true)

	for i in range(pellet_count):
		var start_pos = owner_body.global_position + Vector3(0, 0.5, 0)

		# Spread direction
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)

		var forward = -owner_body.transform.basis.z
		var right = owner_body.transform.basis.x
		var up = owner_body.transform.basis.y

		var spread_direction = (forward + right * sin(spread_x) + up * sin(spread_y)).normalized()
		var current_start = start_pos
		var max_range = stats["range"]
		var remaining_distance = max_range
		var already_hit: Array = []

		while remaining_distance > 0:
			var end_pos = current_start + spread_direction * remaining_distance

			var query = PhysicsRayQueryParameters3D.create(current_start, end_pos)
			query.exclude = [owner_body] + already_hit
			query.collision_mask = 0xFFFFFFFF

			var result = owner_body.get_world_3d().direct_space_state.intersect_ray(query)

			if result.is_empty():
				break  # No more hits along this path

			var hit_position = result.position
			var hit_body = result.collider

			if is_instance_valid(hit_body):
				if already_hit.has(hit_body):
					break  # Already hit this target, stop
				already_hit.append(hit_body)

				if hit_body.has_method("take_damage"):
					hit_body.take_damage(stats["damage"])
					print("Shotgun pellet pierced: ", hit_body.name)

					if hit_body is RigidBody3D:
						var knockback_dir = (hit_body.global_position - owner_body.global_position).normalized()
						hit_body.apply_central_impulse(knockback_dir * stats["knockback"])

					_create_hit_effect(hit_position, Color.ORANGE, 0.5)

			# Move start point forward to continue pierce
			var distance_to_hit = current_start.distance_to(hit_position)
			remaining_distance -= distance_to_hit
			current_start = hit_position + spread_direction * 0.1  # Slight offset to avoid self-collision


func _fire_mortar():
	print("Firing mortar!")
	# Show muzzle flash
	_show_muzzle_flash(Color.RED, true, true)  # Big red flash for mortar
	
	if owner_body.has_method("_fire_mortar_at_cursor"):
		owner_body._fire_mortar_at_cursor()

func _show_muzzle_flash(color: Color, big: bool = false, extra_big: bool = false):
	"""Show muzzle flash effect"""
	if muzzle_flash:
		var process_mat = muzzle_flash.process_material as ParticleProcessMaterial
		if process_mat:
			process_mat.color = color
			if big:
				process_mat.scale_min = 0.2
				process_mat.scale_max = 0.4
			elif extra_big:
				process_mat.scale_min = 0.3
				process_mat.scale_max = 0.6
			else:
				process_mat.scale_min = 0.1
				process_mat.scale_max = 0.3
		
		muzzle_flash.restart()
		muzzle_flash.emitting = true
	
	# Also create a light flash
	var flash_light = OmniLight3D.new()
	flash_light.light_color = color
	flash_light.light_energy = 3.0 if extra_big else (2.0 if big else 1.5)
	flash_light.omni_range = 5.0
	owner_body.add_child(flash_light)
	flash_light.position = Vector3(0, 0, -0.5)
	
	# Fade out the light
	var tween = create_tween()
	tween.tween_property(flash_light, "light_energy", 0.0, 0.2)
	tween.tween_callback(flash_light.queue_free)

func _create_hit_effect(position: Vector3, color: Color = Color.WHITE, scale: float = 1.0):
	"""Create a hit effect at the specified position"""
	# Create particles
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.one_shot = true
	
	# Setup process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.angular_velocity_min = -180.0
	process_mat.angular_velocity_max = 180.0
	process_mat.scale_min = 0.05 * scale
	process_mat.scale_max = 0.15 * scale
	process_mat.color = color
	particles.process_material = process_mat
	
	# Create mesh
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(0.1, 0.1, 0.1)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy = 2.0
	cube_mesh.material = material
	
	particles.draw_pass_1 = cube_mesh
	
	# Clean up after lifetime
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _find_best_target() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var best_distance = INF
	var max_angle = deg_to_rad(60)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = owner_body.global_position.distance_to(enemy.global_position)
		var to_enemy = (enemy.global_position - owner_body.global_position).normalized()
		var forward = -owner_body.transform.basis.z
		var angle = forward.angle_to(to_enemy)
		
		if angle < max_angle and distance < best_distance:
			# Check if there's a clear line of sight
			var space_state = owner_body.get_world_3d().direct_space_state
			var start_pos = owner_body.global_position + Vector3(0, 0.5, 0)
			var end_pos = enemy.global_position + Vector3(0, 0.5, 0)
			
			var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
			query.exclude = [owner_body, enemy]
			query.collision_mask = 1  # Only check walls/static bodies
			
			var wall_check = space_state.intersect_ray(query)
			
			if wall_check.is_empty():  # Clear line of sight
				best_distance = distance
				best_target = enemy
	
	return best_target

func _aim_raycast_at_target(target: Node3D):
	if not hitscan_raycast:
		return
		
	var to_target = target.global_position - owner_body.global_position
	to_target.y = 0  # Keep it horizontal like classic Doom
	
	if to_target.length() > 0:
		var look_direction = to_target.normalized()
		hitscan_raycast.look_at(hitscan_raycast.global_position + look_direction, Vector3.UP)
