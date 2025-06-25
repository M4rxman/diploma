## A proportional–integral–derivative controller (PID controller or three-term controller).
## Extends RefCounted for lightweight reference counting.
extends RefCounted
class_name Pid3D

## Proportional gain coefficient (P term).
var _p: float
## Integral gain coefficient (I term).
var _i: float
## Derivative gain coefficient (D term).
var _d: float

## Previous error vector used to compute derivative term.
var _prev_error: Vector3
## Accumulated integral of error over time.
var _error_integral: Vector3


## Constructor: initializes PID coefficients.
## @param p: Proportional gain.
## @param i: Integral gain.
## @param d: Derivative gain.
func _init(p: float, i: float, d: float) -> void:
	_p = p
	_i = i
	_d = d


## Updates the controller state and computes control output.
##
## Calculates the proportional, integral, and derivative contributions based on the
## current error and elapsed time, then returns the combined control vector.
##
## @param error: Current error vector (target - actual).
## @param delta: Time step since last update (seconds).
## @return: Control output vector = P*error + I*integral + D*derivative.
func update(error: Vector3, delta: float) -> Vector3:
	_error_integral += error * delta
	var error_derivative = (error - _prev_error) / delta
	_prev_error = error
	return _p * error + _i * _error_integral + _d * error_derivative
