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

### Рекомендовані вимоги для CI/CD

|Компонент|Специфікація|
|---|---|
|CPU|Intel Core i7 або AMD Ryzen 7 (8+ ядер)|
|RAM|32 GB|
|Диск|200 GB NVMe SSD|
|GPU|Дискретна відеокарта (для тестування)|
|Мережа|1 Gbps|

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

### 1. Підготовка проекту

```bash
# Клонування репозиторію
git clone [YOUR_REPOSITORY_URL]
cd [PROJECT_NAME]

# Перевірка цілісності проекту
ls -la project.godot
```

### 2. Налаштування Export Presets

Створіть файл `export_presets.cfg` в корені проекту:

```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="builds/windows/Game.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=true
application/icon="res://icon.svg"
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name=""
application/file_description=""
application/copyright=""
application/trademarks=""
application/export_angle=0
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script="Expand-Archive -LiteralPath '{temp_dir}\\{archive_name}' -DestinationPath '{temp_dir}'
$action = New-ScheduledTaskAction -Execute '{temp_dir}\\{exe_name}' -Argument '{cmd_args}'
$trigger = New-ScheduledTaskTrigger -Once -At 00:00
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
Register-ScheduledTask godot_remote_debug -InputObject $task -Force:$true
Start-ScheduledTask -TaskName godot_remote_debug
while (Get-ScheduledTask -TaskName godot_remote_debug | ? State -eq running) { Start-Sleep 1 }
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue"
ssh_remote_deploy/cleanup_script="Stop-ScheduledTask -TaskName godot_remote_debug -ErrorAction:SilentlyContinue
Unregister-ScheduledTask -TaskName godot_remote_debug -Confirm:$false -ErrorAction:SilentlyContinue
Remove-Item -Recurse -Force '{temp_dir}'"

[preset.1]

name="Linux/X11"
platform="Linux/X11"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="builds/linux/Game.x86_64"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script="unzip -o -q \\"{temp_dir}/{archive_name}\\" -d \\"{temp_dir}\\"
\\"{temp_dir}/{exe_name}\\" {cmd_args}"
ssh_remote_deploy/cleanup_script="kill $(pgrep -x -f \\"{temp_dir}/{exe_name} {cmd_args}\\")
rm -rf \\"{temp_dir}\\""

[preset.2]

name="macOS"
platform="macOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="builds/macos/Game.zip"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.2.options]

export/distribution_type=1
binary_format/architecture="universal"
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
application/icon="res://icon.svg"
application/icon_interpolation=4
application/bundle_identifier="com.yourcompany.yourgame"
application/signature=""
application/app_category="Games"
application/short_version="1.0"
application/version="1.0"
application/copyright=""
display/high_res=true
codesign/enable=false
codesign/identity=""
codesign/timestamp=true
codesign/hardened_runtime=true
codesign/replace_existing_signature=true
codesign/entitlements/custom_file=""
codesign/entitlements/allow_jit_code_execution=false
codesign/entitlements/allow_unsigned_executable_memory=false
codesign/entitlements/allow_dyld_environment_variables=false
codesign/entitlements/disable_library_validation=false
codesign/entitlements/audio_input=false
codesign/entitlements/camera=false
codesign/entitlements/location=false
codesign/entitlements/address_book=false
codesign/entitlements/calendars=false
codesign/entitlements/photos_library=false
codesign/entitlements/apple_events=false
codesign/entitlements/debugging=false
codesign/entitlements/app_sandbox/enabled=false
codesign/entitlements/app_sandbox/network_server=false
codesign/entitlements/app_sandbox/network_client=false
codesign/entitlements/app_sandbox/device_usb=false
codesign/entitlements/app_sandbox/device_bluetooth=false
codesign/entitlements/app_sandbox/files_downloads=0
codesign/entitlements/app_sandbox/files_pictures=0
codesign/entitlements/app_sandbox/files_music=0
codesign/entitlements/app_sandbox/files_movies=0
codesign/entitlements/app_sandbox/helper_executables=[]
notarization/enable=false
notarization/apple_id_name=""
notarization/apple_id_password=""
notarization/apple_team_id=""
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
```

### 3. Скрипт автоматичної збірки

Створіть `scripts/build.py`:

```python
#!/usr/bin/env python3
import os
import subprocess
import sys
import shutil
from pathlib import Path

class GameBuilder:
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.builds_dir = self.project_root / "builds"
        self.godot_executable = self.find_godot()
        
    def find_godot(self):
        """Знайти виконуваний файл Godot"""
        possible_paths = [
            "godot",
            "Godot_v4.2.1-stable_linux.x86_64",
            "Godot_v4.2.1-stable_win64.exe",
            "Godot.app/Contents/MacOS/Godot"
        ]
        
        for path in possible_paths:
            if shutil.which(path):
                return path
                
        raise FileNotFoundError("Godot executable not found!")
    
    def clean_builds(self):
        """Очистити папку збірок"""
        if self.builds_dir.exists():
            shutil.rmtree(self.builds_dir)
        self.builds_dir.mkdir(exist_ok=True)
        
    def build_platform(self, preset_name, build_path):
        """Збірка для конкретної платформи"""
        print(f"Building {preset_name}...")
        
        # Створити директорію
        build_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Команда збірки
        cmd = [
            self.godot_executable,
            "--headless",
            "--export-release",
            preset_name,
            str(build_path)
        ]
        
        # Виконати збірку
        result = subprocess.run(cmd, cwd=self.project_root, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Error building {preset_name}:")
            print(result.stderr)
            return False
        
        print(f"✅ {preset_name} built successfully!")
        return True
    
    def build_all(self):
        """Збірка для всіх платформ"""
        platforms = [
            ("Windows Desktop", self.builds_dir / "windows" / "Game.exe"),
            ("Linux/X11", self.builds_dir / "linux" / "Game.x86_64"),
            ("macOS", self.builds_dir / "macos" / "Game.zip")
        ]
        
        self.clean_builds()
        success_count = 0
        
        for preset, path in platforms:
            if self.build_platform(preset, path):
                success_count += 1
        
        print(f"\n✅ Built {success_count}/{len(platforms)} platforms successfully!")
        return success_count == len(platforms)

if __name__ == "__main__":
    builder = GameBuilder()
    
    if len(sys.argv) > 1 and sys.argv[1] == "clean":
        builder.clean_builds()
        print("Builds directory cleaned!")
    else:
        success = builder.build_all()
        sys.exit(0 if success else 1)
```

## Розгортання на платформах

### Itch.io

#### 1. Налаштування Butler

```bash
# Авторизація в itch.io
butler login

# Створення каналів для кожної платформи
butler push builds/windows your-username/your-game:windows
butler push builds/linux your-username/your-game:linux
butler push builds/macos your-username/your-game:osx
```

#### 2. Автоматичний деплой скрипт

```bash
#!/bin/bash
# scripts/deploy_itch.sh

ITCH_USER="your-username"
GAME_NAME="your-game"

echo "Deploying to itch.io..."

# Завантаження кожної платформи
butler push builds/windows $ITCH_USER/$GAME_NAME:windows --userversion $(date +%Y.%m.%d.%H%M)
butler push builds/linux $ITCH_USER/$GAME_NAME:linux --userversion $(date +%Y.%m.%d.%H%M)
butler push builds/macos $ITCH_USER/$GAME_NAME:osx --userversion $(date +%Y.%m.%d.%H%M)

echo "Itch.io deployment completed!"
```

### Standalone дистрибуція

#### 1. Створення інсталяторів

**Windows (NSIS)**:

```nsis
; installer.nsi
!define APP_NAME "Your Game"
!define APP_VERSION "1.0.0"
!define APP_PUBLISHER "Your Company"
!define APP_URL "https://yourgame.com"
!define APP_EXE "Game.exe"

OutFile "YourGame_Setup.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"

Section "MainSection" SEC01
    SetOutPath "$INSTDIR"
    File /r "builds\windows\*"
    CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd
```

**Linux (AppImage)**:

```bash
#!/bin/bash
# scripts/create_appimage.sh

# Створення структури AppImage
mkdir -p appimage/usr/bin
mkdir -p appimage/usr/share/applications
mkdir -p appimage/usr/share/icons/hicolor/256x256/apps

# Копіювання файлів
cp builds/linux/Game.x86_64 appimage/usr/bin/
cp assets/icon.png appimage/usr/share/icons/hicolor/256x256/apps/game.png

# Створення .desktop файлу
cat > appimage/usr/share/applications/game.desktop << EOF
[Desktop Entry]
Type=Application
Name=Your Game
Exec=Game.x86_64
Icon=game
Categories=Game;
EOF

# Створення AppRun
cat > appimage/AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/Game.x86_64" "$@"
EOF
chmod +x appimage/AppRun

# Збірка AppImage
appimagetool appimage YourGame-1.0.0-x86_64.AppImage
```

### CDN та веб-дистрибуція

#### 1. Налаштування веб-експорту

```bash
# Для WebGL збірки потрібні додаткові налаштування
mkdir -p builds/web

# Збірка для веб
godot --headless --export-release "Web" builds/web/index.html
```

#### 2. Налаштування веб-сервера

```nginx
# nginx.conf для хостингу WebGL збірки
server {
    listen 80;
    server_name yourgame.com;
    root /var/www/yourgame;
    index index.html;
    
    # MIME types для Godot WebGL
    location ~* \.(pck|wasm)$ {
        add_header Cross-Origin-Embedder-Policy require-corp;
        add_header Cross-Origin-Opener-Policy same-origin;
    }
    
    # Кешування ресурсів
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

## Перевірка працездатності

### 1. Автоматизоване тестування збірок

```python
# scripts/test_builds.py
import subprocess
import sys
import time
from pathlib import Path

def test_build(executable_path, timeout=30):
    """Тестування збірки"""
    try:
        # Запуск гри з headless режимом для тестування
        process = subprocess.Popen([str(executable_path), "--headless", "--quit-after", "5"])
        process.wait(timeout=timeout)
        return process.returncode == 0
    except subprocess.TimeoutExpired:
        process.kill()
        return False
    except Exception as e:
        print(f"Error testing {executable_path}: {e}")
        return False

def main():
    builds_dir = Path("builds")
    tests = [
        builds_dir / "windows" / "Game.exe",
        builds_dir / "linux" / "Game.x86_64",
    ]
    
    passed = 0
    for build in tests:
        if build.exists():
            print(f"Testing {build}...")
            if test_build(build):
                print(f"✅ {build.name} passed")
                passed += 1
            else:
                print(f"❌ {build.name} failed")
        else:
            print(f"⚠️ {build} not found")
    
    print(f"\nPassed: {passed}/{len(tests)}")
    return passed == len(tests)

if __name__ == "__main__":
    sys.exit(0 if main() else 1)
```

### 2. Моніторинг та логування

```gdscript
# scripts/Logger.gd - Система логування в грі
extends Node

enum LogLevel {
    DEBUG,
    INFO,
    WARNING,
    ERROR
}

var log_file: FileAccess
var log_buffer: Array = []

func _ready():
    # Створення лог файлу
    var log_dir = OS.get_user_data_dir() + "/logs"
    if not DirAccess.dir_exists_absolute(log_dir):
        DirAccess.open(OS.get_user_data_dir()).make_dir("logs")
    
    var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
    log_file = FileAccess.open(log_dir + "/game_" + timestamp + ".log", FileAccess.WRITE)

func log(message: String, level: LogLevel = LogLevel.INFO):
    var timestamp = Time.get_datetime_string_from_system()
    var level_str = LogLevel.keys()[level]
    var log_entry = "[%s] %s: %s" % [timestamp, level_str, message]
    
    print(log_entry)
    
    if log_file:
        log_file.store_line(log_entry)
        log_file.flush()
    
    log_buffer.append(log_entry)
    
    # Обмеження розміру буферу
    if log_buffer.size() > 1000:
        log_buffer.pop_front()

func _exit_tree():
    if log_file:
        log_file.close()
```

### 3. Перевірка ключових функцій

```bash
#!/bin/bash
# scripts/smoke_test.sh

echo "Running smoke tests..."

# Перевірка цілісності збірок
echo "1. Checking build integrity..."
for build in builds/*/Game.*; do
    if [[ -f "$build" ]]; then
        echo "✅ Found: $build"
        
        # Перевірка розміру файлу
        size=$(stat -f%z "$build" 2>/dev/null || stat -c%s "$build" 2>/dev/null)
        if [[ $size -gt 10000000 ]]; then  # > 10MB
            echo "✅ Size check passed: $(($size / 1024 / 1024))MB"
        else
            echo "⚠️ Build seems too small: $(($size / 1024 / 1024))MB"
        fi
    else
        echo "❌ Missing: $build"
    fi
done

# Перевірка ресурсів
echo "2. Checking game assets..."
essential_assets=(
    "assets/textures"
    "scenes/Main_scene.tscn"
    "project.godot"
)

for asset in "${essential_assets[@]}"; do
    if [[ -e "$asset" ]]; then
        echo "✅ Found: $asset"
    else
        echo "❌ Missing: $asset"
    fi
done

echo "Smoke test completed!"
```

## Автоматизація CI/CD

### GitHub Actions

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy Game

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Godot
      uses: chickensoft-games/setup-godot@v1
      with:
        version: 4.2.1
        use-dotnet: false
    
    - name: Import project
      run: godot --headless --import
    
    - name: Build for all platforms
      run: python3 scripts/build.py
    
    - name: Run smoke tests
      run: bash scripts/smoke_test.sh
    
    - name: Upload builds
      uses: actions/upload-artifact@v3
      with:
        name: game-builds
        path: builds/
    
    - name: Deploy to itch.io
      if: startsWith(github.ref, 'refs/tags/')
      env:
        BUTLER_API_KEY: ${{ secrets.BUTLER_API_KEY }}
      run: |
        curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
        unzip butler.zip
        chmod +x butler
        ./butler login
        bash scripts/deploy_itch.sh
```

---

Ця документація забезпечує повний цикл розгортання ігрової системи від локальної розробки до production дистрибуції на різних платформах.