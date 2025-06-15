# Spawning/LevelSpawner.gd
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
	# Create timer if it doesn't exist
	if not timer:
		timer = Timer.new()
		timer.name = "SpawnerTimer"
		add_child(timer)
		timer.timeout.connect(_on_timer_timeout)
		print("LevelSpawner: Created timer")
	
	# Small delay before starting first wave
	await get_tree().create_timer(1.0).timeout
	
	if waves.size() > 0:
		print("LevelSpawner: Starting first wave with ", waves.size(), " total waves")
		start_next_wave()
	else:
		print("LevelSpawner: No waves found! Creating default wave.")
		create_default_wave()

func create_default_wave():
	"""Create a default wave if none exist"""
	var default_wave = Wave.new()
	default_wave.num_enemies = 3
	default_wave.second_between_spawns = 2.0
	default_wave.move_speed = 2.0
	default_wave.damage = 20
	default_wave.health = 100
	waves = [default_wave]
	start_next_wave()

func start_next_wave():
	if current_wave_number >= waves.size() - 1:
		# All waves completed
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
		# Level complete
		print("LevelSpawner: Level completed!")
		level_complete.emit()

func reset():
	"""Reset spawner to beginning"""
	current_wave_number = -1
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
	# Small delay before starting
	await get_tree().create_timer(0.5).timeout
	start_next_wave()

func spawn_enemy():
	if not enemy_scene:
		print("LevelSpawner: No enemy scene assigned!")
		return
	
	if not navmap:
		print("LevelSpawner: No navigation map assigned!")
		return
	
	# Spawn enemy
	var enemy = enemy_scene.instantiate()
	
	# Set enemy characteristics based on wave
	if enemy.has_method("set_health"):
		enemy.set_health(current_wave.health)
	elif enemy.get("health"):
		enemy.health = current_wave.health
		
	if enemy.has_method("set_damage"):
		enemy.set_damage(current_wave.damage)
	elif enemy.get("damage"):
		enemy.damage = current_wave.damage
		
	if enemy.has_method("set_speed"):
		enemy.set_speed(current_wave.move_speed)
	elif enemy.get("TARGET_SPEED"):
		enemy.TARGET_SPEED = current_wave.move_speed
	
	# Get spawn position
	var location: Vector3 = navmap.get_random_empty_vec3()
	enemy.global_position = location + Vector3(0, 1, 0)
	
	# Add enemy to scene
	var scene_root = get_tree().current_scene
	scene_root.add_child(enemy)
	
	# Enable AI
	if enemy.has_method("_set_ai_to_true"):
		enemy._set_ai_to_true()
		print("LevelSpawner: Enabled AI for enemy at ", location)
	
	# Add to group
	enemy.add_to_group("enemies")
	
	# Connect to enemy death
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
	active_enemies.append(enemy)
	enemies_remaining_to_spawn -= 1
	
	print("LevelSpawner: Spawned enemy. Remaining: ", enemies_remaining_to_spawn, " Active: ", active_enemies.size())

func _on_enemy_died(enemy):
	active_enemies.erase(enemy)
	enemies_killed_this_wave += 1
	print("LevelSpawner: Enemy died. Killed: ", enemies_killed_this_wave, " Active: ", active_enemies.size())
	
	# Check if item should drop
	if current_wave and current_wave.should_drop(enemies_killed_this_wave):
		drop_item.emit(current_wave.DropItem)
		print("LevelSpawner: Item dropped!")
	
	# Check if wave is complete
	if enemies_remaining_to_spawn == 0 and active_enemies.is_empty():
		print("LevelSpawner: Wave complete! Starting next wave...")
		await get_tree().create_timer(2.0).timeout  # Brief pause between waves
		start_next_wave()

func _on_timer_timeout():
	if enemies_remaining_to_spawn > 0:
		spawn_enemy()
	else:
		timer.stop()
		print("LevelSpawner: Finished spawning enemies for this wave")

func get_enemies_remaining() -> int:
	return enemies_remaining_to_spawn

func get_active_enemy_count() -> int:
	return active_enemies.size()

func get_current_wave_number() -> int:
	return current_wave_number + 1  # +1 for display purposes
