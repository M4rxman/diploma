extends RigidBody3D

@onready var feet = $Feet

const TARGET_SPEED = 8.0
const TARGET_JUMP = 70.0
const TARGET_GRAVITY = 200.0

var dodge_ready = true
var is_on_floor = true 
var is_on_slope = false

var _pid := Pid3D.new(30.0, 0.05, 2.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	# Movement
	var direction = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	).normalized()
	var target_velocity = direction * TARGET_SPEED
	var velocity_error = target_velocity - linear_velocity
	var correction_impulse = _pid.update(velocity_error, delta) * 0.01
	apply_impulse(correction_impulse)
	
	# Jumping logic
	if Input.is_action_just_pressed("jump"): 
		if is_on_floor:
			apply_impulse(Vector3(0.0, TARGET_JUMP, 0.0))
			is_on_floor = false  # Ensure the player isn't marked as "on floor" immediately
			print("Jumped")


func _on_timer_timeout() -> void:
	dodge_ready = true

func _apply_gravity(delta: float) -> void:
	if feet.is_colliding():
		is_on_floor = true
	else:
		is_on_floor = false
		# Apply a stronger gravity impulse to ensure falling  
		apply_impulse(Vector3(0.0, -TARGET_GRAVITY, 0.0) * delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Artificial stopping when no movement input
	var move_input = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	
	# Define stop speed (tweak as necessary)
	var stop_speed = 0.4
	
	if move_input.length() < 0.2:
		state.linear_velocity.x = lerp(state.linear_velocity.x, 0.0, stop_speed)
		state.linear_velocity.z = lerp(state.linear_velocity.z, 0.0, stop_speed)

	# Slope resistance (push against unreasonable slopes)
	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			var contact_normal = state.get_contact_local_normal(i)
			
			# If on floor and slope is too steep (y < 0.9), counteract sliding
			if is_on_floor and contact_normal.y < 0.8:
				apply_central_force(-contact_normal * 20)
