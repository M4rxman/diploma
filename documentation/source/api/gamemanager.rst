GameManager API Reference
=========================

.. currentmodule:: scripts.GameManager

Overview
--------

The **GameManager** class serves as the central coordination system for all major game systems. It handles initialization, state management, user input processing, and communication between different game subsystems.

.. note::
   GameManager follows the singleton pattern and should be accessed through the scene tree structure in Godot.

Class Definition
----------------

.. class:: GameManager

   Central game management system that coordinates all major game systems including player state, enemy AI, level generation, camera control, and save/load operations.

   **Inherits**: Node3D

   **Groups**: "game_manager"

Core Properties
---------------

.. attribute:: player
   :type: Node

   Reference to the player character node. Automatically assigned via @onready annotation.

.. attribute:: save_manager
   :type: SaveManager

   Reference to the save/load management system.

.. attribute:: level_manager
   :type: DynamicLevelManager

   Reference to the level generation and management system.

.. attribute:: game_ui
   :type: Control

   Reference to the game's user interface controller.

.. attribute:: current_wave
   :type: int
   :value: 0

   Current wave number in the spawning system (0-indexed).

.. attribute:: game_started
   :type: bool
   :value: false

   Flag indicating whether the game session has begun.

.. attribute:: level_completed
   :type: bool
   :value: false

   Flag indicating whether the current level has been completed.

Signals
-------

.. signal:: wave_changed(wave_number: int)

   Emitted when a new enemy wave begins.

   :param wave_number: The new wave number (0-indexed)

.. signal:: enemies_count_changed(count: int)

   Emitted when the number of active enemies changes.

   :param count: Current number of active enemies

.. signal:: level_completed_signal

   Emitted when all waves in the current level are completed.

Core Methods
------------

Camera Management
~~~~~~~~~~~~~~~~~

.. method:: setup_camera()

   Set up the camera to the correct position and angle.

   Resets camera to proper isometric-like view with position at (0, 20, 6) looking at the world origin. Sets appropriate field of view for gameplay.

   **Implementation Details:**
   
   - Position: Vector3(0, 20, 6)
   - Target: Vector3(0, 0, 0) 
   - FOV: 60.0 degrees
   - Up vector: Vector3.UP

UI Management
~~~~~~~~~~~~~

.. method:: setup_game_ui()

   Create and setup the game UI system.

   Instantiates the GameUI script and adds it to the scene tree as a CanvasLayer for proper rendering order above 3D content.

   **Process:**

   1. Loads UI script from "res://ui/GameUI.gd"
   2. Creates CanvasLayer named "UILayer"
   3. Adds UI to CanvasLayer for proper Z-ordering

Input and Player Control
~~~~~~~~~~~~~~~~~~~~~~~~

.. method:: handle_mouse_cursor()

   Handle player rotation based on mouse cursor position.

   Uses camera ray casting to determine where the mouse is pointing in 3D space and rotates the player to look at that position. Only operates when player is alive.

   **Algorithm:**

   1. Get mouse position in viewport coordinates
   2. Project ray from camera through mouse position
   3. Perform ray intersection with world geometry
   4. Rotate player to look at intersection point

   .. warning::
      This method is automatically called from _physics_process() and should not be called manually.

Game State Management
~~~~~~~~~~~~~~~~~~~~~

.. method:: start_new_game()

   Initialize a new game session.

   Resets game state, player stats, and positions the player at the center of the generated level. Called when starting a fresh game or after loading fails.

   **Resets:**

   - current_wave = 0
   - game_started = true  
   - level_completed = false
   - Player health to max_health
   - Player ammo to max_ammo
   - Player position to level center

.. method:: save_current_game()

   Save the current game state.

   Collects current player state, enemy positions, level settings, and passes them to the SaveManager for persistence to disk.

   **Saved Data:**

   - Player position, health, and ammo
   - Enemy positions and states
   - Level generation parameters
   - Current wave progress

.. method:: load_saved_game()

   Load saved game state from disk.

   Attempts to restore previous game session through SaveManager. If loading fails, continues with current session.

.. method:: regenerate_current_level()

   Regenerate the current level with new settings.

   Clears UI messages, resets game state, and triggers level regeneration through the DynamicLevelManager. Repositions camera after regeneration is complete.

   **Process:**

   1. Clear death/victory UI messages
   2. Reset wave and completion state
   3. Trigger level regeneration
   4. Wait 0.5 seconds for generation
   5. Reposition camera

Enemy Management
~~~~~~~~~~~~~~~~

.. method:: get_current_enemies() -> Array

   Get all current enemies in the scene.

   :returns: Array of enemy nodes currently in the "enemies" group
   :rtype: Array

.. method:: _turn_on_enemy_ai() -> bool

   Turn on AI for all enemies.

   Activates AI behavior for all enemies currently in the scene. Used when resuming game or starting new waves.

   :returns: true if all enemies have AI enabled successfully, false otherwise
   :rtype: bool

   **Implementation:**

   .. code-block:: gdscript

      func _turn_on_enemy_ai() -> bool:
          var enemies = get_current_enemies()
          var success = true
          for enemy in enemies:
              if enemy.has_method("_set_ai_to_true"):
                  enemy._set_ai_to_true()
              else:
                  success = false
          return success

.. method:: _turn_off_enemy_ai() -> bool

   Turn off AI for all enemies.

   Deactivates AI behavior for all enemies currently in the scene. Used for pausing or debugging purposes.

   :returns: true if all enemies have AI disabled successfully, false otherwise
   :rtype: bool

Event Handlers
--------------

Level Events
~~~~~~~~~~~~

.. method:: _on_level_generated()

   Called when the level generation is complete.

   Clears existing UI messages and attempts to load saved game or start new session.

.. method:: _on_enemies_spawned()

   Called when enemy spawning system is initialized.

   Confirms that the spawning system is ready for wave management.

Wave Management
~~~~~~~~~~~~~~~

.. method:: _on_wave_update(wave_number: int)

   Called when a new wave starts.

   :param wave_number: The wave number that started (0-indexed)

   Updates internal wave counter and notifies UI system of wave change.

Player Events
~~~~~~~~~~~~~

.. method:: _on_player_died()

   Handle player death event.

   Shows death UI and pauses enemy spawning until player respawns.

.. method:: _on_player_respawned()

   Handle player respawn event.

   Clears UI messages and resumes enemy spawning.

Utility Methods
---------------

.. method:: get_game_stats() -> Dictionary

   Get current game statistics for debugging and UI display.

   :returns: Dictionary containing current game state information
   :rtype: Dictionary

   **Return Structure:**

   .. code-block:: gdscript

      {
          "current_wave": int,
          "active_enemies": int, 
          "player_health": int,
          "player_ammo": int,
          "enemies_remaining_to_spawn": int,
          "level_completed": bool,
          "game_started": bool
      }

.. method:: print_game_stats()

   Print current game statistics to console for debugging.

   Outputs formatted game statistics including wave progression, enemy counts, and player status.

Getter Methods
--------------

.. method:: get_player() -> Node

   Get reference to the player character.

   :returns: Player node reference
   :rtype: Node

.. method:: get_level_manager() -> DynamicLevelManager

   Get reference to the level management system.

   :returns: Level manager instance
   :rtype: DynamicLevelManager

.. method:: get_current_level() -> Navigation_Map

   Get reference to the current level's navigation map.

   :returns: Current level navigation map, or null if no level exists
   :rtype: Navigation_Map

.. method:: get_level_spawner() -> LevelSpawner

   Get reference to the current level's enemy spawner.

   :returns: Level spawner instance, or null if no level exists  
   :rtype: LevelSpawner

.. method:: get_game_ui() -> Control

   Get reference to the game's UI controller.

   :returns: Game UI controller instance
   :rtype: Control

Usage Examples
--------------

Basic Initialization
~~~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   # GameManager is automatically initialized via scene tree
   # Access through groups or direct reference
   
   var game_manager = get_tree().get_first_node_in_group("game_manager")
   if game_manager:
       var stats = game_manager.get_game_stats()
       print("Current wave: ", stats.current_wave)

Managing Game State
~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   # Start a new game session
   game_manager.start_new_game()
   
   # Save current progress
   game_manager.save_current_game()
   
   # Regenerate level for new challenge
   game_manager.regenerate_current_level()

AI Control
~~~~~~~~~~

.. code-block:: gdscript

   # Enable AI for all enemies
   var ai_enabled = game_manager._turn_on_enemy_ai()
   if not ai_enabled:
       print("Some enemies failed to enable AI")
   
   # Disable AI for debugging
   game_manager._turn_off_enemy_ai()

Best Practices
--------------

1. **Initialization Order**: Always ensure GameManager is initialized before accessing its subsystems.

2. **State Checking**: Check game_started flag before performing game-specific operations.

3. **Error Handling**: Always check return values from AI control methods.

4. **Performance**: Use get_current_enemies() sparingly as it queries the entire scene tree.

5. **Memory Management**: GameManager handles cleanup automatically, but custom game objects should be managed separately.

See Also
--------

- :doc:`savemanager` - Save/load system integration
- :doc:`levelspawner` - Enemy spawning coordination  
- :doc:`navigation` - Level navigation integration
- :doc:`../development/testing` - Testing GameManager functionality