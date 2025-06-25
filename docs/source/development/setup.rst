Development Setup Guide
=======================

Prerequisites
-------------

**Required Software:**

- Godot Engine 4.2.1 or later
- Git for version control
- Python 3.8+ (for documentation generation)

**Recommended Tools:**

- VSCode with Godot syntax highlighting
- Godot LSP for code completion
- Git GUI client (optional)

Project Setup
-------------

1. **Clone Repository**:

   .. code-block:: bash

      git clone [YOUR_REPOSITORY_URL]
      cd diploma-game

2. **Open in Godot**:

   - Launch Godot Engine
   - Click "Import"
   - Select project.godot file
   - Click "Import & Edit"

3. **Verify Setup**:

   - Press F5 to run the game
   - Check for any error messages
   - Confirm player controls work (WASD + mouse)

Documentation Setup
-------------------

To build this documentation locally:

.. code-block:: bash

   # Install documentation tools
   ./scripts/install_docs_tools.sh
   
   # Generate documentation
   ./scripts/generate_docs.sh
   
   # Open in browser
   open docs/build/index.html

Development Workflow
--------------------

1. **Feature Development**:

   .. code-block:: bash

      git checkout -b feature/your-feature-name
      # Make changes
      git add .
      git commit -m "feat: add your feature description"

2. **Testing**:

   - Run automated tests via GUT framework
   - Test manually in Godot editor
   - Verify documentation updates

3. **Code Review**:

   .. code-block:: bash

      git push origin feature/your-feature-name
      # Create pull request
      # Address review feedback

4. **Integration**:

   .. code-block:: bash

      git checkout main
      git pull origin main
      git merge feature/your-feature-name
