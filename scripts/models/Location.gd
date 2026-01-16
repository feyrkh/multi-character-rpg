# Location.gd
# A node in the location graph
class_name Location
extends RegisteredObject

const PATH_SEPARATOR = "\\"

# ID is path-like ID: "World Map\Small Village\"
var display_name: String = ""
var icon_path: String = ""
var background_path: String = ""
var is_discovered: bool = false
var position: Vector2 = Vector2.ZERO  # Position on map for rendering
var is_instant_travel: bool = true  # If false, must walk between nodes
# Potential enemy encounters. Can be:
# - Array of Strings: ["enemy1.json", "enemy2.json"] (backward compat - each is separate encounter)
# - Array of Arrays: [["enemy1.json", "enemy2.json"], ["enemy3.json"]] (multi-enemy encounters)
var potential_enemies: Array = []

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	display_name = p_name
	# Default: top-level locations are not instant travel
	if is_top_level():
		is_instant_travel = false

func discover() -> void:
	is_discovered = true

# --- Path Helper Methods ---

func get_depth() -> int:
	# Count the number of path separators
	# "World Map\" = 1, "World Map\Village\" = 2
	var count = 0
	for c in id:
		if c == PATH_SEPARATOR[0]:
			count += 1
	return count

func is_inside() -> bool:
	# Trailing slash means we're inside this location
	return id.ends_with(PATH_SEPARATOR)

func get_parent_path() -> String:
	# Remove the last segment to get parent
	# "World Map\Village\" -> "World Map\Village" -> "World Map\"
	# "World Map\Village" -> "World Map\"
	if id.is_empty():
		return ""

	var working = id
	# Remove trailing slash if present
	if working.ends_with(PATH_SEPARATOR):
		working = working.left(working.length() - 1)

	# Find the last separator
	var last_sep = working.rfind(PATH_SEPARATOR)
	if last_sep < 0:
		return ""  # No parent (top level)

	return working.left(last_sep + 1)  # Include the trailing separator

func get_current_area_name() -> String:
	# Get the last segment name (without trailing slash)
	# "World Map\Village\" -> "Village"
	# "World Map\Village" -> "Village"
	if id.is_empty():
		return ""

	var working = id
	# Remove trailing slash if present
	if working.ends_with(PATH_SEPARATOR):
		working = working.left(working.length() - 1)

	# Find the last separator
	var last_sep = working.rfind(PATH_SEPARATOR)
	if last_sep < 0:
		return working  # No separator, return whole string

	return working.substr(last_sep + 1)

func is_top_level() -> bool:
	# Top level = depth 0 or 1 (e.g., "World Map\" or just "World Map")
	return get_depth() <= 1

func get_containing_area_id() -> String:
	# Get the area ID that contains this location's nodes
	# "World Map\Village" is a node viewed from "World Map\"
	# "World Map\Village\" is inside Village, viewing nodes there
	if is_inside():
		return id
	else:
		return get_parent_path()

# --- Serialization ---

func to_dict() -> Dictionary:
	var result = {
		"id": id,
		"display_name": display_name,
		"icon_path": icon_path,
		"background_path": background_path,
		"is_discovered": is_discovered,
		"position": {"x": position.x, "y": position.y},
		"is_instant_travel": is_instant_travel
	}
	if potential_enemies.size() > 0:
		result["potential_enemies"] = Array(potential_enemies)
	return result

static func from_dict(dict: Dictionary) -> Location:
	var loc = Location.new(
		dict.get("id", ""),
		dict.get("display_name", "")
	)
	loc.icon_path = dict.get("icon_path", "")
	loc.background_path = dict.get("background_path", "")
	loc.is_discovered = dict.get("is_discovered", false)
	var pos_data = dict.get("position", {})
	loc.position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
	loc.is_instant_travel = dict.get("is_instant_travel", true)
	var enemies_data = dict.get("potential_enemies", [])
	for enemy_path in enemies_data:
		loc.potential_enemies.append(enemy_path)
	return loc

func get_save_data() -> Dictionary:
	return {
		"id": id,
		"is_discovered": is_discovered
	}

static func load_save_data(save_data:Dictionary) -> Location:
	var loc = ResourceMgr.load_clone(Location, save_data["id"])
	loc.is_discovered = save_data.get("is_discovered", false)
	return loc
