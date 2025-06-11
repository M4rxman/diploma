extends Node3D

class_name LevelSpawner

@export var enemy_scene: PackedScene  # Use your generic_enemy.tscn
@onready var timer = $Timer
var navmap: NavigationMap:
	set(value):
		navmap = value
		if navmap:
			waves = navmap.get_waves()

var enemies_remaining_to_spawn
var enemies_killed_this_wave

var waves # list of all the Wave nodes: [ Wave, Wave1, Wave2, ... ]
var current_wave: Wave # Wave node
var current_wave_number = -1
var active_enemies = []

signal level_complete
signal wave_update(wave_number: int)
signal drop_item(item_scene: PackedScene)

func _ready():
	if not timer:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)
		timer.timeout.connect(_on_timer_timeout)

func start_next_wave():
	enemies_killed_this_wave = 0
	current_wave_number += 1
	if current_wave_number < waves.size():
		wave_update.emit(current_wave_number)
		current_wave = waves[current_wave_number]
		enemies_remaining_to_spawn = current_wave.num_enemies
		timer.wait_time = current_wave.second_between_spawns
		timer.start()
		
		if current_wave.should_drop(enemies_killed_this_wave):
			drop_item.emit(current_wave.DropItem)
	else:
		# Level complete
		level_complete.emit()
		
func reset():
	current_wave_number = -1
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	start_next_wave()
	
func spawn_enemy():
	if not enemy_scene:
		push_error("Enemy scene not set!")
		return
		
	# SPAWN!
	var enemy = enemy_scene.instantiate()
	
	# Set enemy characteristics based on wave
	if enemy.has_method("set_health"):
		enemy.set_health(current_wave.health)
	if enemy.has_method("set_damage"):
		enemy.set_damage(current_wave.damage)
	if enemy.has_method("set_speed"):
		enemy.set_speed(current_wave.move_speed)
	
	# Give the enemy a random position, that is NOT in an obstacle
	var location: Vector3 = navmap.get_random_empty_vec3()
	enemy.global_position = location + Vector3(0, 1, 0)  # Spawn slightly above ground
	
	# Add enemy to scene
	var scene_root = get_tree().current_scene
	scene_root.add_child(enemy)
	
	# Enable AI
	if enemy.has_method("_set_ai_to_true"):
		enemy._set_ai_to_true()
	
	# Connect to enemy signals
	connect_to_enemy_signals(enemy)
	
	active_enemies.append(enemy)
	enemies_remaining_to_spawn -= 1
	
func connect_to_enemy_signals(enemy):
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
func _on_enemy_died(enemy):
	active_enemies.erase(enemy)
	enemies_killed_this_wave += 1
	print("Enemies killed: ", enemies_killed_this_wave)
	
	# Check if item should drop
	if current_wave.should_drop(enemies_killed_this_wave):
		drop_item.emit(current_wave.DropItem)
		print("DROPPING!!!")
	
	# Check if wave is complete
	if enemies_remaining_to_spawn == 0 and active_enemies.is_empty():
		start_next_wave()
	
func _on_timer_timeout():
	if enemies_remaining_to_spawn > 0:
		spawn_enemy()
	else:
		timer.stop()
