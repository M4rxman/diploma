# Інструкція з розгортання у виробничому середовищі

Цей документ описує процес розгортання ігрової системи на Godot Engine в production середовищі для різних платформ та дистрибуційних каналів.

## Вимоги до апаратного забезпечення

### Мінімальні вимоги для збірки (Build Server)

|Компонент|Специфікація|
|---|---|
|Архітектура|x86_64 (64-bit)|
|CPU|Intel Core i5 або AMD Ryzen 5 (4+ ядра)|
|RAM|8 GB (16+ GB рекомендовано)|
|Диск|50 GB SSD вільного місця|
|ОС|Windows 10+, macOS 10.15+, Ubuntu 20.04+|
|Мережа|100 Mbps (для завантаження templates)|

### Вимоги для кінцевих користувачів

|Платформа|Мінімум|Рекомендовано|
|---|---|---|
|**Windows**|Windows 10, 4GB RAM, DirectX 11|Windows 11, 8GB RAM, DirectX 12|
|**macOS**|macOS 10.14, 4GB RAM, Metal|macOS 12+, 8GB RAM, Metal 3|
|**Linux**|Ubuntu 18.04, 4GB RAM, OpenGL 3.3|Ubuntu 22.04, 8GB RAM, Vulkan|

## Необхідне програмне забезпечення

### Основні компоненти

1. **Godot Engine 4.2.1**
    
    ```bash
    # Завантаження Godot
    wget https://downloads.tuxfamily.org/godotengine/4.2.1/Godot_v4.2.1-stable_linux.x86_64.zip
    unzip Godot_v4.2.1-stable_linux.x86_64.zip
    chmod +x Godot_v4.2.1-stable_linux.x86_64
    ```
    
2. **Export Templates**
    
    ```bash
    # Завантаження та встановлення export templates
    wget https://downloads.tuxfamily.org/godotengine/4.2.1/Godot_v4.2.1-stable_export_templates.tpz
    # Розпакуйте в ~/.local/share/godot/export_templates/4.2.1.stable/
    ```
    
3. **Додаткові інструменти**
    
    - Git для контролю версій
    - Python 3.8+ для автоматизації
    - Butler (itch.io CLI) для деплою
    - SteamCMD для Steam Workshop

### Встановлення залежностей

#### Ubuntu/Debian

```bash
# Базові залежності
sudo apt update
sudo apt install -y wget unzip git python3 python3-pip

# Додаткові бібліотеки для Godot
sudo apt install -y libasound2-dev libpulse-dev libx11-dev libxrandr-dev \
    libgl1-mesa-dev libglu1-mesa-dev libxinerama-dev libxcursor-dev libxi-dev

# Butler для itch.io
curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip butler.zip -d butler
sudo mv butler/butler /usr/local/bin/
```

#### Windows (PowerShell)

```powershell
# Chocolatey для управління пакетами
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Встановлення залежностей
choco install -y git python3 7zip

# Butler для itch.io
Invoke-WebRequest -Uri "https://broth.itch.ovh/butler/windows-amd64/LATEST/archive/default" -OutFile "butler.zip"
Expand-Archive butler.zip -DestinationPath "C:\tools\butler"
```

#### macOS

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Залежності
brew install git python@3.11 wget

# Butler для itch.io
curl -L -o butler.zip https://broth.itch.ovh/butler/darwin-amd64/LATEST/archive/default
unzip butler.zip
sudo mv butler /usr/local/bin/
```

## Налаштування збірки

Деплоймент проекту (якщо на руках тільки матеріал з репозиторію) проводиться через рушій Godot.

1. спочатку вибираємо функцію експорт в розділі Project
![[Pasted image 20250625102708.png]]

2. В віконці експорт вибираємо add для вибору операційної системи для експорту нашого додатку
![[Pasted image 20250625102824.png]]
3. **Вибір цільової платформи** У списку доступних платформ виберіть необхідну операційну систему:
    - **Windows Desktop** - для Windows 10/11
    - **macOS** - для macOS 10.14+
    - **Linux/X11** - для дистрибутивів Linux
    - **Android** - для мобільних пристроїв Android
    - **iOS** - для iPhone/iPad (потрібен macOS)
    - **Web** - для браузерних версій (WebAssembly)
4. **Налаштування Export Templates** Після вибору платформи система запропонує завантажити відповідний export template:
    
    bash
    
    ```bash
    # Автоматичне завантаження через інтерфейс Godot
    Project → Export → Manage Export Templates → Download and Install
    ```
    
    Або ручне встановлення:
    
    bash
    
    ```bash
    # Завантаження templates для поточної версії
    wget https://downloads.tuxfamily.org/godotengine/4.2.1/Godot_v4.2.1-stable_export_templates.tpz
    # Розпакування у відповідну директорію
    ~/.local/share/godot/export_templates/4.2.1.stable/
    ```
    
5. **Конфігурація параметрів експорту** **Основні налаштування:**
    
    - **Export Path** - шлях для збереження готової збірки
    - **Resources** - включення/виключення ресурсів проекту
    - **Features** - додаткові можливості платформи
    - **Binary Format** - формат виконуваного файлу
    
    **Налаштування для Windows:**
```ini
    [application]
    config/name="Назва вашої гри"
    config/description="Опис гри"
    config/version="1.0.0"
    config/icon="res://icon.ico"
    
    [display]
    window/size/viewport_width=1920
    window/size/viewport_height=1080
    window/stretch/mode="viewport"
```

6. **Налаштування підпису та метаданих** **Для Windows (у вкладці Options):**
    
    - **Company Name** - назва компанії/розробника
    - **Product Name** - назва продукту
    - **File Version** - версія файлу
    - **Product Version** - версія продукту
    - **File Description** - опис файлу
    - **Copyright** - авторські права
    
    **Для macOS:**
    
    bash
    
```bash
    # Налаштування Bundle ID
    com.yourcompany.yourgame
    
    # Підпис додатка (потрібен Apple Developer Account)
    codesign --force --verify --verbose --sign "Developer ID Application: Your Name" YourGame.app
 ```
    
7. **Процес збірки** Натисніть кнопку **"Export Project"** та виберіть:
    
    - **Export All** - повний експорт всіх ресурсів
    - **Export Selected** - експорт тільки вибраних файлів
    - **Export PCK** - експорт тільки ресурсів у .pck файл
    
    **Параметри оптимізації:**

```ini
    # У project.godot для production збірки
    [rendering]
    textures/canvas_textures/default_texture_filter=1
    renderer/rendering_method="gl_compatibility"
    
    [physics]
    3d/physics_engine="JoltPhysics3D"
    
    [compression]
    formats/zstd/long_distance_matching=true
    formats/zstd/compression_level=19
```
    
8. **Специфічні налаштування для платформ** **Android:**
    
    bash
    
```bash
    # Встановлення Android SDK
    export ANDROID_SDK_ROOT="/path/to/android-sdk"
    export JAVA_HOME="/path/to/java"
    
    # У Godot Editor → Editor Settings → Export → Android
    # Android SDK Path: /path/to/android-sdk
    # Debug Keystore: /path/to/debug.keystore
```
    
    **Web (HTML5):**
    
    - **Head Include** - додатковий HTML код
    - **Canvas Resize Policy** - політика зміни розміру
    - **Focus Canvas On Start** - автофокус на canvas
    
    **Linux:**
    
```bash
    # Додаткові бібліотеки для сумісності
    sudo apt install -y libc6:i386 libgcc1:i386
```
    
9. **Автоматизація збірки через командний рядок**
    
```bash
    # Експорт для Windows
    godot --headless --export-release "Windows Desktop" game.exe
    
    # Експорт для Linux
    godot --headless --export-release "Linux/X11" game.x86_64
    
    # Експорт для Web
    godot --headless --export-release "Web" index.html
```
    
10. **Скрипт автоматизації для CI/CD**

```bash
#!/bin/bash
# build_script.sh

GODOT_BIN="godot"
PROJECT_PATH="."
EXPORT_PATH="./builds"

# Створення директорії для збірок
mkdir -p "$EXPORT_PATH"

# Збірка для різних платформ
echo "Building for Windows..."
$GODOT_BIN --headless --export-release "Windows Desktop" "$EXPORT_PATH/game_windows.exe"

echo "Building for Linux..."
$GODOT_BIN --headless --export-release "Linux/X11" "$EXPORT_PATH/game_linux.x86_64"

echo "Building for Web..."
$GODOT_BIN --headless --export-release "Web" "$EXPORT_PATH/web/index.html"

echo "Build completed successfully!"
```

11. **Перевірка та тестування збірки**

bash

```bash
# Перевірка розміру файлів
ls -lh builds/

# Тестування Web версії локально
cd builds/web && python3 -m http.server 8000

# Перевірка залежностей Linux збірки
ldd game_linux.x86_64
```

## Поширені помилки та їх вирішення

**Помилка: "Export template not found"**

bash

```bash
# Рішення: перевстановити export templates
rm -rf ~/.local/share/godot/export_templates/
# Завантажити знову через Editor → Manage Export Templates
```

**Помилка: "Failed to export project"**

bash

```bash
# Перевірити:
# 1. Правильність шляхів до ресурсів
# 2. Відсутність циклічних посилань
# 3. Коректність project.godot файлу
```

**Оптимізація розміру збірки:**

- Використовуйте стиснення текстур
- Вимкніть непотрібні імпорти
- Мінімізуйте розмір аудіофайлів
- Видаліть невикористані ресурси

