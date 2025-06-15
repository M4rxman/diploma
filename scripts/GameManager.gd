# scripts/GameManager.gd
extends Node3D

class_name GameManager

@onready var player = $Player
@onready var save_manager = $SaveManager
@onready var level_manager = $DynamicLevelManager

var ray_origin = Vector3()
var ray_target = Vector3()
var current_wave = 0
var enemies_remaining = 0

# UI Elements (add these as needed)
signal wave_changed(wave_number: int)
signal enemies_count_changed(count: int)
signal level_completed

func _ready():
	# Add to game manager group for easy finding
	add_to_group("game_manager")
	
	# Set up global reference
	GameManagerGlobal.set_scene_game_manager(self)
	
	# Connect level manager signals
	if level_manager:
		level_manager.level_generated.connect(_on_level_generated)
		level_manager.enemies_spawned.connect(_on_enemies_spawned)
	
	# Don't load save game immediately - wait for level to generate
	print("GameManager initialized, waiting for level generation...")

func _input(event):
	if event.is_action_pressed("save_game"):
		save_current_game()
	elif event.is_action_pressed("load_game"):
		load_saved_game()
	elif event.is_action_pressed("regenerate_level"):  # Add this action to input map
		regenerate_current_level()

func _physics_process(delta: float) -> void:
	# Handle mouse cursor direction for player
	handle_mouse_cursor()

func handle_mouse_cursor():
	"""Handle player rotation based on mouse cursor"""
	if not player:
		return
		
	var mouse_position = get_viewport().get_mouse_position()
	ray_origin = $Camera3D.project_ray_origin(mouse_position)
	ray_target = ray_origin + $Camera3D.project_ray_normal(mouse_position) * 2000
	
	var space_state = get_world_3d().direct_space_state
	var ray_intersection = PhysicsRayQueryParameters3D.new()
	ray_intersection.from = ray_origin
	ray_intersection.to = ray_target
	var intersection = space_state.intersect_ray(ray_intersection)
	
	if not intersection.is_empty():
		var pos = intersection.position
		var horizontal_stabilization = Vector3(pos.x, player.position.y, pos.z)
		player.look_at(horizontal_stabilization, Vector3.UP)

func _on_level_generated():
	"""Called when the level generation is complete"""
	print("Level generated successfully!")
	
	# Now we can try to load save game if it exists
	call_deferred("try_load_saved_game")

func _on_enemies_spawned():
	"""Called when enemy spawning system is initialized"""
	print("Enemies spawning system ready!")

func try_load_saved_game():
	"""Try to load saved game, fallback to new game"""
	var enemies = get_current_enemies()
	if not save_manager.load_game(player, enemies):
		print("No save file found or load failed, starting new game.")
		start_new_game()

func start_new_game():
	"""Initialize a new game session"""
	print("Starting new game session...")
	current_wave = 0
	
	# Position player at center of generated level
	if level_manager and level_manager.get_current_level():
		var level = level_manager.get_current_level()
		var center_world_pos = Vector3(0, 2, 0)  # Center of map, slightly elevated
		player.global_position = center_world_pos
		print("Player positioned at level center: ", center_world_pos)
	
	# Adjust camera position for better view
	if has_node("Camera3D"):
		var camera = $Camera3D
		# Position camera for better top-down view
		camera.global_position = Vector3(0, 25, 15)  # Higher and back
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		camera.fov = 45.0  # Wider field of view

func save_current_game():
	"""Save the current game state"""
	var enemies = get_current_enemies()
	var level_seed = 0
	var level_settings = {}
	
	# Get current level info
	if level_manager and level_manager.get_current_level():
		var current_level = level_manager.get_current_level()
		level_settings = {
			"map_width": current_level.map_width,
			"map_depth": current_level.map_depth,
			"obstacle_density": level_manager.obstacle_density,
			"foreground_color": level_manager.foreground_color,
			"background_color": level_manager.background_color
		}
		# You'll need to store the seed in DynamicLevelManager
		level_seed = level_manager.current_seed if level_manager.has_property("current_seed") else 0
	
	save_manager.save_game(player, enemies, level_seed, level_settings)

func load_saved_game():
	"""Load saved game state"""
	var enemies = get_current_enemies()
	if not save_manager.load_game(player, enemies):
		print("Load failed, continuing current session.")

func regenerate_current_level():
	"""Regenerate the current level with new settings"""
	if level_manager:
		print("Regenerating level...")
		level_manager.regenerate_level()

func get_current_enemies() -> Array:
	"""Get all current enemies in the scene"""
	return get_tree().get_nodes_in_group("enemies")

func get_targets() -> Array[Node]: 
	"""Get all valid targets (enemies and interactables)"""
	var enemies := get_tree().get_nodes_in_group("enemies")
	var interactables := get_tree().get_nodes_in_group("interact")
	
	enemies.append_array(interactables)
	return enemies

# Wave management functions for spawner callbacks
func _on_wave_update(wave_number: int):
	"""Called when a new wave starts"""
	current_wave = wave_number
	print("Wave ", wave_number + 1, " started!")
	wave_changed.emit(wave_number)

func _on_level_complete():
	"""Called when all waves are completed"""
	print("Level completed! Player wins!")
	level_completed.emit()
	
	# Don't auto-regenerate - let player decide
	print("Press R to generate a new level or continue playing")
	# Optional: You can add a UI popup here asking player what to do

func _on_item_drop(item_scene: PackedScene):
	"""Called when an item should be dropped"""
	if item_scene and player:
		var item = item_scene.instantiate()
		get_tree().current_scene.add_child(item)
		
		# Position near player
		var drop_position = player.global_position + Vector3(
			randf_range(-2, 2), 1, randf_range(-2, 2)
		)
		item.global_position = drop_position
		print("Item dropped: ", item.name)

# Helper functions for AI control (for testing)
func turn_off_enemy_ai() -> bool:
	"""Turn off AI for all enemies"""
	var enemies = get_current_enemies()
	var success = true
	for enemy in enemies:
		if enemy.has_method("_set_ai_to_false"):
			enemy._set_ai_to_false()
		else:
			success = false
	return success

func turn_on_enemy_ai() -> bool:
	"""Turn on AI for all enemies"""
	var enemies = get_current_enemies()
	var success = true
	for enemy in enemies:
		if enemy.has_method("_set_ai_to_true"):
			enemy._set_ai_to_true()
		else:
			success = false
	return success

func get_ai_status() -> bool:
	"""Get AI status from first enemy"""
	var enemies = get_current_enemies()
	if enemies.size() > 0 and enemies[0].has_method("_get_ai_status"):
		return enemies[0]._get_ai_status()
	return false

# Getters for external access
func get_player() -> Node:
	return player

func get_level_manager() -> DynamicLevelManager:
	return level_manager

func get_current_level() -> Navigation_Map:
	if level_manager:
		return level_manager.get_current_level()
	return null

func get_level_spawner() -> LevelSpawner:
	if level_manager:
		return level_manager.get_level_spawner()
	return null
