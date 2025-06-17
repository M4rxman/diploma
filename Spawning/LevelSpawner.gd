# Spawning/LevelSpawner.gd - Fixed with proper supply spawning
extends Node3D

class_name LevelSpawner

@export var enemy_scene: PackedScene = preload("res://scenes/generic_enemy.tscn")
@export var supplies_scene: PackedScene = preload("res://item/Supplies.tscn")

var waves: Array = []
var current_wave: Wave = null
var current_wave_number: int = -1
var enemies_spawned_this_wave: int = 0
var enemies_remaining_to_spawn: int = 0
var wave_completed: bool = false
var all_waves_completed: bool = false
var game_started: bool = false

var navmap: Navigation_Map
var navigation_region: NavigationRegion3D
var spawner_ready: bool = false

# Timer for spawning
var timer: Timer

# Signals
signal wave_update(wave_number: int)
signal level_complete
signal drop_item(item_scene: PackedScene)

func _ready():
	add_to_group("level_spawner")
	
	# Create timer
	timer = Timer.new()
	timer.name = "SpawnerTimer"
	timer.wait_time = 2.0
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	print("LevelSpawner initialized")

func reset():
	"""Reset the spawner for a new level"""
	print("LevelSpawner: Resetting for new level")
	
	# Stop any current spawning
	if timer:
		timer.stop()
	
	# Clear current state
	game_started = false
	all_waves_completed = false
	wave_completed = false
	current_wave_number = -1
	current_wave = null
	enemies_spawned_this_wave = 0
	enemies_remaining_to_spawn = 0
	spawner_ready = false
	
	# Clear existing enemies and supplies
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	var existing_supplies = get_tree().get_nodes_in_group("supplies")
	for supply in existing_supplies:
		if is_instance_valid(supply):
			supply.queue_free()
	
	# Wait a frame for cleanup, then start
	await get_tree().process_frame
	
	# Initialize waves for the new level
	if initialize_waves():
		# Start spawning after a short delay
		await get_tree().create_timer(1.0).timeout
		start_waves()

func initialize_waves():
	"""Find and initialize waves from the navigation map"""
	waves.clear()
	
	# Get reference to navmap if not set
	if not navmap:
		# Try to find it from our parent structure
		var level_manager = get_parent()
		if level_manager:
			for child in level_manager.get_children():
				if child.name == "GeneratedLevel" or child is Navigation_Map:
					navmap = child
					break
	
	if not navmap:
		print("ERROR: No navigation map found for spawner")
		return false
	
	# Find the Waves container
	var waves_container = navmap.get_node_or_null("Waves")
	if not waves_container:
		print("ERROR: Waves container not found")
		return false
	
	print("Found Waves container with ", waves_container.get_child_count(), " children")
	
	# Create wave configurations with progressive difficulty
	var wave_configs = [
		{"enemies": 3, "health": 40.0, "damage": 15, "speed": 3.0, "spawn_delay": 2.0, "drop_supplies": true},
		{"enemies": 2, "health": 70.0, "damage": 25, "speed": 4.0, "spawn_delay": 1.5, "drop_supplies": true},
		{"enemies": 4, "health": 100.0, "damage": 35, "speed": 5.0, "spawn_delay": 1.0, "drop_supplies": false},
		{"enemies": 5, "health": 70.0, "damage": 25, "speed": 4.0, "spawn_delay": 1.5, "drop_supplies": true},
		{"enemies": 6, "health": 100.0, "damage": 35, "speed": 5.0, "spawn_delay": 1.0, "drop_supplies": false}
	]
	
	# Convert configs to Wave objects
	for i in range(wave_configs.size()):
		var config = wave_configs[i]
		var wave_data = Wave.new()
		
		wave_data.num_enemies = config["enemies"]
		wave_data.health = config["health"]
		wave_data.damage = config["damage"]
		wave_data.move_speed = config["speed"]
		wave_data.second_between_spawns = config["spawn_delay"]
		
		# Set drop chance for supplies
		if config.get("drop_supplies", false):
			wave_data.drop_chance = 1.0  # 100% chance to drop supplies
			wave_data.drop_when = 0.8    # Drop when 80% of enemies are killed
		
		waves.append(wave_data)
		print("Initialized Wave ", i + 1, " - Enemies: ", wave_data.num_enemies, " Health: ", wave_data.health)
	
	if waves.size() > 0:
		spawner_ready = true
		print("LevelSpawner ready with ", waves.size(), " waves")
		return true
	else:
		print("ERROR: No waves created!")
		return false

func start_waves():
	"""Start the wave system"""
	if not spawner_ready:
		print("ERROR: Spawner not ready")
		return false
	
	if waves.size() == 0:
		print("ERROR: No waves available")
		return false
	
	game_started = true
	current_wave_number = -1
	all_waves_completed = false
	start_next_wave()
	return true

func start_next_wave():
	"""Start the next wave in sequence"""
	if current_wave_number + 1 >= waves.size():
		complete_all_waves()
		return
	
	current_wave_number += 1
	current_wave = waves[current_wave_number]
	enemies_spawned_this_wave = 0
	enemies_remaining_to_spawn = current_wave.num_enemies
	wave_completed = false
	
	print("Starting Wave ", current_wave_number + 1, "/", waves.size())
	print("   Enemies to spawn: ", current_wave.num_enemies)
	
	# Emit wave started signal
	wave_update.emit(current_wave_number)
	
	# Start spawning timer
	if timer:
		timer.wait_time = current_wave.second_between_spawns
		timer.start()
		print("Spawning timer started")

func _on_timer_timeout():
	"""Called when spawn timer times out"""
	if not game_started or wave_completed or all_waves_completed:
		return
	
	if enemies_remaining_to_spawn <= 0:
		timer.stop()
		print("Wave ", current_wave_number + 1, " spawning complete")
		return
	
	spawn_enemy()

func spawn_enemy():
	"""Spawn a single enemy for the current wave"""
	if not current_wave or not enemy_scene:
		print("ERROR: Cannot spawn enemy - no current wave or enemy scene")
		return
	
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	
	# Set enemy properties based on current wave
	if enemy.has_method("set_health"):
		enemy.set_health(int(current_wave.health))
	elif enemy.get("health") != null:
		enemy.health = int(current_wave.health)
		
	if enemy.has_method("set_damage"):
		enemy.set_damage(current_wave.damage)
	elif enemy.get("attack_damage") != null:
		enemy.attack_damage = current_wave.damage
		
	if enemy.has_method("set_speed"):
		enemy.set_speed(current_wave.move_speed)
	elif enemy.get("TARGET_SPEED") != null:
		enemy.TARGET_SPEED = current_wave.move_speed
	
	# Position enemy at random spawn point
	var spawn_pos = get_random_spawn_position()
	enemy.global_position = spawn_pos
	
	# Enable AI
	if enemy.has_method("_set_ai_to_true"):
		enemy._set_ai_to_true()
	
	# Connect to enemy death signal
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
		print("Connected enemy death signal")
	
	enemies_spawned_this_wave += 1
	enemies_remaining_to_spawn -= 1
	
	print("Spawned enemy ", enemies_spawned_this_wave, "/", current_wave.num_enemies, " at ", spawn_pos)

func _on_enemy_died(enemy):
	"""Handle enemy death and check for supply drops"""
	print("Enemy died! Checking wave completion and supply drops...")
	
	# Brief delay to ensure enemy is processed
	await get_tree().process_frame
	
	var remaining_enemies = get_tree().get_nodes_in_group("enemies").size()
	var spawning_complete = enemies_remaining_to_spawn <= 0
	var enemies_killed = current_wave.num_enemies - remaining_enemies
	
	print("Remaining enemies: ", remaining_enemies, " Spawning complete: ", spawning_complete)
	print("Enemies killed: ", enemies_killed, "/", current_wave.num_enemies)
	
	# Check if supplies should be dropped
	if current_wave and current_wave.has_method("should_drop"):
		if current_wave.should_drop(enemies_killed):
			spawn_supplies_near_player()
	
	# Check if wave is complete
	if spawning_complete and remaining_enemies <= 0:
		complete_current_wave()

func spawn_item_drop(item_scene: PackedScene):
	"""Spawn an item drop at enemy location or random position"""
	if not item_scene:
		# Default to supplies if no specific item
		item_scene = supplies_scene
	if item_scene:
		drop_item.emit(item_scene)  # This will trigger GameManager's handler

func spawn_supplies_near_player():
	"""Spawn supplies near the player at ground level"""
	print("Dropping supplies for the player!")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("No player found for supply drop")
		return
	
	# Find a good spawn position near the player
	var player_pos = player.global_position
	var spawn_attempts = 10
	
	for i in range(spawn_attempts):
		# Try to spawn supplies near player but not too close
		var random_offset = Vector3(
			randf_range(-4, 4),
			0,  # Will be adjusted by physics
			randf_range(-4, 4)
		)
		
		var spawn_pos = player_pos + random_offset
		
		# Make sure it's at a reasonable height (will fall with physics)
		spawn_pos.y = max(spawn_pos.y + 3.0, 5.0)
		
		# Check if position is clear using raycast
		if is_spawn_position_clear(spawn_pos):
			create_supplies_at_position(spawn_pos)
			return
	
	# Fallback: spawn at player position + height
	var fallback_pos = player_pos + Vector3(0, 5, 2)
	create_supplies_at_position(fallback_pos)

func create_supplies_at_position(position: Vector3):
	"""Create supplies at the specified position"""
	if supplies_scene:
		var supplies = supplies_scene.instantiate()
		get_tree().current_scene.add_child(supplies)
		supplies.global_position = position
		print("Supplies spawned at: ", position)
	else:
		# Fallback: create supplies using the static method
		var supplies_script = preload("res://item/Supplies.gd")
		if supplies_script:
			var supplies = supplies_script.create_supplies_at(position, get_tree().current_scene)
			if supplies:
				print("Supplies created via static method at: ", position)

func is_spawn_position_clear(pos: Vector3) -> bool:
	"""Check if spawn position is clear for supplies"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 1,
		pos - Vector3.UP * 3
	)
	query.collision_mask = 1  # Only check static geometry
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()  # Should hit ground

func complete_current_wave():
	"""Complete current wave and start next one"""
	wave_completed = true
	timer.stop()
	
	print("Wave ", current_wave_number + 1, " completed!")
	
	# Brief pause before next wave
	await get_tree().create_timer(2.0).timeout
	
	spawn_wave_completion_supplies()
	# Start next wave
	start_next_wave()

func complete_all_waves():
	"""Called when all waves are completed"""
	all_waves_completed = true
	timer.stop()
	
	print("ALL WAVES COMPLETED!")
	level_complete.emit()

func get_random_spawn_position() -> Vector3:
	"""Get a random valid spawn position"""
	var spawn_pos: Vector3
	
	if navmap and navmap.has_method("get_random_empty_vec3"):
		spawn_pos = navmap.get_random_empty_vec3()
		# Ensure enemies spawn well above ground
		spawn_pos.y = 3.0
		return spawn_pos
	
	# Fallback to basic random positioning
	for i in range(10):  # Max 10 attempts
		var x = randf_range(-15, 15)
		var z = randf_range(-15, 15)
		spawn_pos = Vector3(x, 3.0, z)  # Higher spawn height
		
		if is_position_clear(spawn_pos):
			return spawn_pos
	
	# Final fallback with higher spawn
	return Vector3(randf_range(-10, 10), 3.0, randf_range(-10, 10))

func is_position_clear(pos: Vector3) -> bool:
	"""Check if spawn position is clear of obstacles"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 2,
		pos - Vector3.UP * 1
	)
	query.collision_mask = 1  # Only check static bodies/walls
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()  # Should hit ground

# Add this new function:
func spawn_wave_completion_supplies():
	"""Spawn supplies after wave completion"""
	if not supplies_scene:
		print("ERROR: No supplies scene assigned!")
		return

	# Get player position for reference
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Spawn 1-3 supply crates
	var num_supplies = randi_range(1, 3)

	for i in range(num_supplies):
		var supplies = supplies_scene.instantiate()
		get_tree().current_scene.add_child(supplies)

		# Position near player but not too close
		var spawn_offset = Vector3(
		randf_range(-8, 8),
		3.0,  # Drop from above
		randf_range(-8, 8)
		)

		# Make sure it's not too close to player
		if spawn_offset.length() < 4.0:
			spawn_offset = spawn_offset.normalized() * 4.0
		supplies.global_position = player.global_position + spawn_offset
			
		print("Spawned supplies at: ", supplies.global_position)

# Getter methods
func get_enemies_remaining() -> int:
	return enemies_remaining_to_spawn

func get_current_wave_number() -> int:
	return current_wave_number

func get_total_waves() -> int:
	return waves.size()

func is_spawner_ready() -> bool:
	return spawner_ready
