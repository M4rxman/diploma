extends Node

class_name Wave

@export var num_enemies: int = 3
@export var second_between_spawns: float = 2.0
@export var move_speed: float = 1.0
@export var damage: int = 1
@export var health: float = 10.0

# Drops
@export var DropItem: PackedScene
@export var drop_chance: float = 1.0
@export var drop_when: float = 0.5  # 0 = beginning and 1.0 = end 

var drop_completed = false
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
func should_drop(num_killed):
	if DropItem and not drop_completed:
		var fraction_killed = float(num_killed)/float(num_enemies)
		if fraction_killed >= drop_when:
			if rng.randf() <= drop_chance:
				drop_completed = true
				return true
	
	return false
