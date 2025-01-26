extends Node3D

var ray_origin = Vector3()
var ray_target = Vector3()

func _physics_process(delta: float) -> void:
	var mouse_position = get_viewport().get_mouse_position()
	ray_origin = $Camera3D.project_ray_origin(mouse_position)
	#print("ray_origin", mouse_position)
	ray_target = ray_origin + $Camera3D.project_ray_normal(mouse_position) * 2000
	
	var space_state = get_world_3d().direct_space_state
	var ray_intersection = PhysicsRayQueryParameters3D.new()
	ray_intersection.from = ray_origin
	ray_intersection.to = ray_target
	var intersection = space_state.intersect_ray(ray_intersection)
	
	if not intersection.is_empty():
		var pos = intersection.position
		var horizontal_stabilization =  Vector3(pos.x, $Character3D.position.y, pos.z)
		$Character3D/Cursor.look_at(horizontal_stabilization, Vector3.UP)
		
