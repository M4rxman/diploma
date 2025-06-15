# Level/LevelGenerator/NavigationMap.gd
extends Node3D

class_name Navigation_Map

class Coord:
	var x: int
	var z: int
	
	func _init(x_pos: int, z_pos: int):
		self.x = x_pos
		self.z = z_pos
		
	func _to_string():
		return "(" + str(x) + ", " + str(z) + ")"
		
	func equals(coord: Coord) -> bool:
		return coord.x == self.x and coord.z == self.z

# Map properties
var map_width: int = 11
var map_depth: int = 9
var map_center: Coord
var map_coords_array: Array[Coord] = []
var obstacle_map: Array = []

# Navigation
var navigation_region: NavigationRegion3D
var waves_container: Node

func _ready():
	# Find navigation region
	navigation_region = get_node_or_null("NavigationRegion3D")
	if not navigation_region:
		navigation_region = find_child("NavigationRegion3D")
	
	# Find waves container
	waves_container = get_node_or_null("Waves")
	if not waves_container:
		waves_container = find_child("Waves")

func update_map_center():
	"""Update the map center based on current dimensions"""
	map_center = Coord.new(map_width / 2, map_depth / 2)

func fill_map_coords_array():
	"""Fill the coordinates array with all valid positions"""
	map_coords_array.clear()
	for x in range(map_width):
		for z in range(map_depth):
			map_coords_array.append(Coord.new(x, z))

func get_random_empty_vec3() -> Vector3:
	"""Get a random empty position in world coordinates"""
	var max_attempts = 100
	var attempts = 0
	
	while attempts < max_attempts:
		var random_coord = map_coords_array[randi() % map_coords_array.size()]
		
		# Check if position is empty (no obstacle)
		if obstacle_map.size() > random_coord.x and obstacle_map[random_coord.x].size() > random_coord.z:
			if not obstacle_map[random_coord.x][random_coord.z]:
				# Convert grid coordinates to world coordinates
				var world_pos = Vector3(
					random_coord.x * 2 - map_width + 1,
					0,
					random_coord.z * 2 - map_depth + 1
				)
				return world_pos
		
		attempts += 1
	
	# Fallback to center if no empty space found
	return Vector3.ZERO

func get_random_empty_coord() -> Coord:
	"""Get a random empty coordinate in grid space"""
	var max_attempts = 100
	var attempts = 0
	
	while attempts < max_attempts:
		var random_coord = map_coords_array[randi() % map_coords_array.size()]
		
		# Check if position is empty
		if obstacle_map.size() > random_coord.x and obstacle_map[random_coord.x].size() > random_coord.z:
			if not obstacle_map[random_coord.x][random_coord.z]:
				return random_coord
		
		attempts += 1
	
	# Fallback to center
	return map_center

func world_to_grid(world_pos: Vector3) -> Coord:
	"""Convert world position to grid coordinates"""
	var grid_x = int((world_pos.x + map_width - 1) / 2)
	var grid_z = int((world_pos.z + map_depth - 1) / 2)
	
	# Clamp to valid range
	grid_x = clamp(grid_x, 0, map_width - 1)
	grid_z = clamp(grid_z, 0, map_depth - 1)
	
	return Coord.new(grid_x, grid_z)

func grid_to_world(coord: Coord) -> Vector3:
	"""Convert grid coordinates to world position"""
	return Vector3(
		coord.x * 2 - map_width + 1,
		0,
		coord.z * 2 - map_depth + 1
	)

func is_position_empty(world_pos: Vector3) -> bool:
	"""Check if a world position is empty (no obstacle)"""
	var coord = world_to_grid(world_pos)
	return is_coord_empty(coord)

func is_coord_empty(coord: Coord) -> bool:
	"""Check if a grid coordinate is empty"""
	if (coord.x < 0 or coord.x >= map_width or 
		coord.z < 0 or coord.z >= map_depth):
		return false
	
	if obstacle_map.size() <= coord.x or obstacle_map[coord.x].size() <= coord.z:
		return true
	
	return not obstacle_map[coord.x][coord.z]

func get_waves() -> Array:
	"""Get all wave nodes"""
	var waves: Array = []
	if waves_container:
		for child in waves_container.get_children():
			if child is Wave:
				waves.append(child)
	return waves

func get_navigation_region() -> NavigationRegion3D:
	"""Get the navigation region"""
	return navigation_region

func get_spawn_positions(count: int) -> Array[Vector3]:
	"""Get multiple spawn positions for enemies"""
	var positions: Array[Vector3] = []
	var used_coords: Array[Coord] = []
	var max_attempts = count * 10
	var attempts = 0
	
	while positions.size() < count and attempts < max_attempts:
		var coord = get_random_empty_coord()
		
		# Make sure we don't use the same position twice
		var already_used = false
		for used_coord in used_coords:
			if coord.equals(used_coord):
				already_used = true
				break
		
		if not already_used:
			used_coords.append(coord)
			positions.append(grid_to_world(coord))
		
		attempts += 1
	
	return positions

func get_safe_spawn_position(min_distance_from_center: float = 5.0) -> Vector3:
	"""Get a spawn position that's safely away from the center"""
	var center_world = Vector3.ZERO
	var max_attempts = 50
	var attempts = 0
	
	while attempts < max_attempts:
		var position = get_random_empty_vec3()
		var distance = position.distance_to(center_world)
		
		if distance >= min_distance_from_center:
			return position
		
		attempts += 1
	
	# Fallback to any empty position
	return get_random_empty_vec3()

func find_path_to_center(from_world_pos: Vector3) -> Array[Vector3]:
	"""Find a path from given position to center using NavigationServer"""
	if not navigation_region or not navigation_region.navigation_mesh:
		return [from_world_pos, Vector3.ZERO]
	
	var nav_map = navigation_region.get_navigation_map()
	var path = NavigationServer3D.map_get_path(
		nav_map,
		from_world_pos,
		Vector3.ZERO,
		true
	)
	
	var path_array: Array[Vector3] = []
	for point in path:
		path_array.append(point)
	
	return path_array

func get_map_bounds() -> Dictionary:
	"""Get the world space bounds of the map"""
	var half_width = map_width
	var half_depth = map_depth
	
	return {
		"min_x": -half_width,
		"max_x": half_width,
		"min_z": -half_depth,
		"max_z": half_depth,
		"center": Vector3.ZERO
	}

func debug_print_map():
	"""Print the obstacle map for debugging"""
	print("=== Obstacle Map (", map_width, "x", map_depth, ") ===")
	for z in range(map_depth):
		var row = ""
		for x in range(map_width):
			if map_center.equals(Coord.new(x, z)):
				row += "P "  # Player start
			elif obstacle_map.size() > x and obstacle_map[x].size() > z and obstacle_map[x][z]:
				row += "X "  # Obstacle
			else:
				row += ". "  # Empty
		print(row)
	print("=== End Map ===")

# Static helper functions
static func setup_navigation_for_level(level_root: Node3D) -> NavigationRegion3D:
	"""Set up navigation for a level node"""
	var nav_region = level_root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		level_root.add_child(nav_region)
	
	if not nav_region.navigation_mesh:
		var nav_mesh = NavigationMesh.new()
		nav_mesh.agent_height = 2.0
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 45.0
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		nav_mesh.edge_max_length = 12.0
		nav_mesh.edge_max_error = 1.3
		nav_region.navigation_mesh = nav_mesh
	
	return nav_region
