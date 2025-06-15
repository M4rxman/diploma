# scripts/DynamicLevelManager.gd - Enhanced wave system with item drops
extends Node3D

class_name DynamicLevelManager

# Level generation settings
@export_group("Level Generation")
@export var ground_scene: PackedScene = preload("res://Level/LevelGenerator/Ground.tscn")
@export var obstacle_scene: PackedScene = preload("res://Level/LevelGenerator/Obstacle.tscn")
@export var navmesh_template: NavigationMesh = preload("res://Level/LevelGenerator/navmesh_template.tres")
@export var wave_scene: PackedScene = preload("res://Spawning/Wave.tscn")

@export_group("Map Settings")
@export_range(5, 21, 2) var map_width: int = 11
@export_range(5, 15, 2) var map_depth: int = 9
@export_range(0.1, 0.8) var obstacle_density: float = 0.3
@export_range(1.0, 5.0) var obstacle_max_height: float = 3.0
@export_range(1.0, 3.0) var obstacle_min_height: float = 1.0

@export_group("Visual Settings")
@export var foreground_color: Color = Color(0.8, 0.3, 0.5)
@export var background_color: Color = Color(0.3, 0.4, 0.6)

@export_group("Enemy Spawning")
@export var enemy_scene: PackedScene = preload("res://scenes/generic_enemy.tscn")
@export var spawn_enemies: bool = true

# Internal variables
var current_level: Navigation_Map
var level_spawner: LevelSpawner
var rng: RandomNumberGenerator
var game_manager: GameManager
var current_seed: int = 0
var map_bounds: Dictionary = {}

signal level_generated
signal enemies_spawned

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Find game manager
	game_manager = get_parent() as GameManager
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	# Auto-generate level on start
	call_deferred("generate_new_level")

func generate_new_level():
	"""Generate a completely new level with random seed and map boundaries"""
	print("Generating new level...")
	
	clear_current_level()
	current_seed = rng.randi()
	print("Level seed: ", current_seed)
	
	create_level_structure(current_seed)
	add_ground()
	add_obstacles(current_seed)
	add_map_walls()  # Add boundary walls
	bake_navigation()
	add_enhanced_waves()  # Use enhanced wave system
	
	# Calculate map bounds for boundary checking
	calculate_map_bounds()
	
	if spawn_enemies and enemy_scene:
		setup_enemy_spawning()
	
	level_generated.emit()
	print("Level generation complete with map boundaries!")

func calculate_map_bounds():
	"""Calculate world-space boundaries of the map"""
	var half_width = map_width
	var half_depth = map_depth
	
	map_bounds = {
		"min_x": -half_width + 2,  # Leave some margin inside walls
		"max_x": half_width - 2,
		"min_z": -half_depth + 2,
		"max_z": half_depth - 2,
		"center": Vector3.ZERO,
		"wall_height": 10.0  # Height of boundary walls
	}
	
	print("Map bounds set: ", map_bounds)

func add_map_walls():
	"""Add walls around the map perimeter to prevent falling off"""
	if not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	var wall_height = 10.0
	var wall_thickness = 2.0
	var wall_material = create_wall_material()
	
	# Calculate wall positions based on map size
	var half_width = map_width + wall_thickness
	var half_depth = map_depth + wall_thickness
	
	# North wall (positive Z)
	create_wall(nav_region, Vector3(0, wall_height/2, half_depth), 
				Vector3(half_width * 2, wall_height, wall_thickness), wall_material)
	
	# South wall (negative Z)
	create_wall(nav_region, Vector3(0, wall_height/2, -half_depth), 
				Vector3(half_width * 2, wall_height, wall_thickness), wall_material)
	
	# East wall (positive X)
	create_wall(nav_region, Vector3(half_width, wall_height/2, 0), 
				Vector3(wall_thickness, wall_height, half_depth * 2), wall_material)
	
	# West wall (negative X)
	create_wall(nav_region, Vector3(-half_width, wall_height/2, 0), 
				Vector3(wall_thickness, wall_height, half_depth * 2), wall_material)
	
	print("Added boundary walls around map")

func create_wall(parent: Node, position: Vector3, size: Vector3, material: Material):
	"""Create a single wall segment"""
	var wall = StaticBody3D.new()
	wall.name = "BoundaryWall"
	
	# Create collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	wall.add_child(collision)
	
	# Create visual mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	wall.add_child(mesh_instance)
	
	# Position the wall
	wall.global_position = position
	parent.add_child(wall)

func create_wall_material() -> StandardMaterial3D:
	"""Create material for boundary walls"""
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, slightly transparent
	material.metallic = 0.1
	material.roughness = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func clear_current_level():
	"""Remove existing level and spawner"""
	if current_level:
		current_level.queue_free()
		current_level = null
	
	if level_spawner:
		level_spawner.queue_free()
		level_spawner = null

func create_level_structure(seed: int):
	"""Create the basic level structure with Navigation_Map"""
	const NavigationMapScript = preload("res://Level/LevelGenerator/NavigationMap.gd")
	
	var level_node = Node3D.new()
	level_node.set_script(NavigationMapScript)
	level_node.name = "GeneratedLevel"
	add_child(level_node)
	
	current_level = level_node as Navigation_Map
	current_level.map_width = map_width
	current_level.map_depth = map_depth
	current_level.update_map_center()
	current_level.fill_map_coords_array()
	
	# Create NavigationRegion3D
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	current_level.add_child(nav_region)
	
	if navmesh_template:
		nav_region.navigation_mesh = navmesh_template.duplicate()

func add_ground():
	"""Add ground plane to the level"""
	if not ground_scene or not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	var ground = ground_scene.instantiate()
	
	# Scale ground to map size
	if ground.has_method("set_size"):
		ground.set_size(Vector3(map_width * 2, 1, map_depth * 2))
	elif ground.get("size"):
		ground.size = Vector3(map_width * 2, 1, map_depth * 2)
	
	nav_region.add_child(ground)

func add_obstacles(seed: int):
	"""Generate and place obstacles randomly"""
	if not obstacle_scene or not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	var obstacle_rng = RandomNumberGenerator.new()
	obstacle_rng.seed = seed
	
	# Initialize obstacle map
	current_level.obstacle_map = []
	for x in range(map_width):
		current_level.obstacle_map.append([])
		for z in range(map_depth):
			current_level.obstacle_map[x].append(false)
	
	# Shuffle coordinates for random placement
	var coords = current_level.map_coords_array.duplicate()
	coords.shuffle()
	
	var num_obstacles = int(coords.size() * obstacle_density)
	var placed_obstacles = 0
	
	for i in range(min(num_obstacles, coords.size())):
		var coord = coords[i]
		if coord and not current_level.map_center.equals(coord):
			current_level.obstacle_map[coord.x][coord.z] = true
			
			if is_map_fully_accessible(placed_obstacles + 1):
				create_obstacle_at(coord.x, coord.z, obstacle_rng, nav_region)
				placed_obstacles += 1
			else:
				current_level.obstacle_map[coord.x][coord.z] = false
	
	print("Placed ", placed_obstacles, " obstacles")

func create_obstacle_at(x: int, z: int, obstacle_rng: RandomNumberGenerator, nav_region: NavigationRegion3D):
	"""Create an obstacle at the specified grid position"""
	var obstacle_position = Vector3(x * 2, 0, z * 2)
	obstacle_position += Vector3(-map_width + 1, 0, -map_depth + 1)
	
	var obstacle = obstacle_scene.instantiate()
	
	# Create simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = foreground_color
	material.metallic = 0.3
	material.roughness = 0.7
	
	if obstacle.get("material"):
		obstacle.material = material
	
	# Set random height
	var height = obstacle_rng.randf_range(obstacle_min_height, obstacle_max_height)
	if obstacle.get("size"):
		obstacle.size.y = height
	
	obstacle.transform.origin = obstacle_position + Vector3(0, height / 2, 0)
	nav_region.add_child(obstacle)

func is_map_fully_accessible(obstacle_count: int) -> bool:
	"""Check if all accessible tiles can be reached using flood fill"""
	var checked = []
	for x in range(map_width):
		checked.append([])
		for z in range(map_depth):
			checked[x].append(false)
	
	var to_check = [current_level.map_center]
	checked[current_level.map_center.x][current_level.map_center.z] = true
	var accessible_count = 1
	
	while to_check.size() > 0:
		var current = to_check.pop_front()
		
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var neighbor_x = current.x + offset.x
			var neighbor_z = current.z + offset.y
			
			if (neighbor_x >= 0 and neighbor_x < map_width and 
				neighbor_z >= 0 and neighbor_z < map_depth):
				
				if not checked[neighbor_x][neighbor_z]:
					if not current_level.obstacle_map[neighbor_x][neighbor_z]:
						checked[neighbor_x][neighbor_z] = true
						to_check.append(Navigation_Map.Coord.new(neighbor_x, neighbor_z))
						accessible_count += 1
	
	var expected_accessible = map_width * map_depth - obstacle_count
	return accessible_count == expected_accessible

func bake_navigation():
	"""Bake the navigation mesh"""
	if not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("Navigation mesh baked")

func add_enhanced_waves():
	"""Add enhanced wave configuration with progressive difficulty and item drops"""
	if not wave_scene or not current_level:
		return
	
	var waves_container = Node.new()
	waves_container.name = "Waves"
	current_level.add_child(waves_container)
	
	# Enhanced wave configurations with scaling difficulty
	var wave_configs = [
		{
			"enemies": 3, 
			"speed": 3.0, 
			"health": 60, 
			"damage": 10,
			"spawn_delay": 2.0,
			"drops_health": true,
			"drops_ammo": false
		},
		{
			"enemies": 5, 
			"speed": 3.5, 
			"health": 80, 
			"damage": 12,
			"spawn_delay": 1.8,
			"drops_health": false,
			"drops_ammo": true
		},
		{
			"enemies": 8, 
			"speed": 4.0, 
			"health": 100, 
			"damage": 15,
			"spawn_delay": 1.5,
			"drops_health": true,
			"drops_ammo": true
		},
		{
			"enemies": 12, 
			"speed": 4.5, 
			"health": 120, 
			"damage": 18,
			"spawn_delay": 1.2,
			"drops_health": true,
			"drops_ammo": true
		},
		{
			"enemies": 15, 
			"speed": 5.0, 
			"health": 150, 
			"damage": 20,
			"spawn_delay": 1.0,
			"drops_health": true,
			"drops_ammo": true
		}
	]
	
	for i in range(wave_configs.size()):
		var wave = wave_scene.instantiate()
		var config = wave_configs[i]
		
		# Set wave properties
		if wave.get("num_enemies") != null:
			wave.num_enemies = config["enemies"]
		if wave.get("move_speed") != null:
			wave.move_speed = config["speed"]
		if wave.get("health") != null:
			wave.health = config["health"]
		if wave.get("damage") != null:
			wave.damage = config["damage"]
		if wave.get("second_between_spawns") != null:
			wave.second_between_spawns = config["spawn_delay"]
		
		# Set drop items (will be created later as needed)
		if config.get("drops_health", false):
			wave.set("drops_health_pack", true)
		if config.get("drops_ammo", false):
			wave.set("drops_ammo_pack", true)
		
		wave.name = "Wave" + str(i + 1)
		waves_container.add_child(wave)
		
		print("Created Wave ", i + 1, " with ", config["enemies"], " enemies")

func setup_enemy_spawning():
	"""Set up the enhanced enemy spawning system"""
	if not current_level or not enemy_scene:
		return
	
	level_spawner = LevelSpawner.new()
	level_spawner.name = "LevelSpawner"
	level_spawner.enemy_scene = enemy_scene
	level_spawner.navmap = current_level
	add_child(level_spawner)
	
	# Connect signals if game manager exists
	if game_manager:
		level_spawner.wave_update.connect(game_manager._on_wave_update.bind())
		level_spawner.level_complete.connect(game_manager._on_level_complete.bind())
		level_spawner.drop_item.connect(game_manager._on_item_drop.bind())
	
	level_spawner.reset()
	enemies_spawned.emit()
	print("Enhanced enemy spawning system initialized")

func get_current_level() -> Navigation_Map:
	return current_level

func get_level_spawner() -> LevelSpawner:
	return level_spawner

func get_map_bounds() -> Dictionary:
	return map_bounds

func regenerate_level():
	"""Regenerate the level with new random settings"""
	obstacle_density = rng.randf_range(0.2, 0.6)
	obstacle_max_height = rng.randf_range(2.0, 4.0)
	
	foreground_color = Color(rng.randf(), rng.randf(), rng.randf())
	background_color = Color(rng.randf() * 0.5, rng.randf() * 0.5, rng.randf() * 0.5)
	
	generate_new_level()
