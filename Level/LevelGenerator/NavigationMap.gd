# Helper script to set up navigation properly in Godot 4
extends Node

#class_name NavigationM

class Coord:
	var x: int
	var z: int
	
	func _init(x, z):
		self.x = x
		self.z = z
		
	func _to_string():
		# (x, z)
		return "(" + str(x) + ", " + str(z) + ")"
		
	func equals(coord):
		return coord.x == self.x and coord.z == self.z

static func setup_navigation_for_level(level_root: Node3D) -> NavigationRegion3D:
	# Find or create NavigationRegion3D
	var nav_region = level_root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		level_root.add_child(nav_region)
	
	# Create navigation mesh if needed
	if not nav_region.navigation_mesh:
		var nav_mesh = NavigationMesh.new()
		
		# Configure navigation mesh settings
		nav_mesh.agent_height = 2.0
		nav_mesh.agent_radius = 0.5
		nav_mesh.agent_max_climb = 0.5
		nav_mesh.agent_max_slope = 45.0
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		nav_mesh.edge_max_length = 12.0
		nav_mesh.edge_max_error = 1.3
		
		nav_region.navigation_mesh = nav_mesh
	
	# Bake navigation mesh
	if nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
	
	return nav_region

static func create_navigation_obstacle(obstacle_node: Node3D) -> NavigationObstacle3D:
	# Add NavigationObstacle3D to dynamic obstacles
	var nav_obstacle = NavigationObstacle3D.new()
	obstacle_node.add_child(nav_obstacle)
	
	# Configure obstacle
	nav_obstacle.radius = 1.0
	nav_obstacle.height = 2.0
	
	return nav_obstacle

static func debug_navigation(nav_region: NavigationRegion3D):
	# Enable debug visualization
	nav_region.debug_enabled = true
	
	# You can also use NavigationServer3D for more debug options
	NavigationServer3D.set_debug_enabled(true)
