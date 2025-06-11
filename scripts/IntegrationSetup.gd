extends Node

# Instructions for integrating the level system:
#
# 1. Update all .tscn files in Level/LevelGenerator/GeneratedLevels/
#    - Change format=2 to format=3
#    - Change Navigation to Node3D with NavigationMap script
#    - Change NavigationMeshInstance to NavigationRegion3D
#
# 2. Create new versions of the resource files:
#    - FGShaderMaterial.tres needs to be recreated as a StandardMaterial3D
#    - navmesh_template.tres needs to be recreated
#
# 3. Scene structure changes needed:
#    Main_scene.tscn should include:
#    - A NavigationMap node (from imported levels)
#    - A Spawner node with the updated script
#    - Connect spawner to navigation map

# Helper function to set up a level in your game
static func setup_level_spawning(game_manager: Node3D, level_scene: PackedScene, enemy_scene: PackedScene) -> LevelSpawner:
	# Instance the level
	var level = level_scene.instantiate()
	game_manager.add_child(level)
	
	# Find the NavigationMap in the level
	var nav_map = level as NavigationMap
	if not nav_map:
		nav_map = level.get_node("Navigation") as NavigationMap
	
	if not nav_map:
		push_error("No NavigationMap found in level!")
		return null
	
	# Create spawner
	var spawner = LevelSpawner.new()
	spawner.name = "LevelSpawner"
	spawner.enemy_scene = enemy_scene
	game_manager.add_child(spawner)
	
	# Connect spawner to navigation map
	spawner.navmap = nav_map
	
	# Create Timer for spawner
	var timer = Timer.new()
	timer.name = "Timer"
	spawner.add_child(timer)
	timer.timeout.connect(spawner._on_timer_timeout)
	
	return spawner

# Example of how to use in your GameManager:
static func example_usage():
	print("""
	In your GameManager.gd, add:
	
	@export var level_scenes: Array[PackedScene] = []  # Add NavMap1.tscn, NavMap2.tscn etc
	var current_level_index = 0
	var level_spawner: LevelSpawner
	
	func load_level(index: int):
		# Clear existing level
		if has_node("Navigation"):
			$Navigation.queue_free()
		if level_spawner:
			level_spawner.queue_free()
		
		# Load new level
		if index < level_scenes.size():
			level_spawner = IntegrationSetup.setup_level_spawning(
				self, 
				level_scenes[index], 
				preload("res://scenes/generic_enemy.tscn")
			)
			
			# Connect spawner signals
			level_spawner.wave_update.connect(_on_wave_update)
			level_spawner.level_complete.connect(_on_level_complete)
			level_spawner.drop_item.connect(_on_item_drop)
			
			# Start spawning
			level_spawner.reset()
	""")
