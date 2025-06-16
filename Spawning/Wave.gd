# Spawning/Wave.gd - Enhanced wave class for LevelSpawner
extends Node

class_name Wave

# Basic wave properties
@export var num_enemies: int = 3
@export var second_between_spawns: float = 2.0
@export var move_speed: float = 1.0
@export var damage: int = 1
@export var health: float = 10.0

# Drops
@export var DropItem: PackedScene
@export var drop_chance: float = 1.0
@export var drop_when: float = 0.5  # 0 = beginning and 1.0 = end 

# Internal state
var drop_completed = false
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()

func _init():
	# Initialize with default values that can be overridden
	num_enemies = 3
	second_between_spawns = 2.0
	move_speed = 4.0
	damage = 15
	health = 40.0
	drop_chance = 1.0
	drop_when = 0.5
	drop_completed = false
	
func should_drop(num_killed: int) -> bool:
	"""Check if an item should be dropped based on enemies killed"""
	if DropItem and not drop_completed:
		var fraction_killed = float(num_killed) / float(num_enemies)
		if fraction_killed >= drop_when:
			if rng.randf() <= drop_chance:
				drop_completed = true
				return true
	
	return false

func reset_drops():
	"""Reset drop state for wave restart"""
	drop_completed = false

func get_wave_summary() -> String:
	"""Get a string summary of this wave's properties"""
	return "Wave: %d enemies, %.1f HP, %d damage, %.1fs spawn delay" % [num_enemies, health, damage, second_between_spawns]

func configure_progressive_difficulty(wave_number: int):
	"""Configure wave properties based on wave number for progressive difficulty"""
	num_enemies = 3 + (wave_number - 1) * 2  # 3, 5, 7, 9, 11...
	health = 40.0 + (wave_number - 1) * 15.0  # 40, 55, 70, 85, 100...
	damage = 15 + (wave_number - 1) * 5   # 15, 20, 25, 30, 35...
	move_speed = 3.0 + (wave_number - 1) * 0.5  # 3.0, 3.5, 4.0, 4.5, 5.0...
	second_between_spawns = max(1.0, 3.0 - (wave_number - 1) * 0.3)  # 3.0, 2.7, 2.4, 2.1, 1.8...
