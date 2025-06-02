@tool
extends Button

signal scene_selected(scene_path: String)
signal color_change_requested(scene_path: String)

var scene_path: String = ""
var is_current_scene: bool = false
var background_color: Color = Color.WHITE
var original_stylebox: StyleBox

func _ready():
	# Enable toggle mode for the standard pressed look
	self.toggle_mode = true
	
	# Save original StyleBox
	original_stylebox = get_theme_stylebox("normal").duplicate()
	
	# Use CONNECT_DEFERRED for all signals
	self.pressed.connect(_on_button_pressed, CONNECT_DEFERRED)
	self.gui_input.connect(_on_gui_input, CONNECT_DEFERRED)

func initialize_button(path: String, is_current: bool, color: Color = Color.WHITE):
	scene_path = path
	is_current_scene = is_current
	background_color = color
	
	setup_button_appearance()

func setup_button_appearance():	
	# Extract scene name from path
	var scene_name = scene_path.get_file().get_basename()
	self.text = scene_name
	tooltip_text = scene_path

	# Load icon of the scene's root node
	var scene_icon = get_scene_root_icon()
	if scene_icon:
		self.icon = scene_icon

	# Button alignment: Icon left, text right next to it
	self.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	self.alignment = HORIZONTAL_ALIGNMENT_LEFT
	self.expand_icon = false

	self.autowrap_mode = 1

	# Set button pressed state for current scene
	self.button_pressed = is_current_scene

	# Apply background color
	apply_background_color()

func apply_background_color():
	if background_color != Color.WHITE:
		# Create a custom StyleBox with the desired color
		var stylebox = original_stylebox.duplicate() as StyleBoxFlat
		if stylebox:
			stylebox.bg_color = background_color
			add_theme_stylebox_override("normal", stylebox)
			add_theme_stylebox_override("hover", stylebox)
			
			# For pressed state use a slightly darker variant
			var pressed_stylebox = stylebox.duplicate() as StyleBoxFlat
			pressed_stylebox.bg_color = background_color.darkened(0.2)
			add_theme_stylebox_override("pressed", pressed_stylebox)
	else:
		# Restore default style
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")

func set_background_color(color: Color):
	background_color = color
	apply_background_color()

func reset_background_color():
	background_color = Color.WHITE
	apply_background_color()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			# Right click detected - request color selection
			color_change_requested.emit(scene_path)

func get_scene_root_icon() -> Texture2D:
	# Load the scene to get the root node icon
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		return null

	# Create temporary instance to determine node type
	var temp_instance = packed_scene.instantiate()
	if not temp_instance:
		return null

	var root_class = temp_instance.get_class()
	# Important: use queue_free() instead of free()
	temp_instance.queue_free()

	# Get the corresponding icon from the editor theme
	var editor_theme = EditorInterface.get_editor_theme()
	var icon = editor_theme.get_icon(root_class, "EditorIcons")

	# Fallback icons for common node types
	if not icon:
		match root_class:
			"Node2D":
				icon = editor_theme.get_icon("Node2D", "EditorIcons")
			"Control":
				icon = editor_theme.get_icon("Control", "EditorIcons")
			"Node3D":
				icon = editor_theme.get_icon("Node3D", "EditorIcons")
			"RigidBody2D":
				icon = editor_theme.get_icon("RigidBody2D", "EditorIcons")
			"CharacterBody2D":
				icon = editor_theme.get_icon("CharacterBody2D", "EditorIcons")
			"StaticBody2D":
				icon = editor_theme.get_icon("StaticBody2D", "EditorIcons")
			_:
				icon = editor_theme.get_icon("Node", "EditorIcons")

	return icon

func _on_button_pressed():
	# Use call_deferred to avoid timing issues
	call_deferred("emit_scene_selected")

func emit_scene_selected():
	scene_selected.emit(scene_path)

func update_current_state(is_current: bool):
	is_current_scene = is_current
	# Only update the pressed state, don't reset the complete appearance
	self.button_pressed = is_current

func get_scene_path() -> String:
	return scene_path
