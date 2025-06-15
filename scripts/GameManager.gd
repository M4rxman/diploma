# scripts/GameManager.gd - Fixed game manager without teleportation
extends Node3D

class_name GameManager

@onready var player = $Player
@onready var save_manager = $SaveManager
@onready var level_manager = $DynamicLevelManager

# UI system
var game_ui: Control

var ray_origin = Vector3()
var ray_target = Vector3()
var current_wave = 0
var enemies_remaining = 0

# Game state
var game_started = false
var level_completed = false

# UI Elements signals
signal wave_changed(wave_number: int)
signal enemies_count_changed(count: int)
signal level_completed_signal

func _ready():
	# Add to game manager group for easy finding
	add_to_group("game_manager")
	
	# Set up global reference
	GameManagerGlobal.set_scene_game_manager(self)
	
	# Create and add UI
	setup_game_ui()
	
	# Connect level manager signals
	if level_manager:
		level_manager.level_generated.connect(_on_level_generated)
		level_manager.enemies_spawned.connect(_on_enemies_spawned)
	
	# Connect player signals for UI updates
	if player:
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		if player.has_signal("player_respawned"):
			player.player_respawned.connect(_on_player_respawned)
	
	print("GameManager initialized, waiting for level generation...")

func setup_game_ui():
	"""Create and setup the game UI"""
	# Create the UI script instance
	var ui_script = preload("res://ui/GameUI.gd")
	game_ui = ui_script.new()
	game_ui.name = "GameUI"
	
	# Add UI to the scene tree as a CanvasLayer for proper rendering
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "UILayer"
	add_child(canvas_layer)
	canvas_layer.add_child(game_ui)
	
	print("Game UI initialized")

func _input(event):
	if event.is_action_pressed("save_game"):
		save_current_game()
	elif event.is_action_pressed("load_game"):
		load_saved_game()
	elif event.is_action_pressed("regenerate_level"):  # Add this action to input map (R key)
		regenerate_current_level()

func _physics_process(delta: float) -> void:
	# Handle mouse cursor direction for player
	handle_mouse_cursor()

func handle_mouse_cursor():
	"""Handle player rotation based on mouse cursor"""
	if not player or (player.get("is_dead") and player.is_dead):
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
	
	# Clear any existing UI messages when level is regenerated
	if game_ui:
		clear_ui_messages()
	
	call_deferred("try_load_saved_game")

func clear_ui_messages():
	"""Clear death and victory messages from UI"""
	if game_ui and game_ui.has_method("clear_all_messages"):
		game_ui.clear_all_messages()
	
	# Remove death overlay if it exists
	if has_node("UILayer/GameUI/DeathOverlay"):
		get_node("UILayer/GameUI/DeathOverlay").queue_free()
	
	# Remove any victory messages
	for child in get_tree().get_nodes_in_group("victory_message"):
		child.queue_free()

func _on_enemies_spawned():
	"""Called when enemy spawning system is initialized"""
	print("Enemies spawning system ready!")

func try_load_saved_game():
	"""Try to load saved game, fallback to new game"""
	var enemies = get_current_enemies()
	if save_manager and save_manager.has_method("load_game"):
		var level_data = save_manager.load_game(player, enemies)
		if not level_data.is_empty():
			print("Game loaded from save file")
			return
	
	print("No save file found or load failed, starting new game.")
	start_new_game()

func start_new_game():
	"""Initialize a new game session"""
	print("Starting new game session...")
	current_wave = 0
	game_started = true
	level_completed = false
	
	# IMPORTANT: Reset player stats when starting new game
	if player:
		if player.has_method("heal"):
			player.heal(player.max_health)  # Full heal
		if player.has_method("add_ammo"):
			player.ammo = player.max_ammo  # Full ammo reload
			player.ammo_changed.emit(player.ammo, player.max_ammo)
		print("Player stats reset - Health: ", player.health, " Ammo: ", player.ammo)
	
	# Position player at center of generated level
	if level_manager and level_manager.get_current_level():
		var center_world_pos = Vector3(0, 3, 0)  # Center of map, elevated for safety
		player.global_position = center_world_pos
		print("Player positioned at level center: ", center_world_pos)
	
	# Adjust camera position for better view
	if has_node("Camera3D"):
		var camera = $Camera3D
		camera.global_position = Vector3(0, 25, 15)
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		camera.fov = 45.0

func save_current_game():
	"""Save the current game state"""
	if not save_manager:
		print("No save manager available!")
		return
		
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
		level_seed = level_manager.current_seed if level_manager.has_property("current_seed") else 0
	
	save_manager.save_game(player, enemies, level_seed, level_settings)
	print("Game saved!")

func load_saved_game():
	"""Load saved game state"""
	if not save_manager:
		print("No save manager available!")
		return
		
	var enemies = get_current_enemies()
	var level_data = save_manager.load_game(player, enemies)
	if not level_data.is_empty():
		print("Game loaded successfully!")
	else:
		print("Load failed, continuing current session.")

func regenerate_current_level():
	"""Regenerate the current level with new settings"""
	if level_manager:
		print("Regenerating level...")
		level_completed = false
		current_wave = 0
		
		# IMPORTANT: Clear death messages before regenerating
		clear_ui_messages()
		
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
	
	# Update UI
	if game_ui and game_ui.has_method("_on_wave_changed"):
		game_ui._on_wave_changed(wave_number)

func _on_level_complete():
	"""Called when all waves are completed"""
	print("Level completed! Player wins!")
	level_completed = true
	level_completed_signal.emit()
	
	# Show completion message
	if game_ui and game_ui.has_method("show_level_complete_message"):
		game_ui.show_level_complete_message()
	
	print("Press R to generate a new level")

func _on_wave_complete(wave_number: int):
	"""Called when a single wave is completed"""
	print("Wave ", wave_number, " completed!")
	
	# Show wave completion message
	if game_ui and game_ui.has_method("show_wave_complete_message"):
		game_ui.show_wave_complete_message(wave_number)

func _on_item_drop(item_scene: PackedScene):
	"""Called when an item should be dropped"""
	if item_scene and player:
		var item = item_scene.instantiate()
		get_tree().current_scene.add_child(item)
		
		# Position near player
		var drop_position = player.global_position + Vector3(
			randf_range(-3, 3), 2, randf_range(-3, 3)
		)
		item.global_position = drop_position
		print("Item dropped: ", item.name if item.has_method("get_name") else "Unknown Item")

func _on_player_died():
	"""Handle player death"""
	print("Player has died!")
	
	# Show death UI
	if game_ui and game_ui.has_method("show_death_message"):
		game_ui.show_death_message()
	
	# Pause enemy spawning
	var spawner = get_level_spawner()
	if spawner and spawner.has_method("pause_spawning"):
		spawner.pause_spawning()

func _on_player_respawned():
	"""Handle player respawn"""
	print("Player has respawned!")
	
	# Resume enemy spawning
	var spawner = get_level_spawner()
	if spawner and spawner.has_method("resume_spawning"):
		spawner.resume_spawning()

# Helper functions for AI control (for testing)
func _turn_off_enemy_ai() -> bool:
	"""Turn off AI for all enemies"""
	var enemies = get_current_enemies()
	var success = true
	for enemy in enemies:
		if enemy.has_method("_set_ai_to_false"):
			enemy._set_ai_to_false()
		else:
			success = false
	return success

func _turn_on_enemy_ai() -> bool:
	"""Turn on AI for all enemies"""
	var enemies = get_current_enemies()
	var success = true
	for enemy in enemies:
		if enemy.has_method("_set_ai_to_true"):
			enemy._set_ai_to_true()
		else:
			success = false
	return success

func turn_off_enemy_ai() -> bool:
	return _turn_off_enemy_ai()

func turn_on_enemy_ai() -> bool:
	return _turn_on_enemy_ai()

func get_ai_status() -> bool:
	"""Get AI status from first enemy"""
	var enemies = get_current_enemies()
	if enemies.size() > 0 and enemies[0].has_method("_get_ai_status"):
		return enemies[0]._get_ai_status()
	return false

# REMOVED: Boundary checking teleportation code
# Now we rely on physical walls instead

# Statistics and debugging
func get_game_stats() -> Dictionary:
	"""Get current game statistics"""
	var enemies = get_current_enemies()
	var spawner = get_level_spawner()
	
	return {
		"current_wave": current_wave + 1,
		"active_enemies": enemies.size(),
		"player_health": player.health if player.has_property("health") else 0,
		"player_ammo": player.ammo if player.has_property("ammo") else 0,
		"enemies_remaining_to_spawn": spawner.get_enemies_remaining() if spawner else 0,
		"level_completed": level_completed,
		"game_started": game_started
	}

func print_game_stats():
	"""Print current game statistics for debugging"""
	var stats = get_game_stats()
	print("=== GAME STATS ===")
	for key in stats:
		print(key, ": ", stats[key])
	print("================")

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

func get_game_ui() -> Control:
	return game_ui

# Emergency functions for debugging
func emergency_heal_player():
	"""Emergency function to heal player (for debugging)"""
	if player and player.has_method("heal"):
		player.heal(50)
		print("Emergency heal applied!")

func emergency_add_ammo():
	"""Emergency function to add ammo (for debugging)"""
	if player and player.has_method("add_ammo"):
		player.add_ammo(20)
		print("Emergency ammo added!")

func clear_all_enemies():
	"""Clear all enemies from the scene (for debugging)"""
	var enemies = get_current_enemies()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	print("All enemies cleared!")

# Legacy function names for compatibility
func _on_item_drop_legacy(item_scene: PackedScene):
	_on_item_drop(item_scene)
