extends RigidBody3D

@onready var feet = $Feet
@onready var nav_agent = $NavigationAgent3D
@export var ai_is_active = false

const TARGET_SPEED = 4.0
const TARGET_JUMP = 70.0
const TARGET_GRAVITY = 200.0
const MAX_HEALTH = 100

var target: Node3D  # The player reference
var is_on_floor = true 
var _pid := Pid3D.new(25.0, 0.1, 1.0)
var health: int = MAX_HEALTH  # Enemy health

func _ready() -> void:
	# Auto-find the player in the scene
	
	target = get_tree().get_first_node_in_group("player")
	if not has_node("NavigationAgent3D"):
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
		
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_max_distance = 1.0
	
	
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if not target or !ai_is_active:
		return
	
	# Use NavigationAgent3D for pathfinding
	nav_agent.target_position = target.global_position

	if nav_agent.is_navigation_finished():
		return

	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Get movement direction toward the player
	#var direction = (target.global_transform.origin - global_transform.origin).normalized()
	var target_velocity = direction * TARGET_SPEED
	var velocity_error = target_velocity - linear_velocity
	var correction_impulse = _pid.update(velocity_error, delta) * 0.01
	apply_impulse(correction_impulse)
	
	# Jumping if needed
	if is_on_floor and global_transform.origin.distance_to(target.global_transform.origin) > 2.0:
		apply_impulse(Vector3(0.0, TARGET_JUMP, 0.0))
		is_on_floor = false

func _apply_gravity(delta: float) -> void:
	if feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false
		apply_impulse(Vector3(0.0, -TARGET_GRAVITY, 0.0) * delta)

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)

	if health <= 0:
		die()

func die() -> void:
	print("Enemy defeated!")
	queue_free()  # Removes the enemy from the scene

	# Check if all enemies are defeated
	if get_tree().get_nodes_in_group("enemies").is_empty():
		print("You win!")

func _set_ai_to_false() -> void:
	ai_is_active = false
	
func _set_ai_to_true() -> void:
	ai_is_active = true
	
func _get_ai_status() -> bool:
	return ai_is_active
