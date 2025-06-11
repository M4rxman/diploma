@tool
extends Node3D

@export var GroundScene: PackedScene
@export var ObstacleScene: PackedScene
@export var navmesh_template: NavigationMesh
@export var WaveScene: PackedScene

var shader_material: ShaderMaterial

@export_range(1, 21) var map_width: int = 11:
	set(value):
		map_width = make_odd(value, map_width)
		
@export_range(1, 15) var map_depth: int = 11:
	set(value):
		map_depth = make_odd(value, map_depth)

@export_range(0.0, 1.0, 0.05) var obstacle_density: float = 0.2:
	set(value):
		obstacle_density = value

@export_range(1.0, 5.0) var obstacle_max_height: float = 5.0:
	set(value):
		obstacle_max_height = max(value, obstacle_min_height)
		
@export_range(1.0, 5.0) var obstacle_min_height: float = 1.0:
	set(value):
		obstacle_min_height = min(value, obstacle_max_height)

@export var foreground_color: Color = Color.RED:
	set(value):
		foreground_color = value
		
@export var background_color: Color = Color.BLUE:
	set(value):
		background_color = value

@export var rng_seed: int = 12345:
	set(value):
		rng_seed = value

@export var generate_level: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate_map()

@export var level_name: String = "New Level"
@export var save_level: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			save_current_level()

var level: NavigationMap
var navmesh_instance: NavigationRegion3D
var wave_container: Node

func _ready():
	pass
	
func save_current_level():
	if not level:
		print("No level to save!")
		return
		
	var packed_scene = PackedScene.new()
	navmesh_instance.owner = level
	for child in navmesh_instance.get_children():
		child.owner = level
		for subchild in child.get_children():
			subchild.owner = level
		
	wave_container.owner = level
	for child in wave_container.get_children():
		child.owner = level
	
	packed_scene.pack(level)
	var scene_resource_path = "res://Level/LevelGenerator/GeneratedLevels/%s.tscn" % level_name
	ResourceSaver.save(packed_scene, scene_resource_path)
	
	level_name = increment_string(level_name)
	notify_property_list_changed()

func increment_string(string: String):
	# NavMap23
	var regex = RegEx.new()
	regex.compile("\\d+$")
	var result = regex.search(string)
	var num = "0"
	if result:
		num = result.get_string() # num = "23"
	
	return string.trim_suffix(num) + str(int(num)+1)  # "23" --> 23 + 1 --> 24 --> "24"
	
func make_odd(new_int, old_int):
	if new_int % 2 == 0: # it's even
		if new_int > old_int:
			return new_int + 1
		else:
			return new_int - 1
	else: # it's already odd
		return new_int

			
func fill_obstacle_map():
	level.obstacle_map = []
	for x in range(map_width):
		level.obstacle_map.append([])
		for z in range(map_depth):
			level.obstacle_map[x].append(false)
	
func generate_map():
	print("Bleep bloop generating map...")
	
	clear_map()
	add_level()
	level.update_map_center()
	add_ground()
	update_obstacle_material()
	add_obstacles()
	add_waves()
	
	rng_seed = rng_seed + 1
	notify_property_list_changed()
	
func add_waves():
	wave_container = Node.new()
	wave_container.name = "Waves"
	
	if WaveScene:
		var wave = WaveScene.instantiate()
		wave_container.add_child(wave)
	
	level.add_child(wave_container)
	
	wave_container.owner = self
	if wave_container.get_child_count() > 0:
		wave_container.get_child(0).owner = self
	
func clear_map():
	for node in get_children():
		node.queue_free()
		
func add_level():
	level = NavigationMap.new()
	level.name = "Navigation"
	add_child(level)
	level.owner = self
	
	level.map_depth = map_depth
	level.map_width = map_width
	
	# Add navmesh
	navmesh_instance = NavigationRegion3D.new()
	navmesh_instance.name = "NavigationRegion3D"
	level.add_child(navmesh_instance)
	navmesh_instance.owner = self
	
	# navmesh instance
	if navmesh_template:
		navmesh_instance.navigation_mesh = navmesh_template.duplicate()
		
func add_ground():
	if not GroundScene:
		return
		
	var ground = GroundScene.instantiate()
	if ground.has_property("width"):
		ground.width = map_width * 2
	if ground.has_property("depth"):
		ground.depth = map_depth * 2 
	navmesh_instance.add_child(ground)
	ground.owner = self
	
func update_obstacle_material():
	if not ObstacleScene:
		return
		
	var temp_obstacle = ObstacleScene.instantiate()
	if temp_obstacle.has_property("material"):
		shader_material = temp_obstacle.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("ForegroundColor", foreground_color)
			shader_material.set_shader_parameter("BackgroundColor", background_color)
			shader_material.set_shader_parameter("LevelDepth", map_depth*2)
	temp_obstacle.queue_free()
	
func add_obstacles():
	level.fill_map_coords_array()
	fill_obstacle_map()
	
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	level.map_coords_array.shuffle()
	
	var num_obstacles: int = int(level.map_coords_array.size() * obstacle_density)
	var current_obstacle_count = 0
	
	if num_obstacles > 0:
		for i in range(min(num_obstacles, level.map_coords_array.size())):
			var coord = level.map_coords_array[i]
			if coord and not level.map_center.equals(coord):
				current_obstacle_count += 1
				level.obstacle_map[coord.x][coord.z] = true
				if map_is_fully_accessible(current_obstacle_count):
					create_obstacle_at(coord.x, coord.z)
				else:
					current_obstacle_count -= 1
					level.obstacle_map[coord.x][coord.z] = false

func map_is_fully_accessible(current_obstacle_count):
	#Flood fill
	var we_already_checked_here = []
	for x in range(map_width):
		we_already_checked_here.append([])
		for z in range(map_depth):
			we_already_checked_here[x].append(false)
	
	var coords_to_check = [level.map_center]
	we_already_checked_here[level.map_center.x][level.map_center.z] = true
	var accessible_tile_count = 1
	
	while coords_to_check:
		var current_tile: NavigationMap.Coord = coords_to_check.pop_front()
		for x in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x == 0 or z == 0:  # non-diagonal neighbor
					var neighbor = NavigationMap.Coord.new(current_tile.x + x, current_tile.z + z)
					# Make sure we don't go off map
					if on_the_map(neighbor):
						if not we_already_checked_here[neighbor.x][neighbor.z]:
							if not level.obstacle_map[neighbor.x][neighbor.z]:
								we_already_checked_here[neighbor.x][neighbor.z] = true
								coords_to_check.append(neighbor)
								accessible_tile_count += 1

	var target_accessible_tile_count = map_width * map_depth - current_obstacle_count
	if target_accessible_tile_count == accessible_tile_count:
		return true
	else:
		return false
	

func on_the_map(neighbor):
	return neighbor.x >= 0 and neighbor.x < map_width and neighbor.z >= 0 and neighbor.z < map_depth

func create_obstacle_at(x, z):
	if not ObstacleScene:
		return
		
	var obstacle_position = Vector3(x * 2, 0, z * 2)
	obstacle_position += Vector3(-map_width + 1, 0, -map_depth + 1)
	var new_obstacle = ObstacleScene.instantiate()
	
	if new_obstacle.has_property("height"):
		new_obstacle.height = get_obstacle_height()
	
	new_obstacle.transform.origin = obstacle_position + Vector3(0, get_obstacle_height()/2, 0)
	navmesh_instance.add_child(new_obstacle)
	new_obstacle.owner = self

func get_obstacle_height():
	return randf_range(obstacle_min_height, obstacle_max_height)
	
func get_color_at_depth(z):
	return background_color.lerp(foreground_color, float(z)/map_depth)
