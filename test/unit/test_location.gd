extends GutTest

func test_init_default():
	var loc = Location.new()
	assert_eq(loc.id, "")
	assert_eq(loc.display_name, "")
	assert_eq(loc.is_discovered, false)
	assert_eq(loc.position, Vector2.ZERO)

func test_init_with_values():
	var loc = Location.new("world\\continent\\city", "The Great City")
	assert_eq(loc.id, "world\\continent\\city")
	assert_eq(loc.display_name, "The Great City")

func test_discover():
	var loc = Location.new("test_loc", "Test")
	assert_false(loc.is_discovered)
	loc.discover()
	assert_true(loc.is_discovered)

func test_to_dict():
	var loc = Location.new("forest\\clearing", "Forest Clearing")
	loc.icon_path = "res://icons/forest.png"
	loc.background_path = "res://backgrounds/forest.png"
	loc.is_discovered = true
	loc.position = Vector2(100, 200)

	var dict = loc.to_dict()
	assert_eq(dict["id"], "forest\\clearing")
	assert_eq(dict["display_name"], "Forest Clearing")
	assert_eq(dict["icon_path"], "res://icons/forest.png")
	assert_eq(dict["background_path"], "res://backgrounds/forest.png")
	assert_eq(dict["is_discovered"], true)
	assert_eq(dict["position"]["x"], 100.0)
	assert_eq(dict["position"]["y"], 200.0)

func test_from_dict():
	var dict = {
		"id": "mountain\\peak",
		"display_name": "Mountain Peak",
		"icon_path": "res://icons/mountain.png",
		"background_path": "res://backgrounds/mountain.png",
		"is_discovered": true,
		"position": {"x": 50, "y": 75}
	}
	var loc = Location.from_dict(dict)
	assert_eq(loc.id, "mountain\\peak")
	assert_eq(loc.display_name, "Mountain Peak")
	assert_eq(loc.icon_path, "res://icons/mountain.png")
	assert_eq(loc.is_discovered, true)
	assert_eq(loc.position, Vector2(50, 75))

func test_serialization_roundtrip():
	var original = Location.new("cave\\entrance", "Cave Entrance")
	original.icon_path = "res://icons/cave.png"
	original.is_discovered = true
	original.position = Vector2(300, 400)

	var dict = original.to_dict()
	var restored = Location.from_dict(dict)

	assert_eq(restored.id, original.id)
	assert_eq(restored.display_name, original.display_name)
	assert_eq(restored.icon_path, original.icon_path)
	assert_eq(restored.is_discovered, original.is_discovered)
	assert_eq(restored.position, original.position)

# --- Path Helper Tests ---

func test_is_inside_with_trailing_slash():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_true(loc.is_inside())

func test_is_inside_without_trailing_slash():
	var loc = Location.new("World Map\\Small Village", "Small Village")
	assert_false(loc.is_inside())

func test_get_depth_top_level():
	var loc = Location.new("World Map\\", "World Map")
	assert_eq(loc.get_depth(), 1)

func test_get_depth_second_level():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_eq(loc.get_depth(), 2)

func test_get_depth_third_level():
	var loc = Location.new("World Map\\Small Village\\Tavern\\", "Tavern")
	assert_eq(loc.get_depth(), 3)

func test_get_depth_node_without_trailing():
	var loc = Location.new("World Map\\Small Village", "Small Village")
	assert_eq(loc.get_depth(), 1)

func test_get_parent_path_from_inside():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_eq(loc.get_parent_path(), "World Map\\")

func test_get_parent_path_from_node():
	var loc = Location.new("World Map\\Small Village", "Small Village")
	assert_eq(loc.get_parent_path(), "World Map\\")

func test_get_parent_path_deep():
	var loc = Location.new("World Map\\Small Village\\Tavern\\", "Tavern")
	assert_eq(loc.get_parent_path(), "World Map\\Small Village\\")

func test_get_parent_path_top_level():
	var loc = Location.new("World Map\\", "World Map")
	assert_eq(loc.get_parent_path(), "")

func test_get_current_area_name():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_eq(loc.get_current_area_name(), "Small Village")

func test_get_current_area_name_node():
	var loc = Location.new("World Map\\Small Village", "Small Village")
	assert_eq(loc.get_current_area_name(), "Small Village")

func test_get_current_area_name_deep():
	var loc = Location.new("World Map\\Small Village\\Tavern\\", "Tavern")
	assert_eq(loc.get_current_area_name(), "Tavern")

func test_is_top_level_true():
	var loc = Location.new("World Map\\", "World Map")
	assert_true(loc.is_top_level())

func test_is_top_level_false():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_false(loc.is_top_level())

func test_instant_travel_default_top_level():
	var loc = Location.new("World Map\\", "World Map")
	assert_false(loc.is_instant_travel)

func test_instant_travel_default_nested():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_true(loc.is_instant_travel)

func test_get_containing_area_id_inside():
	var loc = Location.new("World Map\\Small Village\\", "Small Village")
	assert_eq(loc.get_containing_area_id(), "World Map\\Small Village\\")

func test_get_containing_area_id_node():
	var loc = Location.new("World Map\\Small Village", "Small Village")
	assert_eq(loc.get_containing_area_id(), "World Map\\")

func test_serialization_with_instant_travel():
	var original = Location.new("World Map\\Village\\", "Village")
	original.is_instant_travel = false  # Override default

	var dict = original.to_dict()
	var restored = Location.from_dict(dict)

	assert_eq(restored.is_instant_travel, false)
