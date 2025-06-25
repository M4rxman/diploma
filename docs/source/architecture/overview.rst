System Architecture Overview
=============================

Game Systems Hierarchy
-----------------------

The Diploma game project follows a hierarchical component architecture:

.. code-block:: text

    GameManager (Central Coordinator)
    ├── Player (Character Controller)
    ├── SaveManager (Persistence System)  
    ├── DynamicLevelManager (Level Management)
    │   ├── Navigation_Map (Spatial Queries)
    │   └── LevelSpawner (Enemy Spawning)
    ├── GameUI (User Interface)
    └── Camera3D (Rendering View)

Component Responsibilities
--------------------------

**GameManager**
    Central coordination, input handling, state management

**SaveManager** 
    Game state persistence, file I/O operations

**LevelSpawner**
    Wave-based enemy spawning, difficulty progression

**Navigation_Map**
    Spatial queries, pathfinding, collision detection

**Player**
    Character movement, combat, input processing

Data Flow Architecture
----------------------

1. **Input Processing**: Player input → GameManager → Player
2. **Game State**: GameManager ↔ SaveManager ↔ File System  
3. **Enemy Management**: LevelSpawner → Navigation_Map → Enemy AI
4. **UI Updates**: Game Events → GameManager → GameUI
5. **Level Generation**: GameManager → DynamicLevelManager → Navigation_Map

Performance Considerations
--------------------------

- **Scene Tree Queries**: Minimized through group-based lookups
- **Physics Calculations**: Efficient raycasting for spawn positioning
- **Memory Management**: Automatic cleanup of defeated enemies
- **UI Rendering**: CanvasLayer separation for optimal performance
