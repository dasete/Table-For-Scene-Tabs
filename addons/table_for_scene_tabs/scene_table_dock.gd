@tool
extends Control
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var grid_container: GridContainer = %GridContainer
var scene_buttons: Array = []
var button_scene = preload("res://addons/table_for_scene_tabs/scene_table_button.tscn")

# Color persistence
var scene_colors: Dictionary = {}
var config_file_path: String = "res://addons/table_for_scene_tabs/scene_table_colors.cfg"

var predefined_colors = [
	"#a62b2b", "#a66a11", "#6e4f27", "#28854d", "#355c2a", "#0e8f8f", "#2659a6", "#4328ad", "#8722a1", "#ad2878", "#757575"
]

# For monitoring scene changes
var last_open_scenes: Array = []
var scene_monitor_timer: Timer

func _ready():
	load_scene_colors()
	connect_editor_signals()
	setup_scene_monitor()
	update_scene_tabs()

# New method for continuous monitoring
func setup_scene_monitor():
	scene_monitor_timer = Timer.new()
	scene_monitor_timer.wait_time = 0.1  # Check every 100ms
	scene_monitor_timer.timeout.connect(_check_scene_changes)
	add_child(scene_monitor_timer)
	scene_monitor_timer.start()
	
	# Save initial scene list
	last_open_scenes = EditorInterface.get_open_scenes().duplicate()

func _check_scene_changes():
	var current_open_scenes = EditorInterface.get_open_scenes()
	
	# Check if the scene list has changed
	if not arrays_equal(current_open_scenes, last_open_scenes):
		last_open_scenes = current_open_scenes.duplicate()
		call_deferred("update_scene_tabs")

# Helper function to compare arrays
func arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	
	return true

func load_scene_colors():
	var config = ConfigFile.new()
	var err = config.load(config_file_path)
	
	if err == OK:
		for scene_path in config.get_sections():
			var color_string = config.get_value(scene_path, "color", "")
			if color_string != "":
				scene_colors[scene_path] = Color.from_string(color_string, Color.WHITE)

func save_scene_colors():
	var config = ConfigFile.new()
	
	for scene_path in scene_colors:
		config.set_value(scene_path, "color", scene_colors[scene_path].to_html())
	
	config.save(config_file_path)

func set_scene_color(scene_path: String, color: Color):
	scene_colors[scene_path] = color
	save_scene_colors()
	
	# Update the corresponding button
	for button in scene_buttons:
		if button.get_scene_path() == scene_path:
			button.set_background_color(color)
			break

func remove_scene_color(scene_path: String):
	if scene_path in scene_colors:
		scene_colors.erase(scene_path)
		save_scene_colors()
		
		# Update the corresponding button
		for button in scene_buttons:
			if button.get_scene_path() == scene_path:
				button.reset_background_color()
				break

func get_scene_color(scene_path: String) -> Color:
	return scene_colors.get(scene_path, Color.WHITE)

func connect_editor_signals():
	# Signal when a scene is opened
	if EditorInterface.get_selection().selection_changed.is_connected(_on_editor_selection_changed):
		return

	# Various editor signals for scene changes
	var editor_selection = EditorInterface.get_selection()
	if editor_selection:
		editor_selection.selection_changed.connect(_on_editor_selection_changed)

	# Scene tab changes via the FileSystem
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.filesystem_changed.connect(_on_filesystem_changed)

	# Via EditorInterface directly - scene was switched
	var main_screen = EditorInterface.get_editor_main_screen()
	if main_screen and main_screen.has_signal("scene_changed"):
		main_screen.scene_changed.connect(_on_scene_changed)

func update_scene_tabs():
	if not EditorInterface.get_open_scenes():
		return

	# Use call_deferred to avoid race conditions
	call_deferred("_clear_and_rebuild_buttons")

func _clear_and_rebuild_buttons():
	var open_scenes = EditorInterface.get_open_scenes()
	var current_scene_path = EditorInterface.get_edited_scene_root()
	var current_path = ""

	if current_scene_path:
		current_path = current_scene_path.scene_file_path

	# IMPORTANT: Disconnect signals before deleting
	for button in scene_buttons:
		if is_instance_valid(button):
			# Disconnect all signals from the button
			if button.scene_selected.is_connected(_on_scene_selected):
				button.scene_selected.disconnect(_on_scene_selected)
			if button.color_change_requested.is_connected(_on_color_change_requested):
				button.color_change_requested.disconnect(_on_color_change_requested)

			button.queue_free()

	scene_buttons.clear()

	# Create new buttons for each open scene
	for scene_path in open_scenes:
		var button_instance = button_scene.instantiate()
		grid_container.add_child(button_instance)

		# Initialize the button with scene data and saved color
		var saved_color = get_scene_color(scene_path)
		button_instance.initialize_button(scene_path, scene_path == current_path, saved_color)

		# Connect the signals with DEFERRED flag
		button_instance.scene_selected.connect(_on_scene_selected, CONNECT_DEFERRED)
		button_instance.color_change_requested.connect(_on_color_change_requested, CONNECT_DEFERRED)

		scene_buttons.append(button_instance)

func _on_color_change_requested(scene_path: String):
	# Create color selection dialog
	show_color_picker(scene_path)

func show_color_picker(scene_path: String):
	var color_dialog = AcceptDialog.new()
	color_dialog.title = "Pick a color for button background"
	color_dialog.size = Vector2(400, 300)
	
	var ok_button = color_dialog.get_ok_button()
	color_dialog.add_cancel_button("Cancel")
	color_dialog.add_button("Reset Color", true, "reset_button_clicked")
	
	
	var vbox = VBoxContainer.new()
	color_dialog.add_child(vbox)
	
	var introduction_label = Label.new()
	introduction_label.text = "Use color picker or a predefined color:"
	vbox.add_child(introduction_label)
	
	var color_picker = ColorPicker.new()
	color_picker.color = get_scene_color(scene_path)
	vbox.add_child(color_picker)
	
	var predefinied_colors_header = Label.new()
	predefinied_colors_header.text = "Predefined colors:"
	vbox.add_child(predefinied_colors_header)
	
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	# Create multiple color buttons for all predefined colors
	for i in range(predefined_colors.size()):
		var color_button = Button.new()
		color_button.custom_minimum_size = Vector2(30, 30)
		color_button.text = ""  # No text, just show color
		
		var base_color = Color.from_string(predefined_colors[i], Color.WHITE)
		
		# Normal StyleBox
		var normal_stylebox = StyleBoxFlat.new()
		normal_stylebox.bg_color = base_color
		
		# Hover StyleBox
		var hover_stylebox = StyleBoxFlat.new()
		hover_stylebox.bg_color = base_color.darkened(0.2)
		hover_stylebox.border_width_left = 1
		hover_stylebox.border_width_right = 1
		hover_stylebox.border_width_top = 1
		hover_stylebox.border_width_bottom = 1
		hover_stylebox.border_color = Color.GRAY
		
		# Pressed StyleBox
		var pressed_stylebox = StyleBoxFlat.new()
		pressed_stylebox.bg_color = base_color.darkened(0.3)
		pressed_stylebox.border_width_left = 1
		pressed_stylebox.border_width_right = 1
		pressed_stylebox.border_width_top = 1
		pressed_stylebox.border_width_bottom = 1
		pressed_stylebox.border_color = Color.GRAY
		
		color_button.add_theme_stylebox_override("normal", normal_stylebox)
		color_button.add_theme_stylebox_override("hover", hover_stylebox)
		color_button.add_theme_stylebox_override("pressed", pressed_stylebox)
		
		button_container.add_child(color_button)
		
		# Signal connection with closure for correct index
		var color_index = i
		color_button.pressed.connect(func():
			var selected_color = Color.from_string(predefined_colors[color_index], Color.WHITE)
			set_scene_color(scene_path, selected_color)
			color_dialog.queue_free()
		)
	
	ok_button.pressed.connect(func(): 
		set_scene_color(scene_path, color_picker.color)
		color_dialog.queue_free()
	)
	
	color_dialog.custom_action.connect(func(action: String):
		if action == "reset_button_clicked":
			remove_scene_color(scene_path)
			color_dialog.queue_free()
	)
	
	color_dialog.close_requested.connect(func():
		color_dialog.queue_free()
	)
	
	# Add dialog to scene and show
	get_viewport().add_child(color_dialog)
	color_dialog.popup_centered()

func _on_editor_selection_changed():
	# Update when the selection in the editor changes
	call_deferred("update_scene_tabs")

func _on_filesystem_changed():
	# Update when the filesystem changes (scene opened/closed)
	call_deferred("update_scene_tabs")

func _on_scene_changed():
	# Update when the current scene is switched
	call_deferred("update_scene_tabs")

func _on_scene_selected(scene_path: String):
	# Switch to the selected scene
	EditorInterface.open_scene_from_path(scene_path)

func on_editor_change():
	# External method called by the plugin
	call_deferred("update_scene_tabs")

func set_grid_columns(columns: int):
	if grid_container:
		grid_container.columns = columns

# Cleanup when plugin is disabled
func _exit_tree():
	# Stop timer and cleanup
	if scene_monitor_timer:
		scene_monitor_timer.stop()
		scene_monitor_timer.queue_free()
	
	# Disconnect all signals and cleanup
	for button in scene_buttons:
		if is_instance_valid(button):
			if button.scene_selected.is_connected(_on_scene_selected):
				button.scene_selected.disconnect(_on_scene_selected)
			if button.color_change_requested.is_connected(_on_color_change_requested):
				button.color_change_requested.disconnect(_on_color_change_requested)
