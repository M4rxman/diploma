# diploma

A 3D game developed in **Godot Engine 4**, as part of a bachelor's diploma project. The game features a player character, enemies, and gameplay logic including saving/loading game states, combat, and game state management. The project uses modular architecture and follows modern best practices for game development and version control.

## 📦 Repository Structure

├── addons/ # Custom or third-party Godot plugins (e.g., GUT for testing)
├── assets/ # Game assets (models, textures, sounds, icons)
│ ├── models/
│ ├── textures/
│ ├── sounds/
│ └── icons/
├── save/ # Folder for game save files
├── scenes/ # All game scenes: world, player, enemies, UI
├── scripts/ # GDScript logic for player, enemies, saving, etc.
├── tests/ # Unit tests (using GUT framework)
├── .gitignore # Files and folders ignored by Git
├── LICENSE # Project license (e.g., MIT)
├── README.md # This file
└── project.godot # Godot project configuration

## 🚀 Features

- **Modular architecture** using GDScript and scene-based composition
- **Save/Load system** via JSON files
- **Unit tests** powered by [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)
- **Enemy AI** (can be disabled for testing)
- **Basic combat** and player gravity/jumping logic
- Clean and **version-controlled structure** suitable for team development

## 📜 How to Run

1. Install **Godot Engine 4.2** or higher
2. Clone the repository:
   ```bash
   git clone https://github.com/M4rxman/diploma.git
   cd diploma
Open the project with Godot Editor

Run the Main_scene.tscn or press F5 to start the game

🧪 Running Tests
Make sure the GUT plugin is installed and activated in addons/gut/

Run tests via the GutRunner.tscn scene

Alternatively, from the editor, press F6 to run current tests

📄 License
This project is licensed under the MIT License.
Feel free to use, modify, and distribute with attribution.

📌 System Requirements
Godot 4.2+

Tested on Windows and Linux

Recommended screen resolution: 800x600 or higher

📁 Commit Reference
Repository: https://github.com/M4rxman/diploma
Cleanup Commit: <commit-sha>

🧹 Repository Cleanup Summary
Removed unnecessary temporary files and editor-generated cache

Added .gitignore to exclude build artifacts and editor logs

Created proper README.md and LICENSE

Validated directory structure: scenes, scripts, assets, tests, saves

🔐 No Sensitive Information
All private keys, API tokens, user credentials, or personal data have been removed.
The repository is now safe for public sharing and collaborative development.
