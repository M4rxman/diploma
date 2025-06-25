# Інструкція з генерації документації

## Огляд

Цей документ описує процес генерації документації для проекту на GDScript/Godot. Документація генерується у форматі HTML з використанням статичних інструментів.

## Передумови

### Системні вимоги

- **Linux/WSL/macOS**: Bash shell
- **Python 3.8+**: для інструментів документації
- **Git**: для отримання останніх змін
- **Godot Engine 4.2.1+**: для перевірки коду

### Структура документації

```
docs/
├── source/           # Вихідні файли документації
│   ├── api/         # API документація
│   ├── architecture/ # Архітектурні діаграми
│   ├── development/ # Інструкції розробки
│   └── _static/     # CSS та статичні файли
├── build/           # Згенерована HTML документація
├── venv/            # Віртуальне середовище Python
└── requirements.txt # Python залежності
```

## Встановлення інструментів

### Перший запуск

1. **Встановлення інструментів документації**:

```bash
./scripts/install_docs_tools.sh
```

Цей скрипт:
- Встановлює Python virtual environment
- Завантажує Sphinx та необхідні пакети
- Створює структуру документації
- Налаштовує CSS стилі

2. **Перевірка встановлення**:

```bash
cd docs
source venv/bin/activate
sphinx-build --version
```

### Ручне встановлення (якщо автоматичне не працює)

```bash
cd docs
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install sphinx sphinx-rtd-theme
```

## Генерація документації

### Автоматична генерація

```bash
./scripts/generate_docs.sh
```

### Ручна генерація

```bash
cd docs
source venv/bin/activate
sphinx-build -b html source build
```

### Очищення попередніх збірок

```bash
cd docs
rm -rf build/*
```

## Структура файлів документації

### Конфігурація Sphinx (docs/source/conf.py)

```python
# Основна конфігурація
project = 'Diploma Game'
copyright = '2024, Олександр Алещенко'
author = 'Олександр Алещенко'

# HTML налаштування
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_css_files = ['custom.css']
```

### Головна сторінка (docs/source/index.rst)

Точка входу для всієї документації з посиланнями на:
- API довідник
- Архітектурний огляд
- Інструкції розробки
- Перевірка якості

## Оновлення документації

### При зміні коду

1. **Оновіть коментарі в коді**:

```gdscript
## Brief description of the method
##
## Detailed description
## @param parameter_name: Description
## @return: Description of return value
func method_name(parameter_name: Type) -> ReturnType:
```

2. **Регенеруйте документацію**:

```bash
./scripts/generate_docs.sh
```

3. **Перевірте результат**:

```bash
# Автоматичне відкриття в браузері (Linux)
xdg-open docs/build/index.html

# Ручне відкриття
open docs/build/index.html  # macOS
start docs/build/index.html # Windows
```

### При додаванні нових модулів

1. Створіть файл документації в `docs/source/api/`
2. Додайте посилання в `docs/source/index.rst`
3. Регенеруйте документацію

## Автоматизація

### Pre-commit hook

Створіть `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "Перевірка документації..."
./scripts/check_documentation.sh

if [ $? -ne 0 ]; then
    echo "Помилки в документації! Коміт відхилено."
    exit 1
fi
```

### CI/CD інтеграція

Приклад для GitHub Actions (`.github/workflows/docs.yml`):

```yaml
name: Build Documentation
on: [push, pull_request]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.8'
    - name: Install dependencies
      run: ./scripts/install_docs_tools.sh
    - name: Generate documentation
      run: ./scripts/generate_docs.sh
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./docs/build
```

## Налагодження проблем

### Помилка: "Virtual environment not found"

```bash
cd docs
python3 -m venv venv
source venv/bin/activate
pip install sphinx sphinx-rtd-theme
```

### Помилка: "conf.py not found"

```bash
cd docs/source
sphinx-quickstart
# Відповідайте на запитання або скопіюйте існуючий conf.py
```

### Помилка: CSS стилі не застосовуються

Перевірте наявність `docs/source/_static/custom.css`:

```bash
ls -la docs/source/_static/
```

### WSL специфічні проблеми

```bash
# Встановлення додаткових пакетів
sudo apt update
sudo apt install python3-venv python3-full

# Перезапуск WSL
wsl --shutdown
wsl
```

## Веб-сервер для тестування

### Простий HTTP сервер

```bash
cd docs/build
python3 -m http.server 8000
# Відкрийте http://localhost:8000
```

### Live reload сервер

```bash
pip install sphinx-autobuild
sphinx-autobuild docs/source docs/build
# Автоматичне оновлення при змінах
```

## Метрики якості документації

### Покриття документацією

```bash
./scripts/check_documentation.sh
```

Перевіряє:
- Наявність документації для всіх публічних методів
- Правильність формату коментарів
- Відповідність стандартам GDScript

### Розмір документації

```bash
du -sh docs/build/
find docs/build -name "*.html" | wc -l
```

## Підтримка документації

### Відповідальність команди

- **Розробники**: Документують свій код при написанні
- **Tech Lead**: Перевіряє якість документації в PR
- **DevOps**: Підтримує автоматизацію генерації

### Частота оновлень

- **Щодня**: Автоматична генерація при комітах
- **Щотижня**: Перевірка покриття документацією
- **Щомісяця**: Аудит архітектурної документації

### Зворотний зв'язок

Для звітування про проблеми з документацією:
1. Створіть issue в репозиторії
2. Використайте тег `documentation`
3. Опишіть проблему та очікуваний результат

## Корисні посилання

- [Sphinx Documentation](https://www.sphinx-doc.org/)
- [reStructuredText Primer](https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html)
- [Godot GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Read the Docs Theme](https://sphinx-rtd-theme.readthedocs.io/)