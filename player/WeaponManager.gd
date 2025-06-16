# player/WeaponManager.gd - Fixed weapon system with proper damage
extends Node3D

enum WeaponType {
	SWORD,
	PISTOL,
	SHOTGUN,
	MORTAR
}

const WEAPON_STATS = {
	WeaponType.SWORD: {
		"damage": 50,
		"range": 3.0,
		"cooldown": 0.5,
		"knockback": 50.0,  # Reduced knockback
		"color": Color(0, 1, 0),
		"name": "Sword"
	},
	WeaponType.PISTOL: {
		"damage": 25,
		"range": 50.0,
		"cooldown": 0.3,
		"knockback": 10.0,  # Much smaller knockback
		"color": Color(1, 1, 0),
		"name": "Pistol"
	},
	WeaponType.SHOTGUN: {
		"damage": 15,
		"range": 20.0,
		"cooldown": 0.8,
		"pellets": 5,
		"spread": 15.0,
		"knockback": 8.0,  # Minimal knockback per pellet
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
	
	switch_weapon(WeaponType.PISTOL)

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
	
	# Check for wall blocking sword attack
	var wall_check = _check_for_wall_in_front(WEAPON_STATS[WeaponType.SWORD]["range"])
	if wall_check:
		print("Sword blocked by wall")
		return
	
	print("Firing sword!")
	sword_hitbox.monitoring = true
	
	# Visual thrust effect
	var tween = create_tween()
	var thrust_direction = -owner_body.transform.basis.z * 0.3
	tween.tween_property(owner_body, "position", owner_body.position + thrust_direction, 0.1)
	tween.tween_property(owner_body, "position", owner_body.position, 0.1)
	
	await get_tree().create_timer(0.2).timeout
	sword_hitbox.monitoring = false

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
	
	# Apply knockback
	if body is RigidBody3D:
		var knockback_dir = (body.global_position - owner_body.global_position).normalized()
		body.apply_central_impulse(knockback_dir * WEAPON_STATS[WeaponType.SWORD]["knockback"])

func _fire_pistol():
	if not hitscan_raycast:
		return
	
	print("Firing pistol!")
	
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
		print("Hit at: ", hit_point)
	else:
		print("Pistol missed")

func _fire_shotgun():
	var stats = WEAPON_STATS[WeaponType.SHOTGUN]
	var spread_angle = deg_to_rad(stats["spread"])
	var pellet_count = stats["pellets"]
	
	print("Shotgun firing ", pellet_count, " pellets with ", stats["damage"], " damage each")
	
	for i in range(pellet_count):
		var space_state = owner_body.get_world_3d().direct_space_state
		var start_pos = owner_body.global_position + Vector3(0, 0.5, 0)
		
		# Calculate spread for each pellet
		var spread_x = randf_range(-spread_angle, spread_angle)
		var spread_y = randf_range(-spread_angle, spread_angle)
		
		var forward = -owner_body.transform.basis.z
		var right = owner_body.transform.basis.x
		var up = owner_body.transform.basis.y
		
		var spread_direction = forward + right * sin(spread_x) + up * sin(spread_y)
		spread_direction = spread_direction.normalized()
		
		var end_pos = start_pos + spread_direction * stats["range"]
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.exclude = [owner_body]
		query.collision_mask = 0xFFFFFFFF
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit_body = result["collider"]
			print("Shotgun pellet ", i+1, " hit: ", hit_body.name)
			
			if hit_body.has_method("take_damage"):
				hit_body.take_damage(stats["damage"])
				print("Shotgun pellet dealt ", stats["damage"], " damage to ", hit_body.name)
				
				# Small knockback per pellet
				if hit_body is RigidBody3D:
					var knockback_dir = (hit_body.global_position - owner_body.global_position).normalized()
					hit_body.apply_central_impulse(knockback_dir * stats["knockback"])

func _fire_mortar():
	print("Firing mortar!")
	if owner_body.has_method("_fire_mortar_at_cursor"):
		owner_body._fire_mortar_at_cursor()

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
