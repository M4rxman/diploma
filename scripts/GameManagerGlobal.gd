# res://scripts/GameManagerGlobal.gd
extends Node

var scene_game_manager: Node = null


func set_scene_game_manager(node: Node):
	scene_game_manager = node


func get_targets() -> Array[Node]:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var interactables := get_tree().get_nodes_in_group("interact")
	enemies.append_array(interactables)
	return enemies


func get_player() -> Node:
	if scene_game_manager:
		return scene_game_manager.get_node("Player")
	return null
