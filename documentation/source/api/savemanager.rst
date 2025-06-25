SaveManager API Reference
=========================

.. currentmodule:: scripts.SaveManager

Overview
--------

The **SaveManager** class handles all game state persistence operations, providing reliable save/load functionality for player progress, enemy states, and level configurations.

.. note::
   SaveManager uses JSON format for human-readable save files stored in the user data directory.

Class Definition
----------------

.. class:: SaveManager

   System for saving and loading game state that handles all persistence operations including player position, enemy states, and level data using JSON format for human-readable save files.

   **Inherits**: Node

Constants
---------

.. attribute:: SAVE_PATH
   :type: String
   :value: "user://savegame.json"

   File path for the main save game file in Godot's user data directory.

Core Methods
------------

.. method:: save_game(player: Node, enemies: Array, level_seed: int = 0, level_settings: Dictionary = {}) -> bool

   Save the current game state to file.

   Serializes player data, enemy positions, and game state to a JSON file in the user directory. Handles error checking and ensures data integrity.

   :param player: The player node to save
   :param enemies: Array of enemy nodes to save  
   :param level_seed: Seed used for level generation
   :param level_settings: Dictionary containing level configuration
   :returns: true if save was successful, false otherwise
   :rtype: bool

   **Saved Data Structure:**

   .. code-block:: json

      {
        "player": {
          "position": [x, y, z],
          "health": 100,
          "ammo": 50,
          "level": 1
        },
        "enemies": [
          {
            "position": [x, y, z],
            "health": 75,
            "type": "basic_enemy"
          }
        ],
        "level_data": {
          "seed": 12345,
          "settings": {...}
        },
        "timestamp": 1640995200
      }

.. method:: load_game(player: Node, enemies: Array) -> Dictionary

   Load game state from save file.

   Deserializes game data and applies it to the current scene. Returns level data that can be used for level regeneration. If the save file is corrupted or missing, returns empty dictionary.

   :param player: Player node to apply loaded data to
   :param enemies: Array of enemy nodes to update
   :returns: Dictionary containing level data for regeneration
   :rtype: Dictionary

   **Error Handling:**

   - Returns empty dict if save file doesn't exist
   - Returns empty dict if JSON parsing fails
   - Logs errors to console for debugging
   - Gracefully handles missing data fields

Usage Examples
--------------

Basic Save Operation
~~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   var save_manager = SaveManager.new()
   var player = get_node("Player")
   var enemies = get_tree().get_nodes_in_group("enemies")
   
   var success = save_manager.save_game(player, enemies)
   if success:
       print("Game saved successfully!")
   else:
       print("Save failed!")

Advanced Save with Level Data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   var level_settings = {
       "difficulty": 3,
       "map_size": "large",
       "enemy_density": 0.7
   }
   
   var success = save_manager.save_game(
       player, 
       enemies, 
       current_level_seed,
       level_settings
   )

Load and Apply State
~~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   var level_data = save_manager.load_game(player, enemies)
   
   if not level_data.is_empty():
       # Apply level data to regenerate same level
       if level_data.has("seed"):
           level_generator.set_seed(level_data.seed)
       if level_data.has("settings"):
           level_generator.apply_settings(level_data.settings)
   else:
       print("No save data found, starting new game")

Best Practices
--------------

1. **Error Checking**: Always check return values from save_game()

2. **Data Validation**: Verify loaded data before applying to game objects

3. **Backup Strategy**: Consider implementing multiple save slots

4. **Performance**: Save only when necessary (level transitions, checkpoints)

5. **Security**: Validate save file integrity in production builds

See Also
--------

- :doc:`gamemanager` - Integration with main game loop
- :doc:`../development/testing` - Testing save/load functionality