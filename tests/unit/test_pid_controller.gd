extends GutTest

# Import the PID class
const Pid3D = preload("res://scripts/pid_3d.gd")

func test_pid_controller():
	var pid = Pid3D.new(10.0, 0.1, 1.0)  # Example PID values
	var error = Vector3(5, 0, 0)
	var output = pid.update(error, 1.0)
	
	# Check if output is in expected range
	assert_true(output.length() > 0, "PID output should be greater than zero")
	assert_true(output.x > 0, "PID should correct in positive X direction")
