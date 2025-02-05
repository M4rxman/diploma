extends Node3D

@onready var player = $Player
@onready var enemies = get_tree().get_nodes_in_group("enemies")
@onready var save_manager = $SaveManager

var ray_origin = Vector3()
var ray_target = Vector3()

func _ready():
	if not save_manager.load_game(player, enemies):
		print("Запускаємо гру з початковими параметрами.")

func _input(event):
	if event.is_action_pressed("save_game"):
		save_manager.save_game(player, enemies)
	elif event.is_action_pressed("load_game"):
		if not save_manager.load_game(player, enemies):
			print("Завантаження не вдалося. Гра починається з нуля.")

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
		var horizontal_stabilization =  Vector3(pos.x, $Player.position.y, pos.z)
		$Player/Cursor.look_at(horizontal_stabilization, Vector3.UP)
		

func _turn_off_enemy_ai() -> bool:
	if $Generic_enemy._get_ai_status():
		$Generic_enemy._set_ai_to_false()
		return $Generic_enemy._get_ai_status()
	else:
		return true
		
func _turn_on_enemy_ai() -> bool:
	if !$Generic_enemy._get_ai_status():
		$Generic_enemy._set_ai_to_true()
		return $Generic_enemy._get_ai_status()
	else:
		return false
