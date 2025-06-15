# scripts/DynamicLevelManager.gd - Fixed navigation baking
extends Node3D

class_name DynamicLevelManager

@export_group("Level Generation")
@export var ground_scene: PackedScene = preload("res://Level/LevelGenerator/Ground.tscn")
@export var obstacle_scene: PackedScene = preload("res://Level/LevelGenerator/Obstacle.tscn")
@export var navmesh_template: NavigationMesh = preload("res://Level/LevelGenerator/navmesh_template.tres")
@export var wave_scene: PackedScene = preload("res://Spawning/Wave.tscn")

const NavigationMapScript = preload("res://Level/LevelGenerator/NavigationMap.gd")

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

var current_level: Navigation_Map
var level_spawner: LevelSpawner
var rng: RandomNumberGenerator
var game_manager: GameManager
var current_seed: int = 0

signal level_generated
signal enemies_spawned

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	game_manager = get_parent() as GameManager
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	call_deferred("generate_new_level")

func generate_new_level():
	print("Generating new level...")
	
	clear_current_level()
	current_seed = rng.randi()
	print("Level seed: ", current_seed)
	
	create_level_structure(current_seed)
	add_ground()
	add_obstacles(current_seed)
	
	# IMPORTANT: Wait for physics to settle before baking navigation
	await get_tree().process_frame
	await get_tree().process_frame
	
	bake_navigation()
	add_waves()
	
	if spawn_enemies and enemy_scene:
		setup_enemy_spawning()
	
	level_generated.emit()
	print("Level generation complete!")

func clear_current_level():
	if current_level:
		current_level.queue_free()
		current_level = null
	
	if level_spawner:
		level_spawner.queue_free()
		level_spawner = null

func create_level_structure(seed: int):
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
	
	# Setup navigation mesh with proper settings
	if navmesh_template:
		var nav_mesh = navmesh_template.duplicate()
		# Configure navigation mesh for better pathfinding
		nav_mesh.agent_height = 2.0
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 45.0
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		nav_mesh.edge_max_length = 12.0
		nav_mesh.edge_max_error = 1.3
		nav_mesh.detail_sample_distance = 6.0
		nav_mesh.detail_sample_max_error = 1.0
		nav_region.navigation_mesh = nav_mesh
		print("Navigation mesh template applied")

func add_ground():
	if not ground_scene or not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	var ground = ground_scene.instantiate()
	
	if ground.has_method("set_size"):
		ground.set_size(Vector3(map_width * 2, 1, map_depth * 2))
	elif ground.get("size"):
		ground.size = Vector3(map_width * 2, 1, map_depth * 2)
	
	nav_region.add_child(ground)
	print("Ground added with size: ", Vector3(map_width * 2, 1, map_depth * 2))

func add_obstacles(seed: int):
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
	var obstacle_position = Vector3(x * 2, 0, z * 2)
	obstacle_position += Vector3(-map_width + 1, 0, -map_depth + 1)
	
	var obstacle = obstacle_scene.instantiate()
	
	# Create simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = foreground_color
	material.metallic = 0.3
	material.roughness = 0.7
	
	if obstacle.has_method("set_surface_override_material"):
		obstacle.set_surface_override_material(0, material)
	elif obstacle.get("material"):
		obstacle.material = material
	
	var height = obstacle_rng.randf_range(obstacle_min_height, obstacle_max_height)
	if obstacle.get("size"):
		obstacle.size.y = height
	
	obstacle.transform.origin = obstacle_position + Vector3(0, height / 2, 0)
	
	# Set collision layer for obstacles
	if obstacle is StaticBody3D:
		obstacle.collision_layer = 1
		obstacle.collision_mask = 0
	
	nav_region.add_child(obstacle)

func is_map_fully_accessible(obstacle_count: int) -> bool:
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
						to_check.append(NavigationMap.Coord.new(neighbor_x, neighbor_z))
						accessible_count += 1
	
	var expected_accessible = map_width * map_depth - obstacle_count
	return accessible_count == expected_accessible

func bake_navigation():
	"""PROPERLY bake navigation mesh"""
	if not current_level:
		return
	
	var nav_region = current_level.get_node("NavigationRegion3D")
	if not nav_region or not nav_region.navigation_mesh:
		print("No navigation region or mesh found!")
		return
	
	print("Starting navigation mesh baking...")
	
	# Wait for all physics bodies to settle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Force bake the navigation mesh
	nav_region.bake_navigation_mesh()
	
	# Wait for baking to complete
	await get_tree().process_frame
	
	# Verify navigation is working
	var nav_map = nav_region.get_navigation_map()
	if nav_map.is_valid():
		print("Navigation mesh baked successfully!")
		print("Navigation map ID: ", nav_map)
		
		# Debug: Test navigation paths
		var center_pos = Vector3.ZERO
		var test_pos = Vector3(5, 0, 5)
		var path = NavigationServer3D.map_get_path(nav_map, center_pos, test_pos, true)
		if path.size() > 0:
			print("Navigation test successful - path found with ", path.size(), " points")
		else:
			print("WARNING: Navigation test failed - no path found")
	else:
		print("ERROR: Navigation mesh baking failed!")

func add_waves():
	if not wave_scene or not current_level:
		return
	
	var waves_container = Node.new()
	waves_container.name = "Waves"
	current_level.add_child(waves_container)
	
	# Create waves with increasing difficulty
	var wave_configs = [
		{"enemies": 3, "speed": 2.0, "health": 80, "damage": 15},
		{"enemies": 5, "speed": 2.5, "health": 100, "damage": 20},
		{"enemies": 8, "speed": 3.0, "health": 120, "damage": 25},
		{"enemies": 12, "speed": 3.5, "health": 150, "damage": 30}
	]
	
	for i in range(wave_configs.size()):
		var wave = wave_scene.instantiate()
		var config = wave_configs[i]
		
		if wave.get("num_enemies") != null:
			wave.num_enemies = config["enemies"]
		if wave.get("move_speed") != null:
			wave.move_speed = config["speed"]
		if wave.get("health") != null:
			wave.health = config["health"]
		if wave.get("damage") != null:
			wave.damage = config["damage"]
		
		wave.name = "Wave" + str(i + 1)
		waves_container.add_child(wave)
	
	print("Added ", wave_configs.size(), " waves")

func setup_enemy_spawning():
	if not current_level or not enemy_scene:
		return
	
	# Wait for navigation to be fully ready
	await get_tree().create_timer(0.5).timeout
	
	level_spawner = LevelSpawner.new()
	level_spawner.name = "LevelSpawner"
	level_spawner.enemy_scene = enemy_scene
	level_spawner.navmap = current_level
	add_child(level_spawner)
	
	# Connect signals
	if game_manager:
		level_spawner.wave_update.connect(game_manager._on_wave_update.bind())
		level_spawner.level_complete.connect(game_manager._on_level_complete.bind())
		level_spawner.drop_item.connect(game_manager._on_item_drop.bind())
	
	# Start spawning
	level_spawner.reset()
	enemies_spawned.emit()
	print("Enemy spawning system initialized with navigation")

func get_current_level() -> Navigation_Map:
	return current_level

func get_level_spawner() -> LevelSpawner:
	return level_spawner

func regenerate_level():
	obstacle_density = rng.randf_range(0.2, 0.6)
	obstacle_max_height = rng.randf_range(2.0, 4.0)
	foreground_color = Color(rng.randf(), rng.randf(), rng.randf())
	background_color = Color(rng.randf() * 0.5, rng.randf() * 0.5, rng.randf() * 0.5)
	generate_new_level()
