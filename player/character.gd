# player/character.gd - Fixed mortar targeting and RigidBody movement
extends RigidBody3D

@onready var feet = $Feet  
@onready var interaction_ray = $InteractionRay 
@onready var weapon_system = $WeaponManager

@export var mortar_shell_scene: PackedScene
@export var mortar_launch_angle: float = 60.0  # INCREASED angle for higher arc
@export var mortar_min_range: float = 3.0      # REDUCED min range
@export var mortar_max_range: float = 25.0     # REDUCED max range
@onready var launch_point = $"."

var health := 100
var max_health := 100
var ammo := 30
var max_ammo := 30
var is_dead := false

const TARGET_SPEED := 10.0
const TARGET_JUMP := 70.0
const TARGET_GRAVITY := 200.0

var dodge_ready = true
var is_on_floor = true 
var _pid := Pid3D.new(30.0, 0.05, 2.0)

# Signals
signal health_changed(new_health: int, max_health: int)
signal ammo_changed(new_ammo: int, max_ammo: int)
signal player_died
signal player_respawned

func _ready() -> void:
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 5.0
	
	add_to_group("player")
	
	# Create launch point if it doesn't exist
	if not launch_point:
		launch_point = Marker3D.new()
		launch_point.name = "LaunchPoint"
		launch_point.position = Vector3(0, 1.5, 0.5)
		add_child(launch_point)
	
	# Connect weapon system signals
	if weapon_system:
		weapon_system.mortar_shell_scene = mortar_shell_scene
		weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	# Set up feet raycast
	if feet:
		feet.target_position = Vector3(0, -1.0, 0)
		feet.enabled = true
	
	# Remove any MortarShell child nodes that might be spawning automatically
	for child in get_children():
		if child.name == "MortarShell" or child.get_script() == mortar_shell_scene:
			print("Removing auto-spawned mortar shell: ", child.name)
			child.queue_free()
	
	# Emit initial values
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, max_ammo)
	
	print("Character mesh setup - Visible:", has_node("MeshInstance3D"))
	print("Player initialized at position:", global_position)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	_update_floor_detection()
	_apply_gravity(delta)
	
	# Fire current weapon
	if Input.is_action_just_pressed("attack"):
		if weapon_system and ammo > 0:
			weapon_system.fire()
			ammo -= 1
			ammo_changed.emit(ammo, max_ammo)
	
	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# CORRECT MOVEMENT - FIXED AXES PROPERLY
	var direction = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	).normalized()
	
	# Apply movement
	if direction.length() > 0.1:
		var target_velocity = direction * TARGET_SPEED
		target_velocity.y = linear_velocity.y
		
		var velocity_error = Vector3(
			target_velocity.x - linear_velocity.x,
			0.0,
			target_velocity.z - linear_velocity.z
		)
		
		var correction_impulse = _pid.update(velocity_error, delta) * 0.01
		apply_impulse(correction_impulse)
	
	# Jumping logic
	if Input.is_action_just_pressed("jump"): 
		_jump()

func _update_floor_detection():
	if feet and feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false

func _jump() -> void: 
	if is_on_floor and not is_dead:
		apply_impulse(Vector3.UP * TARGET_JUMP)
		is_on_floor = false
		print("Jumped")

func _apply_gravity(delta: float) -> void:
	if not is_on_floor:
		apply_central_impulse(Vector3.DOWN * TARGET_GRAVITY * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_dead:
		return
		
	# CORRECT MOVEMENT INPUT - EXACT COPY FROM YOUR WORKING VERSION
	var move_input = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	if move_input.length() < 0.1:
		var stop_speed = 0.4
		state.linear_velocity.x = lerp(state.linear_velocity.x, 0.0, stop_speed)
		state.linear_velocity.z = lerp(state.linear_velocity.z, 0.0, stop_speed)

func take_damage(amount):
	if is_dead:
		return
		
	health -= amount
	health = max(0, health)
	health_changed.emit(health, max_health)
	print("Player took ", amount, " damage. Health: ", health)
	
	if health <= 0:
		die()

func die():
	if is_dead:
		return
		
	is_dead = true
	print("Player died!")
	player_died.emit()
	
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var material = mesh.material_override as ShaderMaterial
			if material:
				var tween = create_tween()
				tween.tween_method(_change_death_color, 0.0, 1.0, 1.0)
	
	freeze = true
	await get_tree().create_timer(2.0).timeout
	offer_respawn()

func _change_death_color(progress: float):
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var material = mesh.material_override as ShaderMaterial
			if material:
				var death_color = Color.RED.lerp(Color.BLACK, progress)
				material.set_shader_parameter("base_color", death_color)

func offer_respawn():
	print("Press SPACE to respawn or ESC for main menu")
	
	while is_dead:
		if Input.is_action_just_pressed("jump"):
			respawn()
			break
		elif Input.is_action_just_pressed("ui_cancel"):
			get_tree().quit()
			break
		await get_tree().process_frame

func respawn():
	is_dead = false
	health = max_health
	ammo = max_ammo
	freeze = false
	
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var material = mesh.material_override as ShaderMaterial
			if material:
				material.set_shader_parameter("base_color", Color.GREEN)
	
	global_position = Vector3(0, 5, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, max_ammo)
	player_respawned.emit()
	
	# IMPORTANT: Clear any lingering death UI
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if not game_ui:
		# Try to find it in the scene tree
		var ui_nodes = get_tree().get_nodes_in_group("ui")
		for ui_node in ui_nodes:
			if ui_node.has_method("clear_all_messages"):
				game_ui = ui_node
				break
	
	if game_ui and game_ui.has_method("clear_all_messages"):
		game_ui.clear_all_messages()
		print("Cleared death messages on respawn")
	
	print("Player respawned!")

func heal(amount):
	if is_dead:
		return
		
	health += amount
	health = min(max_health, health)
	health_changed.emit(health, max_health)
	print("Player healed ", amount, ". Health: ", health)

func add_ammo(amount):
	ammo += amount
	ammo = min(max_ammo, ammo)
	ammo_changed.emit(ammo, max_ammo)
	print("Player gained ", amount, " ammo. Ammo: ", ammo)

func _try_interact():
	if is_dead:
		return
		
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target.has_method("interact"):
			target.interact()
			print("Interaction completed!")

func _on_weapon_changed(weapon_type):
	print("Weapon changed to: ", weapon_type)

# FIXED MORTAR FUNCTIONS - Completely rewritten for better targeting
func _fire_mortar_at_cursor():
	if is_dead or not mortar_shell_scene:
		print("Cannot fire mortar: dead or no scene")
		return
	
	# Get the main camera from the scene
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("No camera found!")
		return
	
	print("Firing mortar with camera: ", camera.name)
	
	var mouse_pos = get_viewport().get_mouse_position()
	print("Mouse position: ", mouse_pos)
	
	# Create ray from camera through mouse position - SHORTENED RANGE
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100  # REDUCED from 1000 to 100
	
	print("Ray from: ", from, " to: ", to)
	
	# Perform raycast to find target position
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1  # Only hit terrain/static objects
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Hit target at: ", result.position)
		_fire_mortar_at_position(result.position)
	else:
		# If no collision, fire at much closer range in that direction
		var fallback_target = from + camera.project_ray_normal(mouse_pos) * 20  # REDUCED from mortar_max_range to 20
		fallback_target.y = 0  # Place on ground level
		print("No collision, using fallback target: ", fallback_target)
		_fire_mortar_at_position(fallback_target)

func _fire_mortar_at_position(target_pos: Vector3):
	if is_dead or not mortar_shell_scene:
		return
	
	var distance = global_position.distance_to(target_pos)
	print("Target distance: ", distance)
	
	if distance < mortar_min_range:
		print("Target too close! Min range: ", mortar_min_range)
		return
	elif distance > mortar_max_range:
		print("Target too far! Max range: ", mortar_max_range)
		return
	
	# Create mortar shell
	var shell = mortar_shell_scene.instantiate()
	get_tree().current_scene.add_child(shell)
	
	# Position shell at launch point
	var launch_pos = global_position + Vector3(0, 1.5, 0)  # Launch from above player
	shell.global_position = launch_pos
	
	print("Shell created at: ", shell.global_position)
	
	# Calculate and apply launch velocity
	var launch_velocity = _calculate_mortar_trajectory(target_pos, launch_pos)
	
	if launch_velocity.length() > 0:
		# Face the target direction
		var look_direction = Vector3(target_pos.x - global_position.x, 0, target_pos.z - global_position.z).normalized()
		if look_direction.length() > 0:
			look_at(global_position + look_direction, Vector3.UP)
		
		# Launch the shell using the new method
		if shell.has_method("launch_at_target"):
			shell.launch_at_target(target_pos)
			print("Launched shell using launch_at_target method")
		elif shell.has_method("launch"):
			shell.launch(launch_velocity.normalized(), launch_velocity.length())
			print("Launched shell using launch method")
		else:
			# Fallback: apply velocity directly
			if shell is RigidBody3D:
				shell.linear_velocity = launch_velocity
				print("Applied velocity directly: ", launch_velocity)
			else:
				print("Shell is not RigidBody3D, cannot apply velocity")
				shell.queue_free()
				return
		
		# Apply recoil to player
		var recoil = -look_direction * 5.0
		apply_impulse(recoil)
		
		print("Mortar fired! Target: ", target_pos, " Distance: ", distance)
	else:
		print("Could not calculate trajectory")
		shell.queue_free()

func _calculate_mortar_trajectory(target_pos: Vector3, launch_pos: Vector3 = global_position) -> Vector3:
	"""Calculate ballistic trajectory for mortar shell"""
	var displacement = target_pos - launch_pos
	var horizontal_distance = Vector2(displacement.x, displacement.z).length()
	var vertical_distance = displacement.y
	
	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var angle_rad = deg_to_rad(mortar_launch_angle)
	
	print("Calculating trajectory - H dist: ", horizontal_distance, " V dist: ", vertical_distance, " Angle: ", mortar_launch_angle)
	
	# Ballistic formula for required velocity
	var velocity_squared = (gravity * horizontal_distance * horizontal_distance) / (2.0 * cos(angle_rad) * cos(angle_rad) * (horizontal_distance * tan(angle_rad) - vertical_distance))
	
	if velocity_squared <= 0:
		# Try with a steeper angle
		angle_rad = deg_to_rad(60.0)
		velocity_squared = (gravity * horizontal_distance * horizontal_distance) / (2.0 * cos(angle_rad) * cos(angle_rad) * (horizontal_distance * tan(angle_rad) - vertical_distance))
		
		if velocity_squared <= 0:
			print("Cannot calculate valid trajectory")
			return Vector3.ZERO
	
	var velocity = sqrt(velocity_squared)
	var horizontal_dir = Vector3(displacement.x, 0, displacement.z).normalized()
	var launch_direction = horizontal_dir * cos(angle_rad) + Vector3.UP * sin(angle_rad)
	
	var final_velocity = launch_direction * velocity
	print("Calculated velocity: ", final_velocity, " (magnitude: ", velocity, ")")
	
	return final_velocity
