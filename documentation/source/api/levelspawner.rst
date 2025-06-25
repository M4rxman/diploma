LevelSpawner API Reference
==========================

.. currentmodule:: Spawning.LevelSpawner

Overview
--------

The **LevelSpawner** class manages wave-based enemy spawning with progressive difficulty scaling. It coordinates with the Navigation_Map system for spawn positioning and integrates with game progression systems to provide challenging gameplay experiences.

.. note::
   LevelSpawner automatically scales enemy difficulty across waves and manages supply drops for resource management.

Class Definition
----------------

.. class:: LevelSpawner

   Level spawning system for enemies and supplies that manages wave-based enemy spawning with progressive difficulty, supply drops, and level completion detection.

   **Inherits**: Node3D

   **Groups**: "level_spawner"

Exported Properties
-------------------

.. attribute:: enemy_scene
   :type: PackedScene
   :value: preload("res://scenes/generic_enemy.tscn")

   Scene template for spawning enemies. All spawned enemies will be instances of this scene.

.. attribute:: supplies_scene
   :type: PackedScene  
   :value: preload("res://item/Supplies.tscn")

   Scene template for spawning supply crates during wave progression.

Wave Management Properties
--------------------------

.. attribute:: waves
   :type: Array
   :value: []

   Array of Wave objects defining enemy configurations for each wave.

.. attribute:: current_wave
   :type: Wave
   :value: null

   Reference to the currently active wave configuration.

.. attribute:: current_wave_number
   :type: int
   :value: -1

   Index of the current wave (0-indexed). -1 indicates no active wave.

.. attribute:: enemies_spawned_this_wave
   :type: int
   :value: 0

   Number of enemies already spawned in the current wave.

.. attribute:: enemies_remaining_to_spawn
   :type: int
   :value: 0

   Number of enemies still to be spawned in the current wave.

State Properties
----------------

.. attribute:: wave_completed
   :type: bool
   :value: false

   Flag indicating whether the current wave has been completed.

.. attribute:: all_waves_completed
   :type: bool
   :value: false

   Flag indicating whether all waves in the level have been completed.

.. attribute:: game_started
   :type: bool
   :value: false

   Flag indicating whether the spawning system has been activated.

.. attribute:: spawner_ready
   :type: bool
   :value: false

   Flag indicating whether the spawner has been properly initialized.

Navigation Properties
---------------------

.. attribute:: navmap
   :type: Navigation_Map
   :value: null

   Reference to the navigation map used for spawn positioning and pathfinding.

.. attribute:: navigation_region
   :type: NavigationRegion3D
   :value: null

   Reference to the 3D navigation region for AI movement.

Internal Components
-------------------

.. attribute:: timer
   :type: Timer

   Internal timer controlling spawn intervals between enemies in a wave.

Signals
-------

.. signal:: wave_update(wave_number: int)

   Emitted when a new wave begins spawning.

   :param wave_number: The wave number that started (0-indexed)

.. signal:: level_complete

   Emitted when all waves have been completed successfully.

.. signal:: drop_item(item_scene: PackedScene)

   Emitted when an item should be dropped in the game world.

   :param item_scene: The PackedScene to instantiate as a drop

Core Methods
------------

Initialization and Reset
~~~~~~~~~~~~~~~~~~~~~~~~

.. method:: reset()

   Reset the spawner for a new level.

   Clears all current spawning state, removes existing enemies and supplies, and prepares the spawner for a fresh level. Should be called when transitioning between levels or restarting.

   **Process:**

   1. Stop current spawning timer
   2. Reset all state variables to defaults
   3. Remove all existing enemies from "enemies" group
   4. Remove all existing supplies from "supplies" group
   5. Wait one frame for cleanup
   6. Initialize waves for new level
   7. Start spawning system after 1-second delay

   .. code-block:: gdscript

      # Example usage
      level_spawner.reset()
      # Spawner will automatically reinitialize after cleanup

.. method:: initialize_waves() -> bool

   Find and initialize waves from the navigation map.

   Creates wave configurations with progressive difficulty scaling. Each wave has increasing enemy count, health, damage, and speed. Locates spawn points through the Navigation_Map system.

   :returns: true if waves were successfully initialized, false if setup failed
   :rtype: bool

   **Wave Configuration:**

   .. list-table:: Default Wave Settings
      :widths: 10 15 15 15 15 20 10
      :header-rows: 1

      * - Wave
        - Enemies
        - Health
        - Damage
        - Speed
        - Spawn Delay
        - Supplies
      * - 1
        - 3
        - 40
        - 15
        - 3.0
        - 2.0s
        - Yes
      * - 2
        - 2
        - 70
        - 25
        - 4.0
        - 1.5s
        - Yes
      * - 3
        - 4
        - 100
        - 35
        - 5.0
        - 1.0s
        - No
      * - 4
        - 5
        - 70
        - 25
        - 4.0
        - 1.5s
        - Yes
      * - 5
        - 6
        - 100
        - 35
        - 5.0
        - 1.0s
        - No

Wave Execution
~~~~~~~~~~~~~~

.. method:: start_waves() -> bool

   Start the wave system.

   Begins the sequential spawning of enemy waves. Requires successful initialization before calling. Sets up the first wave and begins the spawning cycle.

   :returns: true if waves started successfully, false if spawner not ready
   :rtype: bool

   **Prerequisites:**
   
   - spawner_ready must be true
   - waves array must contain at least one wave
   - Navigation system must be functional

.. method:: start_next_wave()

   Start the next wave in sequence.

   Transitions to the next wave configuration or completes all waves if no more remain. Updates wave counters and begins enemy spawning timer.

   **Process:**

   1. Check if more waves remain
   2. Increment wave counter
   3. Load next wave configuration  
   4. Reset wave-specific counters
   5. Emit wave_update signal
   6. Start spawning timer

Enemy Spawning
~~~~~~~~~~~~~~

.. method:: spawn_enemy()

   Spawn a single enemy for the current wave.

   Instantiates an enemy with current wave's difficulty parameters, positions it at a valid spawn location, and connects death signals for wave progression tracking.

   **Enemy Configuration Process:**

   1. Instantiate enemy from enemy_scene
   2. Set health based on current_wave.health
   3. Set damage based on current_wave.damage  
   4. Set movement speed based on current_wave.move_speed
   5. Position at random spawn point
   6. Enable AI behavior
   7. Connect death signal for tracking

   .. warning::
      This method should only be called by the internal timer system. Manual calls may disrupt wave balance.

Supply Management
~~~~~~~~~~~~~~~~~

.. method:: spawn_supplies_near_player()

   Spawn supplies near the player at ground level.

   Creates supply drops in the vicinity of the player character. Uses physics raycasting to ensure supplies land on solid ground. Called during wave progression for resource management.

   **Algorithm:**

   1. Locate player in "player" group
   2. Generate random offset positions around player
   3. Test each position for ground collision
   4. Spawn supplies at first valid position
   5. Fallback to player position + height if no valid position found

   **Spawn Parameters:**

   - Distance from player: 2-4 units minimum, 4-8 units maximum
   - Height: 3-5 units above ground for physics drop
   - Collision testing: Ensures supplies land on solid surfaces

.. method:: create_supplies_at_position(position: Vector3)

   Create supplies at the specified position.

   :param position: World position where supplies should be created

   Instantiates supplies scene at the given position and adds it to the current scene tree.

.. method:: spawn_wave_completion_supplies()

   Spawn supplies after wave completion.

   Creates 1-3 supply crates near the player as a reward for completing a wave. Positions supplies at safe distances from the player to avoid interference with combat.

Positioning and Validation
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. method:: get_random_spawn_position() -> Vector3

   Get a random valid spawn position.

   Queries the navigation map for empty positions or falls back to basic random positioning with collision checking. Ensures enemies spawn at appropriate height above ground.

   :returns: Vector3 world position suitable for enemy spawning
   :rtype: Vector3

   **Positioning Strategy:**

   1. **Primary**: Use navmap.get_random_empty_vec3() if available
   2. **Secondary**: Test random positions within level bounds
   3. **Fallback**: Return basic random position with safety height

   **Position Constraints:**

   - X/Z range: -15 to +15 world units (fallback mode)
   - Y position: Fixed at 3.0 units above ground
   - Maximum attempts: 10 position tests before fallback

.. method:: is_position_clear(pos: Vector3) -> bool

   Check if spawn position is clear of obstacles.

   :param pos: World position to test for clearance
   :returns: true if position is clear for spawning, false if blocked
   :rtype: bool

   Uses physics raycasting to detect ground collision and ensure spawn position validity.

.. method:: is_spawn_position_clear(pos: Vector3) -> bool

   Check if spawn position is clear for supplies.

   :param pos: World position to test for clearance  
   :returns: true if position has ground contact, false if floating
   :rtype: bool

   Specialized version for supply drops that ensures solid ground contact.

Event Handlers
--------------

.. method:: _on_timer_timeout()

   Called when spawn timer times out.

   Internal callback that spawns the next enemy in the current wave. Handles wave completion detection and timer management.

   **Logic Flow:**

   1. Check if game is active and wave is ongoing
   2. Verify enemies remain to be spawned
   3. Spawn next enemy via spawn_enemy()
   4. Stop timer if wave spawning is complete

.. method:: _on_enemy_died(enemy)

   Handle enemy death and check for supply drops.

   :param enemy: The enemy node that died

   Processes enemy death events, checks for wave completion conditions, and manages supply drop triggers based on kill count thresholds.

   **Death Processing:**

   1. Wait one frame for scene tree updates
   2. Count remaining enemies in scene
   3. Calculate enemies killed in current wave
   4. Check supply drop conditions
   5. Evaluate wave completion criteria
   6. Trigger appropriate progression events

Wave Completion
~~~~~~~~~~~~~~~

.. method:: complete_current_wave()

   Complete current wave and start next one.

   Marks current wave as completed, stops spawning timer, provides brief pause, spawns completion rewards, and initiates next wave.

   **Completion Sequence:**

   1. Set wave_completed flag
   2. Stop spawning timer
   3. Wait 2 seconds for player to process completion
   4. Spawn wave completion supplies
   5. Call start_next_wave()

.. method:: complete_all_waves()

   Called when all waves are completed.

   Finalizes level completion by stopping all spawning activities and emitting completion signal for game state management.

Information Methods
-------------------

.. method:: get_enemies_remaining() -> int

   Get number of enemies remaining to spawn in current wave.

   :returns: Integer count of enemies yet to be spawned
   :rtype: int

.. method:: get_current_wave_number() -> int

   Get current wave number (0-indexed).

   :returns: Integer representing current wave index
   :rtype: int

.. method:: get_total_waves() -> int

   Get total number of waves configured.

   :returns: Integer count of total waves in this level
   :rtype: int

.. method:: is_spawner_ready() -> bool

   Check if spawner is ready for operation.

   :returns: true if spawner has been initialized and is ready to spawn
   :rtype: bool

Usage Examples
--------------

Basic Level Setup
~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   # LevelSpawner is typically managed by the level system
   var spawner = get_tree().get_first_node_in_group("level_spawner")
   
   # Reset for new level
   spawner.reset()
   
   # Check readiness before starting
   if spawner.is_spawner_ready():
       var started = spawner.start_waves()
       if started:
           print("Wave system activated!")

Monitoring Progress
~~~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   # Get current wave information
   var current_wave = spawner.get_current_wave_number()
   var total_waves = spawner.get_total_waves()
   var remaining = spawner.get_enemies_remaining()
   
   print("Wave %d/%d - %d enemies remaining" % [current_wave + 1, total_waves, remaining])

Signal Connection
~~~~~~~~~~~~~~~~~

.. code-block:: gdscript

   # Connect to spawner signals for UI updates
   spawner.wave_update.connect(_on_wave_started)
   spawner.level_complete.connect(_on_level_complete)
   spawner.drop_item.connect(_on_item_dropped)
   
   func _on_wave_started(wave_number: int):
       ui.show_wave_message(wave_number + 1)
   
   func _on_level_complete():
       ui.show_victory_screen()

Best Practices
--------------

1. **Initialization**: Always call reset() when transitioning between levels.

2. **Signal Management**: Connect to wave_update and level_complete signals for proper game flow.

3. **Performance**: Avoid frequent calls to get_current_enemies() during active spawning.

4. **Error Handling**: Check is_spawner_ready() before starting wave operations.

5. **Supply Balance**: Monitor supply drop frequency to maintain appropriate resource scarcity.

Common Issues
-------------

**Spawner Not Ready**
   Ensure Navigation_Map is properly initialized before calling reset().

**Enemies Not Spawning**
   Check that enemy_scene is valid and timer is functioning correctly.

**Supply Drops Failing**
   Verify supplies_scene is assigned and player exists in "player" group.

**Wave Not Progressing**
   Confirm enemy death signals are properly connected via spawn_enemy().

See Also
--------

- :doc:`gamemanager` - Central coordination with spawning system
- :doc:`navigation` - Navigation map integration for spawn positioning
- :doc:`../development/testing` - Testing spawning functionality
- :doc:`../architecture/game_flow` - Wave progression in overall game flow