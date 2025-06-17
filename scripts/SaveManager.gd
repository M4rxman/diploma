# scripts/SaveManager.gd
extends Node

const SAVE_PATH = "user://savegame.json"

func save_game(player, enemies, level_seed: int = 0, level_settings: Dictionary = {}):
	var save_data = {
		"player": {
			"position": {
				"x": player.global_transform.origin.x,
				"y": player.global_transform.origin.y,
				"z": player.global_transform.origin.z
			},
			"health": player.health if player.get("health") else 100
		},
		"enemies": [],
		"level": {
			"seed": level_seed,
			"settings": level_settings,
			"timestamp": Time.get_unix_time_from_system()
		},
		"game_state": {
			"current_wave": 0,
			"score": 0  # Add scoring system later if needed
		}
	}
	
	# Save enemy positions and states
	for enemy in enemies:
		if is_instance_valid(enemy):
			save_data["enemies"].append({
				"position": {
					"x": enemy.global_transform.origin.x,
					"y": enemy.global_transform.origin.y,
					"z": enemy.global_transform.origin.z
				},
				"health": enemy.health if enemy.get("health") else 100,
				"ai_active": enemy.ai_is_active if enemy.get("ai_is_active") else true
			})
	
	# Write to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Game saved! Level seed: ", level_seed)
		return true
	else:
		print("Failed to save game - could not open file")
		return false

func load_game(player, enemies) -> Dictionary:
	"""Load game and return level data for regeneration"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("Save file not found")
		return {}
	
	# Read file
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		print("Could not open save file")
		return {}
		
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()

	if save_data == null or not save_data is Dictionary:
		print("Invalid save file format")
		return {}

	# Load player data
	if "player" in save_data:
		var player_data = save_data["player"]
		if "position" in player_data:
			var pos = player_data["position"]
			if "x" in pos and "y" in pos and "z" in pos:
				player.global_transform.origin = Vector3(pos.x, pos.y, pos.z)
				print("Player position loaded: ", Vector3(pos.x, pos.y, pos.z))
		
		if "health" in player_data and player.get("health"):
			player.health = player_data["health"]

	# Handle enemies - clear excess enemies
	while enemies.size() > save_data.get("enemies", []).size():
		var enemy = enemies.pop_back()
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Load enemy data
	var enemy_data_list = save_data.get("enemies", [])
	for i in range(enemy_data_list.size()):
		var enemy_data = enemy_data_list[i]
		if i < enemies.size() and is_instance_valid(enemies[i]):
			var enemy = enemies[i]
			
			# Load position
			if "position" in enemy_data:
				var pos = enemy_data["position"]
				if "x" in pos and "y" in pos and "z" in pos:
					enemy.global_transform.origin = Vector3(pos.x, pos.y, pos.z)
			
			# Load health
			if "health" in enemy_data and enemy.get("health"):
				enemy.health = enemy_data["health"]
			
			# Load AI state
			if "ai_active" in enemy_data:
				if enemy_data["ai_active"] and enemy.has_method("_set_ai_to_true"):
					enemy._set_ai_to_true()
				elif not enemy_data["ai_active"] and enemy.has_method("_set_ai_to_false"):
					enemy._set_ai_to_false()

	print("Game loaded successfully!")
	
	# Return level data for regeneration
	return save_data.get("level", {})

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save_file():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")

func get_save_info() -> Dictionary:
	"""Get info about save file without loading it"""
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
		
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if save_data and "level" in save_data:
		return save_data["level"]
	return {}
