# Архітектура проекту

## Огляд системи

Проект використовує модульну архітектуру з чітким розділенням відповідальностей:

### Основні компоненти

1. **GameManager** - центральний координатор
   - Управління станом гри
   - Обробка вводу користувача  
   - Координація між системами
   - Управління камерою та UI

2. **SaveManager** - система збереження
   - Серіалізація стану гри в JSON
   - Збереження позицій гравця та ворогів
   - Відновлення налаштувань рівня
   - Обробка помилок файлової системи

3. **LevelSpawner** - генерація хвиль ворогів
   - Прогресивне збільшення складності
   - Управління таймерами спавну
   - Розподіл ресурсів (припасів)
   - Координація з навігаційною системою

4. **NavigationMap** - навігація та простір
   - Генерація навігаційних мешів
   - Пошук валідних позицій спавну
   - Перевірка колізій
   - Просторові запити для ШІ

5. **Player** - система гравця
   - Обробка вводу WASD + миша
   - Фізика руху та бойової системи
   - Управління здоров'ям та боєприпасами
   - Взаємодія з об'єктами рівня

### Взаємодія компонентів

```
GameManager
├── Player ─────────────┐
├── SaveManager        │
├── LevelSpawner ──────┼── NavigationMap
│   └── Wave[]         │
└── GameUI             │
    └── HUD ───────────┘
```

### Потік даних

#### 1. Ініціалізація гри
```
GameManager._ready()
├── setup_camera()
├── setup_game_ui()  
├── level_manager.level_generated.connect()
└── try_load_saved_game()
```

#### 2. Генерація рівня
```
DynamicLevelManager.regenerate_level()
├── NavigationMap.generate_level()
├── LevelSpawner.reset()
├── LevelSpawner.initialize_waves()
└── LevelSpawner.start_waves()
```

#### 3. Ігровий цикл
```
_physics_process()
├── handle_mouse_cursor()
├── Player.process_input()
├── LevelSpawner.spawn_enemy()
└── UI.update_stats()
```

#### 4. Завершення хвилі
```
LevelSpawner._on_enemy_died()
├── check_wave_completion()
├── spawn_supplies_near_player()
├── complete_current_wave()
└── start_next_wave()
```

### Системи координації

#### Система сигналів
- **LevelSpawner.wave_update** → GameManager._on_wave_update()
- **LevelSpawner.level_complete** → GameManager._on_level_complete() 
- **Player.player_died** → GameManager._on_player_died()
- **Player.player_respawned** → GameManager._on_player_respawned()

#### Групи об'єктів
- **"game_manager"** - доступ до центрального менеджера
- **"player"** - пошук гравця для спавну припасів
- **"enemies"** - підрахунок активних ворогів
- **"supplies"** - управління ресурсами
- **"level_spawner"** - доступ до системи спавну

### Управління пам'яттю

#### Автоматичне очищення
```gdscript
# LevelSpawner.reset()
var existing_enemies = get_tree().get_nodes_in_group("enemies")
for enemy in existing_enemies:
    if is_instance_valid(enemy):
        enemy.queue_free()
```

#### Обробка сигналів
```gdscript
# Автоматичне підключення при спавні
if enemy.has_signal("died"):
    enemy.died.connect(_on_enemy_died.bind(enemy))
```

### Обробка помилок

#### Перевірка залежностей
```gdscript
func initialize_waves():
    if not navmap:
        print("ERROR: No navigation map found for spawner")
        return false
```

#### Безпечний доступ до вузлів
```gdscript
func get_current_enemies() -> Array:
    return get_tree().get_nodes_in_group("enemies")
```

### Масштабованість

#### Модульна структура
- Кожен компонент може працювати незалежно
- Слабкі зв'язки через сигнали та групи
- Можливість додавання нових типів ворогів
- Розширення системи хвиль

#### Конфігурація через дані
```gdscript
var wave_configs = [
    {"enemies": 3, "health": 40.0, "damage": 15, "speed": 3.0},
    {"enemies": 2, "health": 70.0, "damage": 25, "speed": 4.0},
    # Легко додавати нові хвилі
]
```

### Патерни проектування

#### Singleton через Autoload
```gdscript
# GameManagerGlobal.set_scene_game_manager(self)
```

#### Observer через Signals
```gdscript
signal wave_update(wave_number: int)
signal level_complete
```

#### Factory для створення об'єктів
```gdscript
func spawn_enemy():
    var enemy = enemy_scene.instantiate()
    # Налаштування параметрів
```

#### State Machine для хвиль
```gdscript
enum WaveState { INACTIVE, SPAWNING, COMPLETED, ALL_COMPLETED }
```

### Тестування архітектури

#### Модульні тести
- Тестування кожного компонента окремо
- Перевірка обробки сигналів
- Валідація станів систем

#### Інтеграційні тести  
- Взаємодія GameManager ↔ LevelSpawner
- Координація спавну з навігацією
- Повний цикл збереження/завантаження

### Метрики продуктивності

#### Оптимізації
- Кешування результатів пошуку позицій
- Групування об'єктів для швидкого доступу
- Ледача ініціалізація важких ресурсів
- Періодичне очищення неактивних об'єктів

#### Моніторинг
```gdscript
func get_game_stats() -> Dictionary:
    return {
        "current_wave": current_wave + 1,
        "active_enemies": enemies.size(),
        "memory_usage": OS.get_static_memory_usage_by_type()
    }
```

### Подальший розвиток

#### Можливі розширення
1. **Система досягнень** - через GameManager
2. **Мультиплеєр** - розширення архітектури сигналів
3. **Процедурні рівні** - розширення NavigationMap
4. **Система прокачки** - інтеграція з SaveManager
5. **Звукова система** - новий компонент з координацією

#### Рефакторинг планів
- Винесення конфігурації хвиль у зовнішні файли
- Абстракція системи спавну для різних типів об'єктів
- Покращення системи стану гри через enum
- Додавання валідації параметрів у публічні методи