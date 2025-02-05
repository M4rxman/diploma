extends GutTest

var main_scene  # Основна сцена
var save_manager
var player
var enemies = []
var enemy_scene = preload("res://scenes/generic_enemy.tscn")  # Ворог як окрема сцена
var instantiated_objects = []  # Track objects created during the test

func before_each():
	# Завантажуємо основну сцену
	var main_scene_resource = preload("res://scenes/Main_scene.tscn")  # Шлях до вашої основної сцени
	main_scene = main_scene_resource.instantiate()
	get_tree().root.add_child(main_scene)  # Додаємо основну сцену до дерева сцени

	# Ініціалізуємо SaveManager
	save_manager = preload("res://scripts/SaveManager.gd").new()

	# Знаходимо гравця у сцені
	player = main_scene.get_node("Player")  # Замініть "Player" на шлях до вашого гравця
	assert(player != null, "Не вдалося знайти гравця в основній сцені")
	
	main_scene._turn_off_enemy_ai()
	# Очищуємо список ворогів
	enemies.clear()

func after_each():
	# Clean up instantiated objects
	for obj in instantiated_objects:
		if obj.is_inside_tree():
			obj.queue_free()
	instantiated_objects.clear()

	# Remove main scene
	if main_scene.is_inside_tree():
		main_scene.queue_free()


func test_save_game():
	# Переміщуємо гравця
	player.global_transform.origin = Vector3(1, 2, 3)
	
	# Створюємо ворога
	var enemy = enemy_scene.instantiate()
	main_scene.add_child(enemy)  # Додаємо ворога до дерева сцени
	instantiated_objects.append(enemy)  # Track the instantiated enemy
	await get_tree().get_frame() # Чекаємо оновлення дерева сцени

	# Встановлюємо позицію ворога
	enemy.global_transform.origin = Vector3(4, 5, 6)
	enemies.append(enemy)

	# Зберігаємо гру
	save_manager.save_game(player, enemies)

	# Перевіряємо збережений файл
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	assert(file != null, "Файл не створено")
	var data = JSON.parse_string(file.get_as_text())

	# Перевірка позицій гравця та ворогів
	assert_true(
		abs(data["player"]["position"]["x"] - 1.0) < 0.001 and 
		abs(data["player"]["position"]["y"] - 2.0) < 0.001 and 
		abs(data["player"]["position"]["z"] - 3.0) < 0.001, 
		"Коректні координати гравця"
	)
	assert_true(
		abs(data["enemies"][0]["position"]["x"] - 4.0) < 0.001 and 
		abs(data["enemies"][0]["position"]["y"] - 5.0) < 0.001 and 
		abs(data["enemies"][0]["position"]["z"] - 6.0) < 0.001, 
		"Коректні координати ворога"
	)


## Тестування load_game()
func test_load_game():
	# Створюємо збережений файл вручну
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"player": { "position": { "x": 10, "y": 0, "z": -5 } },
		"enemies": [{ "position": { "x": 3, "y": 1, "z": 4 } }]
	}))
	file.close()
	
	# Завантажуємо гру
	save_manager.load_game(player, enemies)
	
	var enemy = enemy_scene.instantiate()
	await get_tree().get_frame()
	enemy.global_transform.origin = Vector3(0, 0, 0)
	
	# Перевіряємо координати гравця
	assert_eq(player.global_transform.origin, Vector3(10, 0, -5), "Гравець не змінив позицію")
	
	# Перевіряємо позицію ворога
	assert_eq(enemy.global_transform.origin, Vector3(0, 0, 0), "Ворог не завантажив позицію")

## Тестування атаки ворога
func test_attack_enemy():
	# Створюємо ворога
	main_scene._turn_on_enemy_ai()
	var enemy = enemy_scene.instantiate()
	enemy.health = 50
	main_scene.add_child(enemy)
	enemy.global_transform.origin = Vector3(1, 1, 1)  # Додаємо ворога до основної сцени
	enemies.append(enemy)

	# Атакуємо ворога
	player.global_transform.origin == Vector3(1, 1, 0)
	player._attack()  # Викликаємо атаку гравця
	assert_true(enemy.health < 50, "Здоров'я ворога не зменшилося")
	
	# Перевіряємо, чи видалено ворога
	if enemy.health <= 0:
		assert_true(!enemy.is_inside_tree(), "Мертвий ворог не видалений")

## Тестування стрибка гравця
func test_player_jump():
	player.is_on_floor = true
	var initial_y = player.global_transform.origin.y

	# Імітуємо стрибок
	player._jump()  # Переконайтесь, що метод _jump() реалізований у Player.gd
	assert_gte(player.global_transform.origin.y, initial_y, "Гравець піднявся")

	# Перевіряємо, чи не можна стрибнути у повітрі
	player.is_on_floor = false
	var prev_y = player.global_transform.origin.y
	player._jump()
	assert_true(player.global_transform.origin.y == prev_y, "Гравець не повинен стрибати у повітрі")

## Тестування перемоги
func test_check_victory():
	# Ситуація без ворогів
	enemies.clear()
	assert_true(save_manager.check_victory() == "You win!", "Перемога не зафіксована")

	# Додаємо ворога
	var enemy = enemy_scene.instantiate()
	main_scene.add_child(enemy)
	enemies.append(enemy)
	assert_true(save_manager.check_victory() == "Game continues", "Перемога не повинна спрацьовувати, поки вороги є")
