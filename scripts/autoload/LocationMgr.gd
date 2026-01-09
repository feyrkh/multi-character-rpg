# LocationMgr.gd
# Manages the location graph, movement, and discovery
extends Node

signal moved_to_location(character: PlayableCharacter, old_location: Location, new_location: Location)
signal party_moved(party: Party, old_location: Location, new_location: Location)
signal location_discovered(location: Location)
signal move_requested(party: Party, path_points: Array, total_distance: int, target_location_id: String)
signal move_confirmed(party: Party, target_location_id: String)
signal move_cancelled()

# Location storage: location_id -> Location
var locations: Dictionary = {}
# Links storage: Array of LocationLink
var links: Array[LocationLink] = []

const LOCATIONS_BASE_PATH = "res://data/locations"

# Track which directories have had their links loaded
var _loaded_link_directories: Dictionary = {}

# Pending move state
var _pending_party: Party = null
var _pending_target_id: String = ""
var _pending_path: Array[String] = []
var _pending_distance: int = 0

func _ready() -> void:
	pass

# --- Path Conversion ---

func _location_id_to_file_path(location_id: String) -> String:
	# Convert location ID to JSON file path
	# "World Map\Small Village" -> "res://data/locations/World Map/Small Village.json"
	if location_id.ends_with("\\"):
		return ""  # Area IDs don't have JSON files
	var path_part = location_id.replace("\\", "/")
	return LOCATIONS_BASE_PATH.path_join(path_part) + ".json"

func _location_id_to_directory_path(location_id: String) -> String:
	# Get the directory containing this location's JSON file (for __links.json)
	# "World Map\Small Village" -> "res://data/locations/World Map"
	var path_part = location_id.replace("\\", "/")
	if path_part.ends_with("/"):
		path_part = path_part.trim_suffix("/")
	var last_slash = path_part.rfind("/")
	if last_slash >= 0:
		return LOCATIONS_BASE_PATH.path_join(path_part.left(last_slash))
	return LOCATIONS_BASE_PATH

func _get_containing_directory(location_id: String) -> String:
	# Get the directory path for an area ID (for checking if area exists)
	# "World Map\Small Village\" -> "res://data/locations/World Map/Small Village"
	var path_part = location_id.replace("\\", "/")
	if path_part.ends_with("/"):
		path_part = path_part.trim_suffix("/")
	return LOCATIONS_BASE_PATH.path_join(path_part)

func _directory_to_location_prefix(dir_path: String) -> String:
	# Convert directory path back to location prefix
	# "res://data/locations/World Map" -> "World Map"
	var relative = dir_path.trim_prefix(LOCATIONS_BASE_PATH).trim_prefix("/")
	return relative.replace("/", "\\")

# --- Location Registration ---

func register_location(location: Location) -> void:
	locations[location.id] = location

func register_link(link: LocationLink) -> void:
	links.append(link)

# --- Location Loading ---

func _try_load_location(location_id: String) -> Location:
	# Handle area IDs (trailing backslash) differently
	if location_id.ends_with("\\"):
		return _try_load_area_location(location_id)
	else:
		return _try_load_location_from_file(location_id)

func _try_load_area_location(area_id: String) -> Location:
	# Area IDs represent "being inside" a location
	# Check if either: 1) the directory exists, or 2) the node .json file exists
	var dir_path = _get_containing_directory(area_id)
	var dir = DirAccess.open(dir_path)
	var has_directory = (dir != null)

	# If no directory, check if the node itself exists (allows entering nodes without subdirectories)
	var node_id = area_id.trim_suffix("\\")
	var node_file_path = _location_id_to_file_path(node_id)
	var has_node_file = FileAccess.file_exists(node_file_path)

	if not has_directory and not has_node_file:
		return null

	var area_name = area_id.trim_suffix("\\").get_file().replace("\\", "")
	if area_name == "":
		# Handle top-level like "World Map\"
		area_name = area_id.replace("\\", "").strip_edges()

	var loc = Location.new(area_id, area_name)
	loc.is_discovered = true
	loc.position = Vector2(0, 0)

	# Check for __area.json with additional properties (only if directory exists)
	if has_directory:
		var area_json_path = dir_path.path_join("__area.json")
		if FileAccess.file_exists(area_json_path):
			var file = FileAccess.open(area_json_path, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data = json.data
					if data.has("display_name"):
						loc.display_name = data.display_name
					if data.has("is_discovered"):
						loc.is_discovered = data.is_discovered
					if data.has("potential_enemies"):
						for enemy_path in data.potential_enemies:
							loc.potential_enemies.append(enemy_path)
				file.close()

	# Register location
	register_location(loc)

	# Only load links if directory exists
	if has_directory:
		_ensure_links_loaded_for_directory(dir_path)

	return loc

func _try_load_location_from_file(location_id: String) -> Location:
	var file_path = _location_id_to_file_path(location_id)
	if file_path == "" or not FileAccess.file_exists(file_path):
		return null

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open location file: " + file_path)
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("Failed to parse JSON in " + file_path + ": " + json.get_error_message())
		return null

	var data = json.data
	var display_name = data.get("display_name", location_id.get_file())
	var loc = Location.new(location_id, display_name)

	var pos_data = data.get("position", {})
	loc.position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
	loc.is_discovered = data.get("is_discovered", false)

	if data.has("is_instant_travel"):
		loc.is_instant_travel = data.get("is_instant_travel")
	if data.has("icon_path"):
		loc.icon_path = data.get("icon_path")
	if data.has("background_path"):
		loc.background_path = data.get("background_path")

	# Register and ensure links are loaded
	register_location(loc)
	var dir_path = _location_id_to_directory_path(location_id)
	_ensure_links_loaded_for_directory(dir_path)

	return loc

func _ensure_links_loaded_for_directory(dir_path: String) -> void:
	# Skip if already loaded
	if _loaded_link_directories.has(dir_path):
		return

	_loaded_link_directories[dir_path] = true

	var links_path = dir_path.path_join("__links.json")
	if not FileAccess.file_exists(links_path):
		return

	var file = FileAccess.open(links_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open links file: " + links_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("Failed to parse JSON in " + links_path + ": " + json.get_error_message())
		return

	var links_data = json.data
	if not links_data is Array:
		push_warning("Links file should contain an array: " + links_path)
		return

	# Determine location prefix from directory path
	var location_prefix = _directory_to_location_prefix(dir_path)

	for link_entry in links_data:
		if link_entry is Array and link_entry.size() >= 3:
			var from_name = link_entry[0]
			var to_name = link_entry[1]
			var distance = link_entry[2]

			var from_id = location_prefix + "\\" + from_name if location_prefix != "" else from_name
			var to_id = location_prefix + "\\" + to_name if location_prefix != "" else to_name

			# Avoid duplicate links
			if get_link_between(from_id, to_id) == null:
				register_link(LocationLink.new(from_id, to_id, distance))

func get_location(location_id: String) -> Location:
	# 1. Check cache first
	if locations.has(location_id):
		return locations[location_id]

	# 2. Try to load from disk
	var loaded = _try_load_location(location_id)
	if loaded:
		return loaded

	# 3. Not found
	return null

func get_all_locations() -> Array[Location]:
	var result: Array[Location] = []
	for loc in locations.values():
		result.append(loc)
	return result

func get_discovered_locations() -> Array[Location]:
	var result: Array[Location] = []
	for loc in locations.values():
		if loc.is_discovered:
			result.append(loc)
	return result

# --- Path Utilities ---

func parse_path(location_id: String) -> Dictionary:
	var segments: Array[String] = []
	var current = ""
	for c in location_id:
		if c == "\\":
			if current != "":
				segments.append(current)
				current = ""
		else:
			current += c
	if current != "":
		segments.append(current)

	return {
		"segments": segments,
		"is_inside": location_id.ends_with("\\"),
		"depth": location_id.count("\\")
	}

func get_parent_location_id(location_id: String) -> String:
	var loc = Location.new(location_id, "")
	return loc.get_parent_path()

func get_locations_in_area(area_id: String) -> Array[Location]:
	# Get all locations that are direct children of this area
	# area_id should end with \ (e.g., "World Map\")
	# First ensure all locations in this area are loaded by scanning the directory
	_ensure_area_locations_loaded(area_id)

	var result: Array[Location] = []
	for loc in locations.values():
		var containing = loc.get_containing_area_id()
		if containing == area_id and loc.id != area_id:
			result.append(loc)
	return result

func _ensure_area_locations_loaded(area_id: String) -> void:
	# Scan directory and load all locations in this area
	var dir_path = _get_containing_directory(area_id)
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	# Determine location prefix for this directory
	var location_prefix = _directory_to_location_prefix(dir_path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.begins_with("__"):
			var location_name = file_name.trim_suffix(".json")
			var location_id = location_prefix + "\\" + location_name if location_prefix != "" else location_name
			# This will load from disk if not already cached
			get_location(location_id)
		file_name = dir.get_next()
	dir.list_dir_end()

func get_exit_link_name(location_id: String) -> String:
	# Determine whether this location should have "Leave" or "Travel"
	var loc = Location.new(location_id, "")
	var depth = loc.get_depth()
	if depth <= 2:
		return "Travel"  # Second level uses "Travel" to go to world map
	else:
		return "Leave"   # Deeper levels use "Leave"

# --- Graph Navigation ---

func get_adjacent_locations(location_id: String) -> Array[Location]:
	var result: Array[Location] = []
	for link in links:
		if link.connects(location_id):
			var other_id = link.get_other_end(location_id)
			var other_loc = get_location(other_id)
			if other_loc:
				result.append(other_loc)
	return result

func get_discovered_adjacent_locations(location_id: String) -> Array[Location]:
	var adjacent = get_adjacent_locations(location_id)
	var result: Array[Location] = []
	for loc in adjacent:
		if loc.is_discovered:
			result.append(loc)
	return result

func get_link_between(from_id: String, to_id: String) -> LocationLink:
	for link in links:
		if (link.from_location_id == from_id and link.to_location_id == to_id) or \
		   (link.from_location_id == to_id and link.to_location_id == from_id):
			return link
	return null

func get_travel_distance(from_id: String, to_id: String) -> int:
	var link = get_link_between(from_id, to_id)
	if link:
		return link.travel_distance
	return -1  # Not connected

func are_connected(from_id: String, to_id: String) -> bool:
	return get_link_between(from_id, to_id) != null

# --- Pathfinding ---

func find_path(from_id: String, to_id: String) -> Array[String]:
	# Dijkstra's algorithm to find lowest-weight path
	if from_id == to_id:
		return [from_id]

	# Distance from start to each node
	var distances: Dictionary = {from_id: 0}
	# Previous node in optimal path
	var previous: Dictionary = {}
	# Nodes still to process
	var unvisited: Dictionary = {from_id: true}

	while unvisited.size() > 0:
		# Find unvisited node with smallest distance
		var current: String = ""
		var current_dist: int = -1
		for node_id in unvisited:
			if distances.has(node_id):
				var dist = distances[node_id]
				if current_dist < 0 or dist < current_dist:
					current = node_id
					current_dist = dist

		if current == "":
			break  # No reachable nodes left

		if current == to_id:
			# Reconstruct path
			var path: Array[String] = []
			var node = to_id
			while node != "":
				path.insert(0, node)
				node = previous.get(node, "")
			return path

		unvisited.erase(current)

		# Check all neighbors
		for neighbor in get_adjacent_locations(current):
			var neighbor_id = neighbor.id
			var edge_weight = get_travel_distance(current, neighbor_id)
			if edge_weight < 0:
				continue  # No valid link

			var new_dist = current_dist + edge_weight

			if not distances.has(neighbor_id) or new_dist < distances[neighbor_id]:
				distances[neighbor_id] = new_dist
				previous[neighbor_id] = current
				unvisited[neighbor_id] = true

	return []  # No path found

func calculate_path_distance(path: Array[String]) -> int:
	if path.size() < 2:
		return 0

	var total = 0
	for i in range(path.size() - 1):
		var dist = get_travel_distance(path[i], path[i + 1])
		if dist < 0:
			return -1  # Invalid path
		total += dist
	return total

func get_path_points(path: Array[String]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for loc_id in path:
		var loc = get_location(loc_id)
		if loc:
			points.append(loc.position)
	return points

# --- Exploration Stats ---

func get_total_links_from(location_id: String) -> int:
	var count = 0
	for link in links:
		if link.connects(location_id):
			count += 1
	return count

func get_discovered_links_from(location_id: String) -> int:
	var count = 0
	for link in links:
		if link.connects(location_id):
			var other_id = link.get_other_end(location_id)
			var other_loc = get_location(other_id)
			if other_loc and other_loc.is_discovered:
				count += 1
	return count

func get_exploration_percent(location_id: String) -> float:
	var total = get_total_links_from(location_id)
	if total == 0:
		return 100.0
	var discovered = get_discovered_links_from(location_id)
	return (float(discovered) / float(total)) * 100.0

# --- Movement ---

func can_move_party(party: Party, to_location_id: String) -> bool:
	var from_id = party.current_location_id
	if from_id == to_location_id:
		return false

	var to_location = get_location(to_location_id)
	if not to_location or not to_location.is_discovered:
		return false
		
	# If the current location and the new location are both in the same area, and it's an instant-move area, you can move
	var from_location = get_location(party.current_location_id)
	if from_location.is_instant_travel and from_location.get_parent_path() == to_location.get_parent_path():
		return true
		
	# Find path and check if connected
	var path = find_path(from_id, to_location_id)
	if path.is_empty():
		return false

	var distance = calculate_path_distance(path)
	if distance < 0:
		return false

	return TimeMgr.can_spend_time(party, distance)

func request_move(party: Party, to_location_id: String) -> void:
	if not can_move_party(party, to_location_id):
		return

	var from_id = party.current_location_id
	var path = find_path(from_id, to_location_id)
	var distance = calculate_path_distance(path)
	var path_points = get_path_points(path)

	# Check if instant travel or zero distance
	var from_loc = get_location(from_id)
	if distance == 0 or (from_loc and from_loc.is_instant_travel):
		# Move immediately
		_execute_move(party, to_location_id, path, distance)
	else:
		# Store pending move and request confirmation
		_pending_party = party
		_pending_target_id = to_location_id
		_pending_path.clear()
		for p in path:
			_pending_path.append(p)
		_pending_distance = distance
		move_requested.emit(party, path_points, distance, to_location_id)

func confirm_move() -> void:
	if _pending_party == null:
		return

	_execute_move(_pending_party, _pending_target_id, _pending_path, _pending_distance)
	move_confirmed.emit(_pending_party, _pending_target_id)
	_clear_pending()

func cancel_move() -> void:
	_clear_pending()
	move_cancelled.emit()

func _clear_pending() -> void:
	_pending_party = null
	_pending_target_id = ""
	_pending_path.clear()
	_pending_distance = 0

func _execute_move(party: Party, to_location_id: String, path: Array[String], distance: int) -> void:
	var from_id = party.current_location_id

	if distance > 0:
		if not TimeMgr.spend_time(party, distance):
			return

	var old_location = get_location(from_id)
	var new_location = get_location(to_location_id)

	# Update party location
	party.current_location_id = to_location_id

	# Update all party members' locations
	var members = GameManager.get_party_members(party)
	for member in members:
		member.current_location_id = to_location_id
		moved_to_location.emit(member, old_location, new_location)

	party_moved.emit(party, old_location, new_location)

# --- Discovery ---

func discover_location(location_id: String) -> bool:
	var location = get_location(location_id)
	if location and not location.is_discovered:
		location.discover()
		location_discovered.emit(location)
		return true
	return false

func is_discovered(location_id: String) -> bool:
	var location = get_location(location_id)
	return location and location.is_discovered

# --- Character Queries ---

func get_characters_at_location(location_id: String) -> Array[PlayableCharacter]:
	var result: Array[PlayableCharacter] = []
	var characters = GameManager.get_all_characters()
	for character in characters:
		if character.current_location_id == location_id:
			result.append(character)
	return result

func get_parties_at_location(location_id: String) -> Array[Party]:
	var result: Array[Party] = []
	var parties = GameManager.get_all_parties()
	for party in parties:
		if party.current_location_id == location_id:
			result.append(party)
	return result

# --- Save/Load State ---

func get_state() -> Dictionary:
	var locations_data = []
	for loc in locations.values():
		locations_data.append(loc.to_dict())

	var links_data = []
	for link in links:
		links_data.append(link.to_dict())

	return {
		"locations": locations_data,
		"links": links_data
	}

func load_state(state: Dictionary) -> void:
	locations.clear()
	links.clear()

	var locations_data = state.get("locations", [])
	for loc_dict in locations_data:
		var loc = Location.from_dict(loc_dict)
		register_location(loc)

	var links_data = state.get("links", [])
	for link_dict in links_data:
		var link = LocationLink.from_dict(link_dict)
		register_link(link)

func reset() -> void:
	locations.clear()
	links.clear()
	_loaded_link_directories.clear()
	_clear_pending()
