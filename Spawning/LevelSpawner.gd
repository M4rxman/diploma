# Spawning/LevelSpawner.gd - Fixed wave completion detection
extends Node3D

class_name LevelSpawner

@export var enemy_scene: PackedScene
@onready var timer: Timer

var navmap: Navigation_Map:
	set(value):
		navmap = value
		if navmap:
			waves = navmap.get_waves()

var enemies_remaining_to_spawn: int = 0
var enemies_killed_this_wave: int = 0

var waves: Array = []
var current_wave: Wave
var current_wave_number: int = -1
var active_enemies: Array = []

signal level_complete
signal wave_update(wave_number: int)
signal drop_item(item_scene: PackedScene)

func _ready():
	# Create timer
	if not timer:
		timer = Timer.new()
		timer.name = "SpawnerTimer"
		add_child(timer)
		timer.timeout.connect(_on_timer_timeout)
		print("LevelSpawner: Created timer")
	
	# Wait a bit before starting
	await get_tree().create_timer(1.0).timeout
	
	if waves.size() > 0:
		print("LevelSpawner: Starting first wave with ", waves.size(), " total waves")
		start_next_wave()
	else:
		print("LevelSpawner: No waves found! Creating default wave.")
		create_default_wave()

func create_default_wave():
	var default_wave = Wave.new()
	default_wave.num_enemies = 3
	default_wave.second_between_spawns = 2.0
	default_wave.move_speed = 3.0
	default_wave.damage = 20
	default_wave.health = 100
	waves = [default_wave]
	start_next_wave()

func start_next_wave():
	if current_wave_number >= waves.size() - 1:
		print("LevelSpawner: All waves completed!")
		level_complete.emit()
		return
	
	enemies_killed_this_wave = 0
	current_wave_number += 1
	
	if current_wave_number < waves.size():
		wave_update.emit(current_wave_number)
		current_wave = waves[current_wave_number]
		enemies_remaining_to_spawn = current_wave.num_enemies
		
		print("LevelSpawner: Starting wave ", current_wave_number + 1, " with ", enemies_remaining_to_spawn, " enemies")
		
		timer.wait_time = current_wave.second_between_spawns
		timer.start()
		
		# Check for item drops
		if current_wave.should_drop(enemies_killed_this_wave):
			drop_item.emit(current_wave.DropItem)
	else:
		print("LevelSpawner: Level completed!")
		level_complete.emit()

func reset():
	current_wave_number = -1
	
	# Clear existing enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
	await get_tree().create_timer(0.5).timeout
	start_next_wave()

func spawn_enemy():
	if not enemy_scene:
		print("LevelSpawner: No enemy scene assigned!")
		return
	
	if not navmap:
		print("LevelSpawner: No navigation map assigned!")
		return
	
	# Get spawn position
	var location: Vector3 = navmap.get_random_empty_vec3()
	
	# Create enemy
	var enemy = enemy_scene.instantiate()
	
	# Set enemy characteristics
	if enemy.has_method("set_health"):
		enemy.set_health(current_wave.health)
	elif enemy.get("health") != null:
		enemy.health = current_wave.health
		
	if enemy.has_method("set_damage"):
		enemy.set_damage(current_wave.damage)
	elif enemy.get("damage") != null:
		enemy.damage = current_wave.damage
		
	if enemy.has_method("set_speed"):
		enemy.set_speed(current_wave.move_speed)
	elif enemy.get("TARGET_SPEED") != null:
		enemy.TARGET_SPEED = current_wave.move_speed
	
	# Position enemy
	enemy.global_position = location + Vector3(0, 1, 0)
	
	# Add to scene
	var scene_root = get_tree().current_scene
	scene_root.add_child(enemy)
	
	# Enable AI
	if enemy.has_method("_set_ai_to_true"):
		enemy._set_ai_to_true()
		print("LevelSpawner: Enabled AI for enemy at ", location)
	
	# Add to groups
	enemy.add_to_group("enemies")
	
	# IMPORTANT: Connect to enemy death signal
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
		print("LevelSpawner: Connected to enemy death signal")
	else:
		print("LevelSpawner: WARNING - Enemy has no 'died' signal!")
	
	active_enemies.append(enemy)
	enemies_remaining_to_spawn -= 1
	
	print("LevelSpawner: Spawned enemy. Remaining to spawn: ", enemies_remaining_to_spawn, " Active: ", active_enemies.size())

func _on_enemy_died(enemy):
	"""Handle enemy death - CRITICAL for wave progression"""
	print("LevelSpawner: Enemy died! Processing...")
	
	# Remove from active list
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	
	enemies_killed_this_wave += 1
	
	print("LevelSpawner: Enemy removed. Killed this wave: ", enemies_killed_this_wave, " Active remaining: ", active_enemies.size())
	
	# Check for item drops
	if current_wave and current_wave.should_drop(enemies_killed_this_wave):
		if current_wave.DropItem:
			drop_item.emit(current_wave.DropItem)
			print("LevelSpawner: Item dropped!")
	
	# IMPORTANT: Check if wave is complete
	var all_spawned = (enemies_remaining_to_spawn <= 0)
	var all_dead = (active_enemies.size() == 0)
	
	print("LevelSpawner: Wave check - All spawned: ", all_spawned, " All dead: ", all_dead)
	
	if all_spawned and all_dead:
		print("LevelSpawner: Wave ", current_wave_number + 1, " completed! Starting next wave...")
		await get_tree().create_timer(2.0).timeout  # Brief pause
		start_next_wave()

func _on_timer_timeout():
	if enemies_remaining_to_spawn > 0:
		spawn_enemy()
	else:
		timer.stop()
		print("LevelSpawner: Finished spawning all enemies for this wave")

func get_enemies_remaining() -> int:
	return enemies_remaining_to_spawn

func get_active_enemy_count() -> int:
	# Clean up invalid enemies from list
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	return active_enemies.size()

func get_current_wave_number() -> int:
	return current_wave_number + 1

# Debug function to force wave completion
func debug_complete_wave():
	print("DEBUG: Force completing current wave")
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	enemies_remaining_to_spawn = 0
	_on_enemy_died(null)  # Trigger wave completion check
