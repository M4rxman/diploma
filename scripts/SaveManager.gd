extends Node

const SAVE_PATH = "user://savegame.json"

func save_game(player, enemies):
	var save_data = {
		"player": {
			"position": {
				"x": player.global_transform.origin.x,
				"y": player.global_transform.origin.y,
				"z": player.global_transform.origin.z
			}
		},
		"enemies": []
	}
	
	# Збереження позицій ворогів
	for enemy in enemies:
		save_data["enemies"].append({
			"position": {
				"x": enemy.global_transform.origin.x,
				"y": enemy.global_transform.origin.y,
				"z": enemy.global_transform.origin.z
			}
		})
		
	# Запис у файл
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))  # "\t" робить JSON читабельним
	file.close()
	print("Гра збережена!")


func load_game(player, enemies):  # Додаємо enemy_scene для можливого створення ворогів
	if not FileAccess.file_exists(SAVE_PATH):
		print("Файл збереження відсутній, завантажуємо стандартну сцену.")
		return false  # Немає файлу -> пропускаємо завантаження
	
	# Читання файлу
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()

	if save_data == null or not save_data is Dictionary:
		print("Помилка: Некоректний формат save-файлу!")
		return false

	# Завантаження гравця
	if "player" in save_data and "position" in save_data["player"]:
		var pos = save_data["player"]["position"]
		if "x" in pos and "y" in pos and "z" in pos:
			player.global_transform.origin = Vector3(pos.x, pos.y, pos.z)
		else:
			print("Помилка: Некоректні координати гравця!")

	# Видалити зайвих ворогів, якщо їх більше, ніж у файлі збереження
	while enemies.size() > save_data["enemies"].size():
		enemies.pop_back().queue_free()

	# Завантаження ворогів
	for i in range(save_data["enemies"].size()):
		var enemy_pos = save_data["enemies"][i]["position"]
		if "x" in enemy_pos and "y" in enemy_pos and "z" in enemy_pos:
			if i < enemies.size():
				enemies[i].global_transform.origin = Vector3(enemy_pos.x, enemy_pos.y, enemy_pos.z)
			else:
				print("Немає ворога")
		else:
			print("Помилка: Некоректні координати ворога!")

	print("Гра завантажена!")
	return true
