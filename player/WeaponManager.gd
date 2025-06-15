# player/WeaponManager.gd
extends Node3D

# Weapon types enum
enum WeaponType {
	SWORD,
	PISTOL,
	SHOTGUN,
	MORTAR
}

# Weapon stats
const WEAPON_STATS = {
	WeaponType.SWORD: {
		"damage": 50,
		"range": 3.0,
		"cooldown": 0.5,
		"knockback": 10.0,
		"recoil": 0.0,
		"color": Color(0, 1, 0),  # Green
		"name": "Sword"
	},
	WeaponType.PISTOL: {
		"damage": 25,
		"range": 50.0,
		"cooldown": 0.3,
		"recoil": 5.0,  # Recoil force
		"color": Color(1, 1, 0),  # Yellow
		"name": "Pistol"
	},
	WeaponType.SHOTGUN: {
		"damage": 15,  # Per pellet
		"range": 20.0,
		"cooldown": 0.8,
		"spread": 15.0,  # Degrees
		"pellets": 5,
		"recoil": 12.0,  # Higher recoil
		"color": Color(1, 0.5, 0),  # Orange
		"name": "Shotgun"
	},
	WeaponType.MORTAR: {
		"damage": 100,  # Set in mortar shell
		"range": 80.0,
		"cooldown": 2.0,
		"recoil": 8.0,
		"color": Color(1, 0, 0),  # Red
		"name": "Mortar"
	}
}

@export var mortar_shell_scene: PackedScene
@export var game_manager = "res://scenes/Main_scene.tscn"

@onready var sword_hitbox: Area3D = $SwordHitbox
@onready var hitscan_raycast: RayCast3D = $HitscanRaycast

var current_weapon: WeaponType = WeaponType.PISTOL
var can_fire: bool = true
var owner_body: RigidBody3D
var mesh_instance: MeshInstance3D 

# Recoil system
var recoil_recovery_speed: float = 10.0
var current_recoil: Vector3 = Vector3.ZERO

signal weapon_changed(weapon_type: WeaponType)
signal weapon_fired

func _ready():
	owner_body = get_parent()
	mesh_instance = owner_body.get_node("MeshInstance3D")
	
	# Setup sword hitbox
	sword_hitbox.body_entered.connect(_on_sword_hit)
	sword_hitbox.monitoring = false
	
	# Setup raycasts
	hitscan_raycast.target_position = Vector3(0, 0, -WEAPON_STATS[WeaponType.PISTOL]["range"])
	
	# Set initial weapon
	switch_weapon(WeaponType.PISTOL)

func _physics_process(delta: float):
	# Apply recoil recovery
	if current_recoil.length() > 0.1:
		current_recoil = current_recoil.move_toward(Vector3.ZERO, recoil_recovery_speed * delta)
		
		# Apply recoil to player (subtle camera shake effect)
		if owner_body:
			owner_body.apply_central_impulse(current_recoil * delta * 0.1)

func _input(event):
	# Weapon switching
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
	
	# Update character color
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.set_shader_parameter("base_color", stats["color"])
	
	print("Switched to: ", stats["name"])
	weapon_changed.emit(current_weapon)

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
	
	# Apply recoil
	_apply_recoil()
	
	can_fire = false
	weapon_fired.emit()
	
	# Cooldown
	await get_tree().create_timer(WEAPON_STATS[current_weapon]["cooldown"]).timeout
	can_fire = true

func _apply_recoil():
	"""Apply weapon recoil"""
	var stats = WEAPON_STATS[current_weapon]
	var recoil_force = stats.get("recoil", 0.0)
	
	if recoil_force > 0 and owner_body:
		# Calculate recoil direction (opposite to facing direction)
		var recoil_direction = owner_body.transform.basis.z  # Forward is -z, so z is backward
		recoil_direction.y = 0  # Keep horizontal
		recoil_direction = recoil_direction.normalized()
		
		# Add some random spread to recoil
		var spread = deg_to_rad(5.0)  # 5 degrees spread
		recoil_direction = recoil_direction.rotated(Vector3.UP, randf_range(-spread, spread))
		
		# Apply recoil impulse
		var recoil_impulse = recoil_direction * recoil_force
		owner_body.apply_central_impulse(recoil_impulse)
		
		# Store recoil for gradual recovery
		current_recoil = recoil_impulse
		
		print("Applied recoil: ", recoil_force, " force")

func _fire_sword():
	sword_hitbox.monitoring = true
	
	# Visual feedback - quick forward thrust
	var tween = create_tween()
	var thrust_direction = -owner_body.transform.basis.z * 0.5
	tween.tween_property(owner_body, "position", owner_body.position + thrust_direction, 0.1)
	tween.tween_property(owner_body, "position", owner_body.position, 0.1)
	
	await get_tree().create_timer(0.1).timeout
	sword_hitbox.monitoring = false

func _on_sword_hit(body):
	if body.has_method("take_damage"):
		body.take_damage(WEAPON_STATS[WeaponType.SWORD]["damage"])
	
	# Apply knockback
	if body is RigidBody3D:
		var knockback_dir = (body.global_position - owner_body.global_position).normalized()
		body.apply_central_impulse(knockback_dir * WEAPON_STATS[WeaponType.SWORD]["knockback"])

func _fire_pistol():
	var target = _find_best_target()
	
	if target:
		_aim_at_target(hitscan_raycast, target)
	else:
		# Shoot straight ahead
		hitscan_raycast.rotation = Vector3.ZERO
	
	hitscan_raycast.force_raycast_update()
	
	if hitscan_raycast.is_colliding():
		var hit = hitscan_raycast.get_collider()
		if hit.has_method("take_damage"):
			hit.take_damage(WEAPON_STATS[WeaponType.PISTOL]["damage"])
		
		# Visual feedback at hit point
		_create_hit_effect(hitscan_raycast.get_collision_point())

func _fire_shotgun():
	# Similar to pistol but with multiple rays
	var stats = WEAPON_STATS[WeaponType.SHOTGUN]
	var spread = deg_to_rad(stats["spread"])
	var target = _find_best_target()
	
	# Fire multiple pellets
	for i in range(stats["pellets"]):
		# Apply spread
		var spread_x = randf_range(-spread, spread)
		var spread_y = randf_range(-spread, spread)
		
		var temp_raycast = RayCast3D.new()
		add_child(temp_raycast)
		temp_raycast.target_position = Vector3(0, 0, -stats["range"])
		
		if target:
			_aim_at_target(temp_raycast, target)
			temp_raycast.rotation.x += spread_x
			temp_raycast.rotation.y += spread_y
		else:
			temp_raycast.rotation = Vector3(spread_x, spread_y, 0)
		
		temp_raycast.force_raycast_update()
		
		if temp_raycast.is_colliding():
			var hit = temp_raycast.get_collider()
			if hit.has_method("take_damage"):
				hit.take_damage(stats["damage"])
			
			_create_hit_effect(temp_raycast.get_collision_point())
		
		temp_raycast.queue_free()

func _fire_mortar():
	if not mortar_shell_scene:
		print("Mortar shell scene not assigned!")
		return
	
	# Use existing mortar code from character.gd
	if owner_body.has_method("_fire_mortar_at_cursor"):
		owner_body._fire_mortar_at_cursor()

func _find_best_target() -> Node3D:
	# Find enemies in range
	var enemies = GameManagerGlobal.get_targets()
	
	var best_target = null
	var best_distance = INF
	var max_angle = deg_to_rad(45)  # Maximum angle to consider a target
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = owner_body.global_position.distance_to(enemy.global_position)
		var to_enemy = (enemy.global_position - owner_body.global_position).normalized()
		var forward = -owner_body.transform.basis.z
		var angle = forward.angle_to(to_enemy)
		
		# Check if enemy is in front and within angle threshold
		if angle < max_angle and distance < best_distance:
			best_distance = distance
			best_target = enemy
	
	return best_target

func _aim_at_target(raycast: RayCast3D, target: Node3D):
	# Aim at target but keep Y level (Doom-style)
	var to_target = target.global_position - owner_body.global_position
	to_target.y = 0  # Ignore Y difference
	
	if to_target.length() > 0:
		raycast.look_at(raycast.global_position + to_target, Vector3.UP)

func _create_hit_effect(position: Vector3):
	# Create a simple hit effect
	print("Hit at: ", position)
	
	# You can add particle effects here later
	# For now, just print the hit location
