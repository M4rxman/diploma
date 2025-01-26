extends RigidBody3D

const TARGET_SPEED = 6.5
const TARGET_GRAVITY = -1.0

var dodge_ready = true
var velocity: Vector3 = Vector3.ZERO
var _pid := Pid3D.new(75.0, 0.1, 2.5)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _physics_process(delta: float) -> void:
	# Movement
	var direction = Vector3(
		Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
		-0.0,
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	).normalized()
	var target_velocity = direction * TARGET_SPEED
	var velocity_error = target_velocity - linear_velocity
	var correction_impulse = _pid.update(velocity_error, delta) * 0.01
	apply_impulse(correction_impulse)
	
	
	
	
	# Get input directions
	var input := Vector3.ZERO
		# Jumping logic
	if  Input.is_action_just_pressed("jump") and dodge_ready:  # Replace with your jump action
		dodge_ready = false
		$Timer.start()
		print("pressed Space")
		print(dodge_ready)
		input.y += 100.0
		
		if Input.is_action_pressed("move_forward"):
			print("moved f")
			input.z += 2
		if Input.is_action_pressed("move_back"):
			print("moved b")
			input.z -= 2
		if Input.is_action_pressed("move_left"):
			print("moved l")
			input.x += 2
		if Input.is_action_pressed("move_right"):
			print("moved r")
			input.x -= 2
	  
	# Normalize direction to prevent faster diagonal movement
	input = input.normalized()
	
	# Apply velocity
	apply_impulse(input * 100.0 * delta)


func _on_timer_timeout() -> void:
	dodge_ready = true
