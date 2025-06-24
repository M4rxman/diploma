# Ігрова система на Godot Engine - Шутер

Інформаційна ігрова система жанру шутер з процедурною генерацією рівнів, розроблена на Godot Engine 4.2.1.

## Швидкий старт

### Передумови

Перед початком роботи з проектом переконайтеся, що у вас встановлено:

- **Операційна система**: Windows 10/11, macOS 10.14+, або Linux (Ubuntu 18.04+)
- **Мінімальні вимоги**: 4 GB RAM, 2 GB вільного місця на диску
- **Git** для роботи з репозиторієм

## Встановлення та налаштування

### Крок 1: Встановлення Godot Engine

1. **Завантажте Godot Engine 4.2.1**:
    
    - Перейдіть на [офіційний сайт Godot](https://godotengine.org/download)
    - Завантажте **Godot Engine 4.2.1 Standard**
    - Розпакуйте архів у зручну папку
2. **Налаштування Godot**:
    
    ```bash
    # Windows: додайте шлях до Godot в PATH або створіть ярлик
    # Linux/macOS: зробіть файл виконуваним
    chmod +x Godot_v4.2.1-stable_linux.x86_64
    ```
    

### Крок 2: Клонування репозиторію

```bash
# Клонуйте репозиторій
git clone https://github.com/M4rxman/diploma

# Переключтеся на основну гілку розробки
git checkout main
```

### Крок 3: Відкриття проекту в Godot

1. Запустіть Godot Engine
2. Натисніть **"Import"** в Project Manager
3. Виберіть файл `project.godot` в корені проекту
4. Натисніть **"Import & Edit"**

### Крок 4: Налаштування середовища розробки

#### Налаштування вбудованого редактора

1. **Налаштування Editor Settings**:
    
    - `Editor → Editor Settings`
    - `Text Editor → Behavior → Indent Type`: Tabs
    - `Text Editor → Behavior → Indent Size`: 4
    - `Network → Language Server → Enable LSP`: Увімкнути
2. **Налаштування Project Settings**:
    
    - `Project → Project Settings`
    - `Rendering → Renderer → Rendering Method`: gl_compatibility
    - `Physics → 3D → Physics Engine`: JoltPhysics3D

#### Альтернативні редактори (опціонально)

**VS Code з розширенням godot-tools**:

```bash
# Встановіть VS Code
# Встановіть розширення "godot-tools"
# Налаштуйте Language Server в Godot
```

**Vim/Neovim з LSP**:

```bash
# Встановіть godot-lsp клієнт
# Налаштуйте у вашому init.vim/init.lua
```

### Крок 5: Перевірка встановлення

1. **Запуск гри в режимі розробки**:
    
    - Натисніть F5 або кнопку ▶️ в Godot
    - Виберіть `Main_scene.tscn` як головну сцену
    - Гра повинна запуститися без помилок
2. **Перевірка основного функціоналу**:
    
    - Персонаж реагує на WASD
    - Стрільба працює (клавіша миші)
    - Вороги з'являються та рухаються

## Робота з проектом

### Структура проекту

```
project/
├── scenes/                     # Ігрові сцени
│   ├── Main_scene.tscn        # Головна сцена
│   ├── Player/                # Сцени гравця
│   ├── Enemies/               # Сцени ворогів
│   └── UI/                    # Інтерфейс користувача
├── scripts/                   # GDScript файли
│   ├── GameManager.gd         # Головний менеджер
│   ├── Player/                # Скрипти гравця
│   ├── Enemies/               # ШІ ворогів
│   └── Systems/               # Системи гри
├── assets/                    # Ресурси
│   ├── textures/              # Текстури
│   ├── models/                # 3D моделі
│   └── audio/                 # Звуки
├── tests/                     # Тести GUT
└── project.godot              # Файл проекту
```

### Основні команди та операції


#### Git workflow

```bash
# Створення нової гілки для фічі
git checkout -b feature/new-weapon-system

# Комітинг змін
git add .
git commit -m "feat: add new weapon system with reload mechanics"

# Пуш та створення PR
git push origin feature/new-weapon-system
```

### Тестування

#### Запуск автоматизованих тестів

1. **Встановлення GUT**:
    
    - GUT вже включений в проект як addon
    - Перейдіть до `Project → Project Settings → Plugins`
    - Увімкніть плагін "Gut"
2. **Запуск тестів**:
    
    ```bash
    # В Godot Editor
    # Відкрийте GUT Dock (зазвичай внизу екрану)
    # Натисніть "Run All Tests"
    
    # Або через командний рядок
    godot --headless -s addons/gut/gut_cmdln.gd -gexit
    ```
    
3. **Написання нових тестів**:
    
    ```gdscript
    # tests/unit/test_player.gd
    extends GutTest
    
    func test_player_movement():
        var player = preload("res://scenes/Player/Player.tscn").instantiate()
        add_child_autofree(player)
        
        # Тест логіки
        assert_true(player.has_method("move"))
    ```
    

### Збірка та експорт

#### Налаштування export templates

1. **Завантаження templates**:
    
    - `Editor → Manage Export Templates`
    - `Download and Install` для версії 4.2.1
2. **Створення export presets**:
    
    - `Project → Export`
    - `Add...` → виберіть потрібну платформу
    - Налаштуйте параметри експорту

#### Збірка для різних платформ

```bash
# Через Godot Editor
Project → Export → Export Project

# Через командний рядок (коли налаштовані presets)
godot --headless --export-release "Windows Desktop" builds/game_windows.exe
godot --headless --export-release "Linux/X11" builds/game_linux
godot --headless --export-release "macOS" builds/game_macos.zip
```

## Налагодження поширених проблем

### Проблема: Помилки в скриптах

**Рішення**:

1. Перевірте Errors/Warnings в нижній панелі
2. Увімкніть `Settings → Network → Language Server`
3. Використовуйте `print()` для відлагодження

### Проблема: Низька продуктивність

**Рішення**:

```gdscript
# Увімкніть Profiler в Debug меню
# Перевірте кількість викликів у Profiler → Network
# Оптимізуйте циклічні операції в _process()
```

### Проблема: Тести не проходять

**Рішення**:

```bash
# Перевірте, що GUT правильно встановлений
# Запустіть тести з детальним виводом
# Перевірте шляхи до тестових файлів
```

## Додаткові Ресурси

### Документація

- [Офіційна документація Godot 4](https://docs.godotengine.org/en/stable/)
- [GDScript документація](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
- [GUT Testing Framework](https://github.com/bitwes/Gut)

### Спільнота

- [Godot Discord](https://discord.gg/4JBkykG)
- [Reddit r/godot](https://reddit.com/r/godot)
- [Godot Q&A](https://ask.godotengine.org/)

### Туторіали

- [Godot Academy](https://godotacademy.com/)
- [Brackeys Godot Tutorials](https://www.youtube.com/playlist?list=PLPV2KyIb3jR6TFcFuzI2bB7TMNIIBpKMQ)

