# LocationView.gd
# Displays the location map with nodes and path lines
extends Control

signal location_clicked(location_id: String)
signal exit_clicked(parent_area_id: String)
signal enter_requested(location_id: String)

const LocationNodeScene = preload("res://scenes/location/location_node.tscn")

@onready var background: TextureRect = $Background
@onready var camera: DraggableCamera2D = $Camera

var current_area_id: String = ""
var current_party_location_id: String = ""
var _is_instant_travel: bool = false
var _path_lines_container: Control
var _nodes_container: Control
var _location_nodes: Dictionary = {}  # location_id -> LocationNode
var _path_preview_line: Line2D = null

func _ready() -> void:
	# Create containers for content
	_path_lines_container = Control.new()
	_path_lines_container.name = "PathLines"
	camera.add_content(_path_lines_container)

	_nodes_container = Control.new()
	_nodes_container.name = "Nodes"
	camera.add_content(_nodes_container)

	# Create path preview line (on top of everything)
	_path_preview_line = Line2D.new()
	_path_preview_line.name = "PathPreview"
	_path_preview_line.width = 4.0
	_path_preview_line.default_color = Color(0.9, 0.2, 0.2, 0.8)  # Bold red
	_path_preview_line.visible = false
	camera.add_content(_path_preview_line)

func load_area(area_id: String, party_location_id: String = "") -> void:
	current_area_id = area_id
	current_party_location_id = party_location_id
	_clear_view()

	# Check if this is an instant-travel area
	var area_location = LocationMgr.get_location(area_id)
	_is_instant_travel = area_location != null and area_location.is_instant_travel

	_spawn_location_nodes()
	_spawn_exit_node()

	# Only draw path lines for non-instant-travel areas
	if not _is_instant_travel:
		_draw_path_lines()

	_update_character_positions()
	_update_current_location_marker()

func _clear_view() -> void:
	# Clear existing nodes
	for child in _nodes_container.get_children():
		child.queue_free()
	_location_nodes.clear()

	# Clear existing lines
	for child in _path_lines_container.get_children():
		child.queue_free()

	# Clear path preview
	clear_path_preview()

func _spawn_location_nodes() -> void:
	var locations = LocationMgr.get_locations_in_area(current_area_id)

	for location in locations:
		if not location.is_discovered:
			continue

		var node_instance = LocationNodeScene.instantiate()
		_nodes_container.add_child(node_instance)

		var exploration = LocationMgr.get_exploration_percent(location.id)
		node_instance.setup(location, exploration)
		node_instance.position = location.position - node_instance.size / 2
		node_instance.clicked.connect(_on_location_node_clicked)
		node_instance.enter_requested.connect(_on_enter_requested)

		_location_nodes[location.id] = node_instance

func _spawn_exit_node() -> void:
	# Don't spawn exit for top-level areas (World Map\)
	var area_location = LocationMgr.get_location(current_area_id)
	if area_location == null or area_location.is_top_level():
		return

	# Determine exit name based on depth
	var exit_name = LocationMgr.get_exit_link_name(current_area_id)

	# Create a virtual exit location
	var exit_location = Location.new("__exit__", exit_name)
	exit_location.is_discovered = true
	exit_location.position = Vector2(-100, 0)  # Left side of the view

	var node_instance = LocationNodeScene.instantiate()
	_nodes_container.add_child(node_instance)
	node_instance.setup(exit_location, 100.0)
	node_instance.position = exit_location.position - node_instance.size / 2
	node_instance.clicked.connect(_on_exit_node_clicked)

	_location_nodes["__exit__"] = node_instance

func _on_exit_node_clicked(_location_id: String) -> void:
	var area_location = LocationMgr.get_location(current_area_id)
	if area_location:
		var parent_id = area_location.get_parent_path()
		if parent_id != "":
			exit_clicked.emit(parent_id)

func _on_enter_requested(location_id: String) -> void:
	enter_requested.emit(location_id)

func _draw_path_lines() -> void:
	var drawn_links: Dictionary = {}

	for link in LocationMgr.links:
		# Skip if already drawn (bidirectional)
		var link_key = _get_link_key(link.from_location_id, link.to_location_id)
		if drawn_links.has(link_key):
			continue

		# Check if both endpoints are in this area and discovered
		var from_loc = LocationMgr.get_location(link.from_location_id)
		var to_loc = LocationMgr.get_location(link.to_location_id)

		if from_loc == null or to_loc == null:
			continue
		if not from_loc.is_discovered or not to_loc.is_discovered:
			continue
		if from_loc.get_containing_area_id() != current_area_id:
			continue
		if to_loc.get_containing_area_id() != current_area_id:
			continue

		# Draw line
		var line = Line2D.new()
		line.add_point(from_loc.position)
		line.add_point(to_loc.position)
		line.width = 2.0
		line.default_color = Color(0.4, 0.4, 0.4, 0.8)
		_path_lines_container.add_child(line)

		drawn_links[link_key] = true

func _get_link_key(from_id: String, to_id: String) -> String:
	# Create consistent key regardless of direction
	if from_id < to_id:
		return from_id + "|" + to_id
	return to_id + "|" + from_id

func _update_character_positions() -> void:
	for location_id in _location_nodes:
		if location_id == "__exit__":
			continue
		var node = _location_nodes[location_id]
		var characters = LocationMgr.get_characters_at_location(location_id)
		node.update_characters(characters)

func _update_current_location_marker() -> void:
	for location_id in _location_nodes:
		if location_id == "__exit__":
			continue
		var node = _location_nodes[location_id]
		var is_current = (location_id == current_party_location_id)

		# Check if this location has an interior by looking for any child locations
		var has_interior = false
		if is_current and not _is_instant_travel:
			var prefix = location_id + "\\"
			has_interior = _has_locations_with_prefix(prefix)

		node.set_current(is_current, has_interior)

func _has_locations_with_prefix(prefix: String) -> bool:
	# Check if any registered location starts with this prefix
	for loc in LocationMgr.locations.values():
		if loc.id.begins_with(prefix):
			return true

	# Check if the directory exists (allows entering locations with subdirectories)
	var dir_path = _location_id_to_directory(prefix)
	var dir = DirAccess.open(dir_path)
	if dir != null:
		return true

	# Check if the node's .json file exists (allows entering any location)
	var node_id = prefix.trim_suffix("\\")
	var node_file_path = _location_id_to_file_path(node_id)
	if FileAccess.file_exists(node_file_path):
		return true

	return false

func _location_id_to_directory(location_id: String) -> String:
	# Convert location ID to directory path
	# "World Map\Slime Dungeon\" -> "res://data/locations/World Map/Slime Dungeon"
	var path = location_id.replace("\\", "/")
	if path.ends_with("/"):
		path = path.trim_suffix("/")
	return "res://data/locations".path_join(path)

func _location_id_to_file_path(location_id: String) -> String:
	# Convert location ID to .json file path
	# "World Map\Small Village\Tavern" -> "res://data/locations/World Map/Small Village/Tavern.json"
	var path = location_id.replace("\\", "/")
	return "res://data/locations".path_join(path) + ".json"

func show_path_preview(path: Array[String]) -> void:
	_path_preview_line.clear_points()

	for location_id in path:
		var location = LocationMgr.get_location(location_id)
		if location:
			_path_preview_line.add_point(location.position)

	_path_preview_line.visible = path.size() > 1

func clear_path_preview() -> void:
	_path_preview_line.clear_points()
	_path_preview_line.visible = false

func highlight_path(path: Array[String]) -> void:
	# Reset all highlights
	for location_id in _location_nodes:
		_location_nodes[location_id].set_highlighted(false)

	# Highlight path nodes
	for location_id in path:
		if _location_nodes.has(location_id):
			_location_nodes[location_id].set_highlighted(true)

func clear_highlight() -> void:
	for location_id in _location_nodes:
		_location_nodes[location_id].set_highlighted(false)

func _on_location_node_clicked(location_id: String) -> void:
	location_clicked.emit(location_id)

func center_on_location(location_id: String) -> void:
	var location = LocationMgr.get_location(location_id)
	if location:
		camera.set_camera_position(location.position)

func is_instant_travel_area() -> bool:
	return _is_instant_travel

func set_party_location(location_id: String) -> void:
	current_party_location_id = location_id
	_update_current_location_marker()
