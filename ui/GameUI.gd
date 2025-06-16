# ui/GameUI.gd - Fixed UI system with crosshair removed
extends Control

# UI Elements
@onready var health_bar: ProgressBar
@onready var health_label: Label
@onready var ammo_label: Label
@onready var wave_label: Label
@onready var enemy_count_label: Label
# REMOVED: @onready var crosshair: TextureRect

# Reference to player and game manager for updates
var player: Node3D
var game_manager: GameManager

func _ready():
	# Create UI elements programmatically
	setup_ui_elements()
	
	# Add to groups for easy finding
	add_to_group("ui")
	add_to_group("game_ui")
	
	# Find player and game manager
	player = get_tree().get_first_node_in_group("player")
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	# Connect to player signals
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("ammo_changed"):
			player.ammo_changed.connect(_on_ammo_changed)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
		if player.has_signal("player_respawned"):
			player.player_respawned.connect(_on_player_respawned)
	
	# Connect to game manager signals
	if game_manager:
		if game_manager.has_signal("wave_changed"):
			game_manager.wave_changed.connect(_on_wave_changed)
		if game_manager.has_signal("enemies_count_changed"):
			game_manager.enemies_count_changed.connect(_on_enemies_count_changed)
		if game_manager.has_signal("level_completed_signal"):
			game_manager.level_completed_signal.connect(_on_level_completed)
	
	# Connect to supplies pickup signals
	_connect_to_supplies()

func _connect_to_supplies():
	""""Connect to existing and future supplies in the scene"""
	# Connect to existing supplies
	var supplies_in_scene = get_tree().get_nodes_in_group("supplies")
	for supplies in supplies_in_scene:
		if supplies.has_signal("picked_up"):
			supplies.picked_up.connect(_on_supplies_picked_up)
	
	# Set up a timer to periodically check for new supplies
	var supplies_timer = Timer.new()
	supplies_timer.wait_time = 1.0
	supplies_timer.timeout.connect(_check_for_new_supplies)
	add_child(supplies_timer)
	supplies_timer.start()

func _check_for_new_supplies():
	"""Check for new supplies and connect to their signals"""
	var supplies_in_scene = get_tree().get_nodes_in_group("supplies")
	for supplies in supplies_in_scene:
		if supplies.has_signal("picked_up") and not supplies.picked_up.is_connected(_on_supplies_picked_up):
			supplies.picked_up.connect(_on_supplies_picked_up)

func setup_ui_elements():
	"""Create and position all UI elements"""
	# Set up main control
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Health bar and label (top-left)
	var health_container = HBoxContainer.new()
	health_container.name = "HealthContainer"
	health_container.position = Vector2(20, 20)
	health_container.size = Vector2(250, 30)
	add_child(health_container)
	
	var health_icon = Label.new()
	health_icon.text = "❤️"
	health_icon.add_theme_font_size_override("font_size", 24)
	health_container.add_child(health_icon)
	
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.size = Vector2(150, 20)
	health_bar.show_percentage = false
	
	# Style the health bar
	var health_style = StyleBoxFlat.new()
	health_style.bg_color = Color.RED
	health_style.corner_radius_bottom_left = 5
	health_style.corner_radius_bottom_right = 5
	health_style.corner_radius_top_left = 5
	health_style.corner_radius_top_right = 5
	health_bar.add_theme_stylebox_override("fill", health_style)
	
	var health_bg_style = StyleBoxFlat.new()
	health_bg_style.bg_color = Color.DARK_RED
	health_bg_style.corner_radius_bottom_left = 5
	health_bg_style.corner_radius_bottom_right = 5
	health_bg_style.corner_radius_top_left = 5
	health_bg_style.corner_radius_top_right = 5
	health_bar.add_theme_stylebox_override("background", health_bg_style)
	
	health_container.add_child(health_bar)
	
	health_label = Label.new()
	health_label.text = "100/100"
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_container.add_child(health_label)
	
	# Ammo display (top-left, below health)
	var ammo_container = HBoxContainer.new()
	ammo_container.name = "AmmoContainer"
	ammo_container.position = Vector2(20, 60)
	ammo_container.size = Vector2(200, 30)
	add_child(ammo_container)
	
	var ammo_icon = Label.new()
	ammo_icon.text = "🔫"
	ammo_icon.add_theme_font_size_override("font_size", 20)
	ammo_container.add_child(ammo_icon)
	
	ammo_label = Label.new()
	ammo_label.text = "30/30"
	ammo_label.add_theme_font_size_override("font_size", 18)
	ammo_label.add_theme_color_override("font_color", Color.YELLOW)
	ammo_container.add_child(ammo_label)
	
	# Wave info (top-right)
	var wave_container = VBoxContainer.new()
	wave_container.name = "WaveContainer"
	wave_container.position = Vector2(get_viewport().get_visible_rect().size.x - 200, 20)
	wave_container.size = Vector2(180, 80)
	add_child(wave_container)
	
	wave_label = Label.new()
	wave_label.text = "Wave: 1"
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color.CYAN)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_container.add_child(wave_label)
	
	enemy_count_label = Label.new()
	enemy_count_label.text = "Enemies: 0"
	enemy_count_label.add_theme_font_size_override("font_size", 16)
	enemy_count_label.add_theme_color_override("font_color", Color.WHITE)
	enemy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_container.add_child(enemy_count_label)
	
	# REMOVED: Crosshair creation code
	
	# Instructions (bottom-left)
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "WASD: Move | Mouse: Aim | LMB: Shoot | Space: Jump | E: Interact\n1-4: Switch Weapons | R: Regenerate Level"
	instructions.position = Vector2(20, get_viewport().get_visible_rect().size.y - 60)
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(instructions)

# REMOVED: create_crosshair_texture function

# Function to clear all messages when level is regenerated
func clear_all_messages():
	"""Clear all temporary UI messages (death, victory, etc.)"""
	print("Clearing all UI messages")
	
	# Remove death overlay if it exists
	var death_overlay = get_node_or_null("DeathOverlay")
	if death_overlay:
		death_overlay.queue_free()
		print("Removed death overlay")
	
	# Remove any victory/level complete messages
	for child in get_children():
		if child.name.begins_with("VictoryMessage") or child.name.begins_with("LevelCompleteMessage"):
			child.queue_free()
			print("Removed victory message: ", child.name)
	
	# Remove any temporary message labels
	for child in get_children():
		if child is Label and (
			"LEVEL COMPLETE" in child.text or 
			"YOU DIED" in child.text or 
			"VICTORY" in child.text or
			"Wave" in child.text and "COMPLETE" in child.text or
			"Press SPACE to respawn" in child.text or
			"Press ESC to quit" in child.text
		):
			child.queue_free()
			print("Removed temporary message: ", child.text)
	
	# Also remove any ColorRect overlays (death screens)
	for child in get_children():
		if child is ColorRect and child.color == Color(0, 0, 0, 0.8):
			child.queue_free()
			print("Removed death screen overlay")
	
	# Reset wave display to wave 1
	if wave_label:
		wave_label.text = "Wave: 1"
		wave_label.add_theme_color_override("font_color", Color.CYAN)
	
	# Reset enemy count
	if enemy_count_label:
		enemy_count_label.text = "Enemies: 0"

func _on_health_changed(new_health: int, max_health: int):
	"""Update health display"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = new_health
	
	if health_label:
		health_label.text = str(new_health) + "/" + str(max_health)
	
	# Change color based on health percentage
	if health_bar and new_health > 0:
		var health_percent = float(new_health) / float(max_health)
		var health_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if health_style:
			if health_percent > 0.6:
				health_style.bg_color = Color.GREEN
			elif health_percent > 0.3:
				health_style.bg_color = Color.YELLOW
			else:
				health_style.bg_color = Color.RED

func _on_ammo_changed(new_ammo: int, max_ammo: int):
	"""Update ammo display"""
	if ammo_label:
		ammo_label.text = str(new_ammo) + "/" + str(max_ammo)
		
		# Change color based on ammo level
		var ammo_percent = float(new_ammo) / float(max_ammo)
		if ammo_percent > 0.5:
			ammo_label.add_theme_color_override("font_color", Color.YELLOW)
		elif ammo_percent > 0.2:
			ammo_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			ammo_label.add_theme_color_override("font_color", Color.RED)

func _on_wave_changed(wave_number: int):
	"""Update wave display"""
	if wave_label:
		wave_label.text = "Wave: " + str(wave_number + 1)

func _on_enemies_count_changed(count: int):
	"""Update enemy count display"""
	if enemy_count_label:
		enemy_count_label.text = "Enemies: " + str(count)

func show_wave_complete_message(wave_number: int):
	"""Show wave completion message with supplies info"""
	var message = Label.new()
	message.name = "WaveCompleteMessage_" + str(wave_number)
	message.text = "WAVE " + str(wave_number) + " COMPLETE!\nSupplies incoming!"
	message.add_theme_font_size_override("font_size", 32)
	message.add_theme_color_override("font_color", Color.GREEN)
	message.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, get_viewport().get_visible_rect().size.y / 2 - 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(message)
	
	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_property(message, "modulate", Color.TRANSPARENT, 3.0)
	tween.tween_callback(message.queue_free)

func show_level_complete_message():
	"""Show level completion message"""
	var message = Label.new()
	message.name = "LevelCompleteMessage"
	message.text = "LEVEL COMPLETE!\nPress R for new level"
	message.add_theme_font_size_override("font_size", 42)
	message.add_theme_color_override("font_color", Color.GOLD)
	message.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, get_viewport().get_visible_rect().size.y / 2 - 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(message)
	
	# Add to a group for easy cleanup
	message.add_to_group("victory_message")
	
	# Pulsing effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(message, "modulate", Color(1, 1, 1, 0.5), 1.0)
	tween.tween_property(message, "modulate", Color.WHITE, 1.0)

func show_death_message():
	"""Show player death message"""
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.name = "DeathOverlay"
	add_child(overlay)
	
	var message = Label.new()
	message.text = "YOU DIED!\nPress SPACE to respawn\nPress ESC to quit"
	message.add_theme_font_size_override("font_size", 36)
	message.add_theme_color_override("font_color", Color.RED)
	message.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, get_viewport().get_visible_rect().size.y / 2 - 75)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(message)

func _on_player_died():
	"""Handle player death UI"""
	show_death_message()

func _on_player_respawned():
	"""Handle player respawn UI cleanup"""
	# Remove death overlay if it exists
	if has_node("DeathOverlay"):
		get_node("DeathOverlay").queue_free()

func _on_level_completed():
	"""Handle level completion"""
	show_level_complete_message()

func show_pickup_message(item_name: String, heal_amount: int = 0, ammo_amount: int = 0):
	"""Show pickup confirmation message"""
	var message_parts = []
	if heal_amount > 0:
		message_parts.append("+" + str(heal_amount) + " Health")
	if ammo_amount > 0:
		message_parts.append("+" + str(ammo_amount) + " Ammo")
	
	var pickup_text = item_name
	if message_parts.size() > 0:
		pickup_text += "\n" + " & ".join(message_parts)
	
	var pickup_label = Label.new()
	pickup_label.text = pickup_text
	pickup_label.add_theme_font_size_override("font_size", 24)
	pickup_label.add_theme_color_override("font_color", Color.CYAN)
	pickup_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, get_viewport().get_visible_rect().size.y / 2 + 100)
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(pickup_label)
	
	# Animate pickup message
	var tween = create_tween()
	tween.parallel().tween_property(pickup_label, "position:y", pickup_label.position.y - 50, 1.5)
	tween.parallel().tween_property(pickup_label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(pickup_label.queue_free)

func _on_supplies_picked_up(heal_amount: int, ammo_amount: int):
	"""Handle supplies pickup notification"""
	show_pickup_message("Supplies Collected!", heal_amount, ammo_amount)

func update_enemy_count():
	"""Update enemy count from current scene"""
	if enemy_count_label:
		var enemies = get_tree().get_nodes_in_group("enemies")
		enemy_count_label.text = "Enemies: " + str(enemies.size())

func _process(_delta):
	"""Update UI elements that need constant updates"""
	# Update enemy count every frame (could be optimized)
	update_enemy_count()
	
	# Keep wave container positioned properly on window resize
	if wave_label:
		var wave_container = wave_label.get_parent()
		if wave_container:
			wave_container.position.x = get_viewport().get_visible_rect().size.x - 200
	
	# REMOVED: Crosshair centering code
	
	# Update instructions position
	var instructions = get_node_or_null("Instructions")
	if instructions:
		instructions.position.y = get_viewport().get_visible_rect().size.y - 60

# Utility functions for external access
func get_health_bar() -> ProgressBar:
	return health_bar

func get_ammo_label() -> Label:
	return ammo_label

func get_wave_label() -> Label:
	return wave_label

func get_enemy_count_label() -> Label:
	return enemy_count_label

# Emergency UI functions for debugging
func show_debug_message(text: String, duration: float = 3.0):
	"""Show a debug message"""
	var debug_label = Label.new()
	debug_label.text = "[DEBUG] " + text
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.add_theme_color_override("font_color", Color.MAGENTA)
	debug_label.position = Vector2(20, 120)
	add_child(debug_label)
	
	# Auto-remove after duration
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(debug_label.queue_free)
	add_child(timer)
	timer.start()

func flash_screen(color: Color = Color.RED, duration: float = 0.5):
	"""Flash the screen with a color"""
	var flash_overlay = ColorRect.new()
	flash_overlay.color = color
	flash_overlay.size = get_viewport().get_visible_rect().size
	flash_overlay.modulate.a = 0.5
	add_child(flash_overlay)
	
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate:a", 0.0, duration)
	tween.tween_callback(flash_overlay.queue_free)
