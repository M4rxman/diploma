# Spawning/LevelSpawner.gd - Fixed with proper reset method
extends Node3D

class_name LevelSpawner

@export var enemy_scene: PackedScene = preload("res://scenes/generic_enemy.tscn")

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
	
	# Clear existing enemies
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
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
		{"enemies": 3, "health": 40.0, "damage": 15, "speed": 3.0, "spawn_delay": 2.0},
		{"enemies": 5, "health": 55.0, "damage": 20, "speed": 3.5, "spawn_delay": 1.8},
		{"enemies": 7, "health": 70.0, "damage": 25, "speed": 4.0, "spawn_delay": 1.5},
		{"enemies": 10, "health": 85.0, "damage": 30, "speed": 4.5, "spawn_delay": 1.2},
		{"enemies": 12, "health": 100.0, "damage": 35, "speed": 5.0, "spawn_delay": 1.0}
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
	
	print("🌊 Starting Wave ", current_wave_number + 1, "/", waves.size())
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
	"""Handle enemy death"""
	print("Enemy died! Checking wave completion...")
	
	# Brief delay to ensure enemy is processed
	await get_tree().process_frame
	
	var remaining_enemies = get_tree().get_nodes_in_group("enemies").size()
	var spawning_complete = enemies_remaining_to_spawn <= 0
	
	print("Remaining enemies: ", remaining_enemies, " Spawning complete: ", spawning_complete)
	
	# Check if wave is complete
	if spawning_complete and remaining_enemies <= 0:
		complete_current_wave()

func complete_current_wave():
	"""Complete current wave and start next one"""
	wave_completed = true
	timer.stop()
	
	print("Wave ", current_wave_number + 1, " completed!")
	
	# Brief pause before next wave
	await get_tree().create_timer(2.0).timeout
	
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
	query.collision_mask = 1  # Only check static geometry
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()  # Should hit ground

# Getter methods
func get_enemies_remaining() -> int:
	return enemies_remaining_to_spawn

func get_current_wave_number() -> int:
	return current_wave_number

func get_total_waves() -> int:
	return waves.size()

func is_spawner_ready() -> bool:
	return spawner_ready
