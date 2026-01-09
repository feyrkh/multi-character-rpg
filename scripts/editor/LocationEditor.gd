# LocationEditor.gd
# Visual editor for creating and editing location data
extends Control

const LOCATIONS_BASE_PATH = "res://data/locations"
const EditorLocationNodeScene = preload("res://scenes/editor/editor_location_node.tscn")

enum Tool { SELECT, CREATE_NODE, CREATE_LINK }

# Current area state
var current_area_id: String = ""
var current_dir_path: String = ""

# Editor data - node_name -> Dictionary with keys:
# display_name, position, is_discovered, is_instant_travel, is_new, is_modified, is_deleted
var node_data: Dictionary = {}

# Link data - Array of Dictionaries with keys:
# from, to, distance, is_new, is_deleted
var link_data: Array = []

# Selection state
var selected_node: String = ""
var selected_link_index: int = -1

# Tool state
var current_tool: Tool = Tool.SELECT
var link_first_node: String = ""  # For link creation workflow

# Visual node references
var _visual_nodes: Dictionary = {}  # node_name -> EditorLocationNode instance
var _link_lines: Array = []  # Line2D instances

# Dynamic containers (created at runtime)
var _path_lines_container: Control
var _nodes_container: Control
var _exit_marker: Control

# Flag to prevent feedback loops when updating UI
var _updating_properties: bool = false

# Node references
@onready var area_id_line_edit: LineEdit = $HSplitContainer/LeftPanel/MarginContainer/VBoxContainer/AreaIdLineEdit
@onready var load_button: Button = $HSplitContainer/LeftPanel/MarginContainer/VBoxContainer/LoadButton
@onready var file_tree: Tree = $HSplitContainer/LeftPanel/MarginContainer/VBoxContainer/FileTree

@onready var select_tool_btn: Button = $HSplitContainer/RightPanel/Toolbar/SelectToolBtn
@onready var create_node_btn: Button = $HSplitContainer/RightPanel/Toolbar/CreateNodeBtn
@onready var create_link_btn: Button = $HSplitContainer/RightPanel/Toolbar/CreateLinkBtn
@onready var save_button: Button = $HSplitContainer/RightPanel/Toolbar/SaveButton

@onready var canvas_panel: PanelContainer = $HSplitContainer/RightPanel/CanvasPanel
@onready var camera: Control = $HSplitContainer/RightPanel/CanvasPanel/Camera

@onready var properties_panel: PanelContainer = $HSplitContainer/RightPanel/PropertiesPanel
@onready var node_props: VBoxContainer = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/NodeProps
@onready var link_props: VBoxContainer = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/LinkProps
@onready var name_line_edit: LineEdit = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/NodeProps/NameLineEdit
@onready var pos_x_spinbox: SpinBox = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/NodeProps/PosContainer/PosXSpinBox
@onready var pos_y_spinbox: SpinBox = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/NodeProps/PosContainer/PosYSpinBox
@onready var discovered_checkbox: CheckBox = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/NodeProps/DiscoveredCheckBox
@onready var distance_spinbox: SpinBox = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/LinkProps/DistanceSpinBox
@onready var delete_button: Button = $HSplitContainer/RightPanel/PropertiesPanel/MarginContainer/HBoxContainer/DeleteButton

func _ready() -> void:
	# Connect signals
	load_button.pressed.connect(_on_load_pressed)
	save_button.pressed.connect(_on_save_pressed)

	select_tool_btn.pressed.connect(_on_select_tool_pressed)
	create_node_btn.pressed.connect(_on_create_node_tool_pressed)
	create_link_btn.pressed.connect(_on_create_link_tool_pressed)

	file_tree.item_selected.connect(_on_file_tree_item_selected)

	name_line_edit.text_changed.connect(_on_name_changed)
	pos_x_spinbox.value_changed.connect(_on_position_changed)
	pos_y_spinbox.value_changed.connect(_on_position_changed)
	discovered_checkbox.toggled.connect(_on_discovered_changed)
	distance_spinbox.value_changed.connect(_on_distance_changed)
	delete_button.pressed.connect(_on_delete_pressed)

	# Setup spinboxes
	pos_x_spinbox.min_value = -10000
	pos_x_spinbox.max_value = 10000
	pos_y_spinbox.min_value = -10000
	pos_y_spinbox.max_value = 10000
	distance_spinbox.min_value = 0
	distance_spinbox.max_value = 100
	distance_spinbox.value = 1

	# Wait for camera to initialize
	await get_tree().process_frame

	# Create containers in camera's content container
	var content = camera.get_content_container()

	_path_lines_container = Control.new()
	_path_lines_container.name = "PathLinesContainer"
	_path_lines_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_path_lines_container)

	_nodes_container = Control.new()
	_nodes_container.name = "NodesContainer"
	_nodes_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_nodes_container)

	_create_exit_marker(content)

	# Initial state
	_set_tool(Tool.SELECT)
	_update_properties_panel()
	_refresh_file_tree()

func _create_exit_marker(parent: Control) -> void:
	_exit_marker = Control.new()
	_exit_marker.name = "ExitMarker"

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_exit_marker.add_child(vbox)

	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.color = Color(0.4, 0.3, 0.3, 0.5)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var label = Label.new()
	label.text = "[Exit Node]"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5, 0.7))
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(label)

	_exit_marker.position = Vector2(-100, 0) - Vector2(40, 30)
	parent.add_child(_exit_marker)

func _input(event: InputEvent) -> void:
	# Handle canvas click for node creation
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_tool == Tool.CREATE_NODE:
			if _is_mouse_over_canvas():
				var world_pos = _get_mouse_world_position()
				_create_node_at(world_pos)
				get_viewport().set_input_as_handled()

# --- Path Conversion ---

func _area_id_to_dir_path(area_id: String) -> String:
	var path = area_id.replace("\\", "/")
	if path.ends_with("/"):
		path = path.trim_suffix("/")
	return LOCATIONS_BASE_PATH.path_join(path)

func _dir_path_to_area_id(dir_path: String) -> String:
	var relative = dir_path.trim_prefix(LOCATIONS_BASE_PATH).trim_prefix("/")
	return relative.replace("/", "\\") + "\\"

# --- File Tree ---

func _refresh_file_tree() -> void:
	file_tree.clear()
	var root = file_tree.create_item()
	root.set_text(0, "locations")
	root.set_meta("area_id", "")
	root.set_meta("path", LOCATIONS_BASE_PATH)

	_populate_directory(root, LOCATIONS_BASE_PATH, "")

func _populate_directory(parent_item: TreeItem, dir_path: String, prefix: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	var subdirs: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			subdirs.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	subdirs.sort()

	for subdir in subdirs:
		var item = file_tree.create_item(parent_item)
		item.set_text(0, subdir)

		var new_prefix = subdir if prefix == "" else prefix + "\\" + subdir
		var area_id = new_prefix + "\\"
		item.set_meta("area_id", area_id)
		item.set_meta("path", dir_path.path_join(subdir))

		_populate_directory(item, dir_path.path_join(subdir), new_prefix)

func _on_file_tree_item_selected() -> void:
	var selected_item = file_tree.get_selected()
	if selected_item:
		var area_id = selected_item.get_meta("area_id")
		if area_id != "":
			area_id_line_edit.text = area_id
			_load_area(area_id)

# --- Load/Save ---

func _on_load_pressed() -> void:
	var area_id = area_id_line_edit.text.strip_edges()
	if area_id == "":
		return
	# Ensure trailing backslash
	if not area_id.ends_with("\\"):
		area_id += "\\"
		area_id_line_edit.text = area_id
	_load_area(area_id)

func _load_area(area_id: String) -> void:
	current_area_id = area_id
	current_dir_path = _area_id_to_dir_path(area_id)

	# Clear state
	node_data.clear()
	link_data.clear()
	selected_node = ""
	selected_link_index = -1
	link_first_node = ""

	# Check if directory exists
	var dir = DirAccess.open(current_dir_path)
	if dir != null:
		# Load .json files (except __links.json)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.begins_with("__"):
				var node_name = file_name.trim_suffix(".json")
				var file_path = current_dir_path.path_join(file_name)
				var data = _load_json_file(file_path)
				if data:
					node_data[node_name] = {
						"display_name": data.get("display_name", node_name),
						"position": Vector2(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0)),
						"is_discovered": data.get("is_discovered", true),
						"is_instant_travel": data.get("is_instant_travel", false),
						"is_new": false,
						"is_modified": false,
						"is_deleted": false
					}
			file_name = dir.get_next()
		dir.list_dir_end()

		# Load __links.json
		var links_path = current_dir_path.path_join("__links.json")
		if FileAccess.file_exists(links_path):
			var links_json = _load_json_file(links_path)
			if links_json is Array:
				for link_arr in links_json:
					if link_arr is Array and link_arr.size() >= 3:
						link_data.append({
							"from": link_arr[0],
							"to": link_arr[1],
							"distance": link_arr[2],
							"is_new": false,
							"is_deleted": false
						})

	_refresh_canvas()
	_update_properties_panel()
	_set_tool(Tool.SELECT)

func _on_save_pressed() -> void:
	if current_area_id == "":
		return
	_save_area()

func _save_area() -> void:
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(current_dir_path):
		DirAccess.make_dir_recursive_absolute(current_dir_path)

	# Delete removed node files
	for node_name in node_data:
		var data = node_data[node_name]
		if data.is_deleted and not data.is_new:
			var file_path = current_dir_path.path_join(node_name + ".json")
			if FileAccess.file_exists(file_path):
				DirAccess.remove_absolute(file_path)

	# Save new/modified nodes
	for node_name in node_data:
		var data = node_data[node_name]
		if data.is_deleted:
			continue
		if data.is_new or data.is_modified:
			var json_data = {
				"display_name": data.display_name,
				"position": {"x": data.position.x, "y": data.position.y},
				"is_discovered": data.is_discovered
			}
			if data.is_instant_travel:
				json_data["is_instant_travel"] = true
			_save_json_file(current_dir_path.path_join(node_name + ".json"), json_data)

	# Save __links.json
	var links_to_save: Array = []
	for link in link_data:
		if not link.is_deleted:
			links_to_save.append([link.from, link.to, link.distance])

	var links_path = current_dir_path.path_join("__links.json")
	if links_to_save.size() > 0 or FileAccess.file_exists(links_path):
		_save_json_file(links_path, links_to_save)

	# Reset dirty flags
	for node_name in node_data:
		var data = node_data[node_name]
		if data.is_deleted:
			continue
		data.is_new = false
		data.is_modified = false

	# Remove deleted nodes from data
	var to_remove: Array[String] = []
	for node_name in node_data:
		if node_data[node_name].is_deleted:
			to_remove.append(node_name)
	for node_name in to_remove:
		node_data.erase(node_name)

	# Remove deleted links
	var new_link_data: Array = []
	for link in link_data:
		if not link.is_deleted:
			link.is_new = false
			new_link_data.append(link)
	link_data = new_link_data

	# Refresh
	_refresh_file_tree()
	_refresh_canvas()

func _load_json_file(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return null
	return json.data

func _save_json_file(path: String, data: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write to: " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# --- Canvas Rendering ---

func _refresh_canvas() -> void:
	if _nodes_container == null or _path_lines_container == null:
		return

	# Clear visual nodes
	for child in _nodes_container.get_children():
		child.queue_free()
	_visual_nodes.clear()

	# Clear link lines
	for child in _path_lines_container.get_children():
		child.queue_free()
	_link_lines.clear()

	# Create visual nodes
	for node_name in node_data:
		var data = node_data[node_name]
		if data.is_deleted:
			continue
		_create_visual_node(node_name, data)

	# Create link lines
	for i in range(link_data.size()):
		var link = link_data[i]
		if link.is_deleted:
			continue
		_create_link_line(i, link)

func _create_visual_node(node_name: String, data: Dictionary) -> void:
	var visual_node = EditorLocationNodeScene.instantiate()
	_nodes_container.add_child(visual_node)
	visual_node.setup(node_name, data.display_name, data.position)
	visual_node.selected.connect(_on_visual_node_selected)
	visual_node.moved.connect(_on_visual_node_moved)
	_visual_nodes[node_name] = visual_node

func _create_link_line(index: int, link: Dictionary) -> void:
	var from_data = node_data.get(link.from)
	var to_data = node_data.get(link.to)

	if from_data == null or to_data == null:
		return
	if from_data.is_deleted or to_data.is_deleted:
		return

	var is_selected = (index == selected_link_index)

	var line = Line2D.new()
	line.add_point(from_data.position)
	line.add_point(to_data.position)
	line.width = 3.0 if is_selected else 2.0
	line.default_color = Color(0.3, 0.6, 0.9, 1.0) if is_selected else Color(0.4, 0.4, 0.4, 0.8)
	line.set_meta("link_index", index)
	_path_lines_container.add_child(line)

	# Add clickable distance label
	var midpoint = (from_data.position + to_data.position) / 2

	var label_button = Button.new()
	label_button.text = str(link.distance)
	label_button.flat = true
	label_button.add_theme_font_size_override("font_size", 12)
	label_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	label_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	label_button.add_theme_color_override("font_pressed_color", Color(0.6, 0.8, 1.0, 1.0))
	label_button.set_meta("link_index", index)
	label_button.pressed.connect(_on_link_label_pressed.bind(index))

	var label_container = Control.new()
	label_container.position = midpoint + Vector2(-15, -12)
	label_container.add_child(label_button)
	line.add_child(label_container)

	_link_lines.append(line)

func _on_link_label_pressed(index: int) -> void:
	_select_link(index)

# --- Tool Handling ---

func _set_tool(tool: Tool) -> void:
	current_tool = tool
	link_first_node = ""

	# Update button states
	select_tool_btn.button_pressed = (tool == Tool.SELECT)
	create_node_btn.button_pressed = (tool == Tool.CREATE_NODE)
	create_link_btn.button_pressed = (tool == Tool.CREATE_LINK)

	# Clear link source highlight
	for node_name in _visual_nodes:
		_visual_nodes[node_name].set_link_source(false)

func _on_select_tool_pressed() -> void:
	_set_tool(Tool.SELECT)

func _on_create_node_tool_pressed() -> void:
	_set_tool(Tool.CREATE_NODE)

func _on_create_link_tool_pressed() -> void:
	_set_tool(Tool.CREATE_LINK)

func _is_mouse_over_canvas() -> bool:
	var mouse_pos = get_global_mouse_position()
	var canvas_rect = canvas_panel.get_global_rect()
	return canvas_rect.has_point(mouse_pos)

func _get_mouse_world_position() -> Vector2:
	# Get mouse position relative to the camera control
	var local_mouse = camera.get_local_mouse_position()
	# Convert to world coordinates using camera's transform
	# The camera stores camera_position (center) and camera_zoom
	var viewport_center = camera.size / 2.0
	var offset_from_center = local_mouse - viewport_center
	return camera.camera_position + offset_from_center / camera.camera_zoom

func _create_node_at(world_pos: Vector2) -> void:
	# Generate unique name
	var base_name = "New Location"
	var name = base_name
	var counter = 1
	while node_data.has(name):
		counter += 1
		name = base_name + " " + str(counter)

	node_data[name] = {
		"display_name": name,
		"position": world_pos,
		"is_discovered": true,
		"is_instant_travel": false,
		"is_new": true,
		"is_modified": false,
		"is_deleted": false
	}

	_create_visual_node(name, node_data[name])
	_select_node(name)
	_set_tool(Tool.SELECT)

# --- Selection ---

func _on_visual_node_selected(node_name: String) -> void:
	if current_tool == Tool.CREATE_LINK:
		_handle_link_creation_click(node_name)
	else:
		_select_node(node_name)

func _handle_link_creation_click(node_name: String) -> void:
	if link_first_node == "":
		# First node
		link_first_node = node_name
		if _visual_nodes.has(node_name):
			_visual_nodes[node_name].set_link_source(true)
	else:
		# Second node
		if node_name != link_first_node:
			# Check if link already exists
			var exists = false
			for link in link_data:
				if link.is_deleted:
					continue
				if (link.from == link_first_node and link.to == node_name) or \
				   (link.from == node_name and link.to == link_first_node):
					exists = true
					break

			if not exists:
				link_data.append({
					"from": link_first_node,
					"to": node_name,
					"distance": 1,
					"is_new": true,
					"is_deleted": false
				})
				_refresh_canvas()
				_select_link(link_data.size() - 1)

		# Reset
		_set_tool(Tool.SELECT)

func _select_node(node_name: String) -> void:
	# Deselect previous
	if selected_node != "" and _visual_nodes.has(selected_node):
		_visual_nodes[selected_node].set_selected(false)
	selected_link_index = -1

	selected_node = node_name
	if _visual_nodes.has(node_name):
		_visual_nodes[node_name].set_selected(true)

	_update_properties_panel()

func _select_link(index: int) -> void:
	# Deselect node
	if selected_node != "" and _visual_nodes.has(selected_node):
		_visual_nodes[selected_node].set_selected(false)
	selected_node = ""

	selected_link_index = index
	_refresh_canvas()  # Refresh to show selection highlight
	_update_properties_panel()

func _on_visual_node_moved(node_name: String, new_position: Vector2) -> void:
	if node_data.has(node_name):
		node_data[node_name].position = new_position
		if not node_data[node_name].is_new:
			node_data[node_name].is_modified = true

		# Update spinboxes if this is selected node
		if node_name == selected_node:
			pos_x_spinbox.value = new_position.x
			pos_y_spinbox.value = new_position.y

		# Refresh link lines
		_refresh_canvas()

		# Re-select after refresh
		if _visual_nodes.has(node_name):
			_visual_nodes[node_name].set_selected(true)

# --- Properties Panel ---

func _update_properties_panel() -> void:
	_updating_properties = true

	if selected_node != "" and node_data.has(selected_node):
		var data = node_data[selected_node]
		node_props.show()
		link_props.hide()

		name_line_edit.text = data.display_name
		pos_x_spinbox.value = data.position.x
		pos_y_spinbox.value = data.position.y
		discovered_checkbox.button_pressed = data.is_discovered

		delete_button.show()
	elif selected_link_index >= 0 and selected_link_index < link_data.size():
		var link = link_data[selected_link_index]
		node_props.hide()
		link_props.show()

		distance_spinbox.value = link.distance

		delete_button.show()
	else:
		node_props.hide()
		link_props.hide()
		delete_button.hide()

	_updating_properties = false

func _on_name_changed(new_name: String) -> void:
	if _updating_properties:
		return
	if selected_node == "" or not node_data.has(selected_node):
		return

	node_data[selected_node].display_name = new_name
	if not node_data[selected_node].is_new:
		node_data[selected_node].is_modified = true

	if _visual_nodes.has(selected_node):
		_visual_nodes[selected_node].set_display_name(new_name)

func _on_position_changed(_value: float) -> void:
	if _updating_properties:
		return
	if selected_node == "" or not node_data.has(selected_node):
		return

	var new_pos = Vector2(pos_x_spinbox.value, pos_y_spinbox.value)
	node_data[selected_node].position = new_pos
	if not node_data[selected_node].is_new:
		node_data[selected_node].is_modified = true

	# Refresh to update links
	_refresh_canvas()

	# Re-select to update visual
	if _visual_nodes.has(selected_node):
		_visual_nodes[selected_node].set_selected(true)

func _on_discovered_changed(pressed: bool) -> void:
	if _updating_properties:
		return
	if selected_node == "" or not node_data.has(selected_node):
		return

	node_data[selected_node].is_discovered = pressed
	if not node_data[selected_node].is_new:
		node_data[selected_node].is_modified = true

func _on_distance_changed(value: float) -> void:
	if _updating_properties:
		return
	if selected_link_index < 0 or selected_link_index >= link_data.size():
		return

	link_data[selected_link_index].distance = int(value)
	if not link_data[selected_link_index].is_new:
		link_data[selected_link_index].is_modified = true

	_refresh_canvas()

func _on_delete_pressed() -> void:
	if selected_node != "" and node_data.has(selected_node):
		# Mark node as deleted
		node_data[selected_node].is_deleted = true

		# Also delete links involving this node
		for link in link_data:
			if link.from == selected_node or link.to == selected_node:
				link.is_deleted = true

		selected_node = ""
		_refresh_canvas()
		_update_properties_panel()

	elif selected_link_index >= 0 and selected_link_index < link_data.size():
		link_data[selected_link_index].is_deleted = true
		selected_link_index = -1
		_refresh_canvas()
		_update_properties_panel()
