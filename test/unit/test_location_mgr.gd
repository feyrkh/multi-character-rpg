extends GutTest

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()
	GameManager.new_game()
	TimeMgr.reset()
	LocationMgr.reset()

func after_each():
	_registry.clear_all()

func _create_test_locations() -> void:
	var town = Location.new("town", "Town Center")
	town.is_discovered = true
	town.position = Vector2(100, 100)

	var forest = Location.new("forest", "Dark Forest")
	forest.is_discovered = true
	forest.position = Vector2(200, 100)

	var cave = Location.new("cave", "Hidden Cave")
	cave.is_discovered = false
	cave.position = Vector2(300, 100)

	LocationMgr.register_location(town)
	LocationMgr.register_location(forest)
	LocationMgr.register_location(cave)

	LocationMgr.register_link(LocationLink.new("town", "forest", 2))
	LocationMgr.register_link(LocationLink.new("forest", "cave", 3))

# --- Location Registration Tests ---

func test_register_location():
	var loc = Location.new("test_loc", "Test Location")
	LocationMgr.register_location(loc)
	var retrieved = LocationMgr.get_location("test_loc")
	assert_eq(retrieved, loc)

func test_get_location_not_found():
	var retrieved = LocationMgr.get_location("nonexistent")
	assert_null(retrieved)

func test_get_all_locations():
	_create_test_locations()
	var locs = LocationMgr.get_all_locations()
	assert_eq(locs.size(), 3)

func test_get_discovered_locations():
	_create_test_locations()
	var locs = LocationMgr.get_discovered_locations()
	assert_eq(locs.size(), 2)  # town and forest are discovered

# --- Graph Navigation Tests ---

func test_get_adjacent_locations():
	_create_test_locations()
	var adjacent = LocationMgr.get_adjacent_locations("forest")
	assert_eq(adjacent.size(), 2)  # town and cave

func test_get_discovered_adjacent_locations():
	_create_test_locations()
	var adjacent = LocationMgr.get_discovered_adjacent_locations("forest")
	assert_eq(adjacent.size(), 1)  # only town is discovered

func test_get_link_between():
	_create_test_locations()
	var link = LocationMgr.get_link_between("town", "forest")
	assert_not_null(link)
	assert_eq(link.travel_distance, 2)

func test_get_link_between_reversed():
	_create_test_locations()
	# Should work both directions
	var link = LocationMgr.get_link_between("forest", "town")
	assert_not_null(link)
	assert_eq(link.travel_distance, 2)

func test_get_link_between_not_connected():
	_create_test_locations()
	var link = LocationMgr.get_link_between("town", "cave")
	assert_null(link)

func test_get_travel_distance():
	_create_test_locations()
	assert_eq(LocationMgr.get_travel_distance("town", "forest"), 2)
	assert_eq(LocationMgr.get_travel_distance("forest", "cave"), 3)

func test_get_travel_distance_not_connected():
	_create_test_locations()
	assert_eq(LocationMgr.get_travel_distance("town", "cave"), -1)

func test_are_connected():
	_create_test_locations()
	assert_true(LocationMgr.are_connected("town", "forest"))
	assert_true(LocationMgr.are_connected("forest", "town"))
	assert_false(LocationMgr.are_connected("town", "cave"))

# --- Movement Tests ---

func test_can_move_party_success():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	char.days_remaining = 30
	var party = GameManager.create_party("Party", [char], "town")
	assert_true(LocationMgr.can_move_party(party, "forest"))

func test_can_move_party_not_connected():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "town")
	assert_false(LocationMgr.can_move_party(party, "cave"))

func test_can_move_party_undiscovered():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "forest")
	# cave is not discovered
	assert_false(LocationMgr.can_move_party(party, "cave"))

func test_can_move_party_not_enough_time():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	char.days_remaining = 1
	var party = GameManager.create_party("Party", [char], "town")
	# travel to forest costs 2 days
	assert_false(LocationMgr.can_move_party(party, "forest"))

func test_can_move_party_same_location():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "town")
	assert_false(LocationMgr.can_move_party(party, "town"))

func test_request_move_emits_signal_for_distance():
	_create_test_locations()
	# Make town NOT instant travel so it requires confirmation
	var town = LocationMgr.get_location("town")
	town.is_instant_travel = false

	var char = GameManager.create_character("Hero")
	char.days_remaining = 30
	var party = GameManager.create_party("Party", [char], "town")

	watch_signals(LocationMgr)
	LocationMgr.request_move(party, "forest")
	# Should emit move_requested since distance > 0 and not instant travel
	assert_signal_emitted(LocationMgr, "move_requested")
	# Party should NOT have moved yet
	assert_eq(party.current_location_id, "town")

func test_request_move_instant_for_zero_distance():
	# Create locations with zero distance link
	var loc_a = Location.new("loc_a", "Location A")
	loc_a.is_discovered = true
	loc_a.is_instant_travel = false
	var loc_b = Location.new("loc_b", "Location B")
	loc_b.is_discovered = true
	LocationMgr.register_location(loc_a)
	LocationMgr.register_location(loc_b)
	LocationMgr.register_link(LocationLink.new("loc_a", "loc_b", 0))

	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "loc_a")

	LocationMgr.request_move(party, "loc_b")
	# Should move immediately since distance is 0
	assert_eq(party.current_location_id, "loc_b")

func test_request_move_instant_travel_location():
	_create_test_locations()
	# Town is instant travel by default (nested location)
	var town = LocationMgr.get_location("town")
	town.is_instant_travel = true

	var char = GameManager.create_character("Hero")
	char.days_remaining = 30
	var party = GameManager.create_party("Party", [char], "town")

	LocationMgr.request_move(party, "forest")
	# Should move immediately since instant travel
	assert_eq(party.current_location_id, "forest")
	assert_eq(char.days_remaining, 28)

func test_confirm_move():
	_create_test_locations()
	var town = LocationMgr.get_location("town")
	town.is_instant_travel = false

	var char = GameManager.create_character("Hero")
	char.days_remaining = 30
	var party = GameManager.create_party("Party", [char], "town")

	LocationMgr.request_move(party, "forest")
	assert_eq(party.current_location_id, "town")  # Not moved yet

	watch_signals(LocationMgr)
	LocationMgr.confirm_move()
	assert_signal_emitted(LocationMgr, "move_confirmed")
	assert_eq(party.current_location_id, "forest")
	assert_eq(char.days_remaining, 28)

func test_cancel_move():
	_create_test_locations()
	var town = LocationMgr.get_location("town")
	town.is_instant_travel = false

	var char = GameManager.create_character("Hero")
	char.days_remaining = 30
	var party = GameManager.create_party("Party", [char], "town")

	LocationMgr.request_move(party, "forest")
	watch_signals(LocationMgr)
	LocationMgr.cancel_move()
	assert_signal_emitted(LocationMgr, "move_cancelled")
	assert_eq(party.current_location_id, "town")
	assert_eq(char.days_remaining, 30)  # No time spent

func test_request_move_updates_all_members():
	_create_test_locations()
	var town = LocationMgr.get_location("town")
	town.is_instant_travel = true

	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	char1.days_remaining = 30
	char2.days_remaining = 30
	var party = GameManager.create_party("Party", [char1, char2], "town")

	LocationMgr.request_move(party, "forest")
	assert_eq(char1.current_location_id, "forest")
	assert_eq(char2.current_location_id, "forest")

# --- Discovery Tests ---

func test_discover_location():
	_create_test_locations()
	assert_false(LocationMgr.is_discovered("cave"))
	var result = LocationMgr.discover_location("cave")
	assert_true(result)
	assert_true(LocationMgr.is_discovered("cave"))

func test_discover_location_already_discovered():
	_create_test_locations()
	var result = LocationMgr.discover_location("town")
	assert_false(result)  # Already discovered

func test_is_discovered():
	_create_test_locations()
	assert_true(LocationMgr.is_discovered("town"))
	assert_false(LocationMgr.is_discovered("cave"))

# --- Character Query Tests ---

func test_get_characters_at_location():
	_create_test_locations()
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var char3 = GameManager.create_character("Hero3")
	char1.current_location_id = "town"
	char2.current_location_id = "town"
	char3.current_location_id = "forest"

	var at_town = LocationMgr.get_characters_at_location("town")
	assert_eq(at_town.size(), 2)

func test_get_parties_at_location():
	_create_test_locations()
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party1 = GameManager.create_party("Party1", [char1], "town")
	var party2 = GameManager.create_party("Party2", [char2], "forest")

	var at_town = LocationMgr.get_parties_at_location("town")
	assert_eq(at_town.size(), 1)
	assert_eq(at_town[0], party1)

# --- State Management ---

func test_get_state():
	_create_test_locations()
	var state = LocationMgr.get_state()
	assert_eq(state["locations"].size(), 3)
	assert_eq(state["links"].size(), 2)

func test_load_state():
	var state = {
		"locations": [
			{"id": "a", "display_name": "A", "icon_path": "", "background_path": "", "is_discovered": true, "position": {"x": 0, "y": 0}},
			{"id": "b", "display_name": "B", "icon_path": "", "background_path": "", "is_discovered": false, "position": {"x": 100, "y": 0}}
		],
		"links": [
			{"from_location_id": "a", "to_location_id": "b", "travel_distance": 5}
		]
	}
	LocationMgr.load_state(state)
	assert_not_null(LocationMgr.get_location("a"))
	assert_not_null(LocationMgr.get_location("b"))
	assert_eq(LocationMgr.get_travel_distance("a", "b"), 5)

func test_reset():
	_create_test_locations()
	LocationMgr.reset()
	assert_eq(LocationMgr.get_all_locations().size(), 0)

# --- Signal Tests ---

func test_moved_to_location_signal():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "town")
	watch_signals(LocationMgr)
	LocationMgr.request_move(party, "forest")
	LocationMgr.confirm_move()
	assert_signal_emitted(LocationMgr, "moved_to_location")

func test_party_moved_signal():
	_create_test_locations()
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char], "town")
	watch_signals(LocationMgr)
	LocationMgr.request_move(party, "forest")
	LocationMgr.confirm_move()
	assert_signal_emitted(LocationMgr, "party_moved")

func test_location_discovered_signal():
	_create_test_locations()
	watch_signals(LocationMgr)
	LocationMgr.discover_location("cave")
	assert_signal_emitted(LocationMgr, "location_discovered")

# --- Path Parsing Tests ---

func test_parse_path_simple():
	var result = LocationMgr.parse_path("World Map\\")
	assert_eq(result["segments"], ["World Map"])
	assert_true(result["is_inside"])
	assert_eq(result["depth"], 1)

func test_parse_path_nested():
	var result = LocationMgr.parse_path("World Map\\Village\\")
	assert_eq(result["segments"], ["World Map", "Village"])
	assert_true(result["is_inside"])
	assert_eq(result["depth"], 2)

func test_parse_path_node():
	var result = LocationMgr.parse_path("World Map\\Village")
	assert_eq(result["segments"], ["World Map", "Village"])
	assert_false(result["is_inside"])
	assert_eq(result["depth"], 1)

func test_get_parent_location_id():
	assert_eq(LocationMgr.get_parent_location_id("World Map\\Village\\"), "World Map\\")
	assert_eq(LocationMgr.get_parent_location_id("World Map\\Village"), "World Map\\")
	assert_eq(LocationMgr.get_parent_location_id("World Map\\"), "")

# --- Pathfinding Tests ---

func test_find_path_direct():
	_create_test_locations()
	var path = LocationMgr.find_path("town", "forest")
	assert_eq(path.size(), 2)
	assert_eq(path[0], "town")
	assert_eq(path[1], "forest")

func test_find_path_multi_hop():
	_create_test_locations()
	# town -> forest -> cave
	var path = LocationMgr.find_path("town", "cave")
	assert_eq(path.size(), 3)
	assert_eq(path[0], "town")
	assert_eq(path[1], "forest")
	assert_eq(path[2], "cave")

func test_find_path_same_location():
	_create_test_locations()
	var path = LocationMgr.find_path("town", "town")
	assert_eq(path.size(), 1)
	assert_eq(path[0], "town")

func test_find_path_no_route():
	_create_test_locations()
	var isolated = Location.new("island", "Isolated Island")
	isolated.is_discovered = true
	LocationMgr.register_location(isolated)
	# No links to island
	var path = LocationMgr.find_path("town", "island")
	assert_eq(path.size(), 0)

func test_calculate_path_distance():
	_create_test_locations()
	var path: Array[String] = ["town", "forest", "cave"]
	var distance = LocationMgr.calculate_path_distance(path)
	assert_eq(distance, 5)  # 2 + 3

func test_calculate_path_distance_single():
	_create_test_locations()
	var path: Array[String] = ["town"]
	var distance = LocationMgr.calculate_path_distance(path)
	assert_eq(distance, 0)

func test_get_path_points():
	_create_test_locations()
	var path: Array[String] = ["town", "forest"]
	var points = LocationMgr.get_path_points(path)
	assert_eq(points.size(), 2)
	assert_eq(points[0], Vector2(100, 100))
	assert_eq(points[1], Vector2(200, 100))

# --- Exploration Stats Tests ---

func test_get_total_links_from():
	_create_test_locations()
	assert_eq(LocationMgr.get_total_links_from("forest"), 2)  # town and cave
	assert_eq(LocationMgr.get_total_links_from("town"), 1)  # just forest

func test_get_discovered_links_from():
	_create_test_locations()
	# cave is not discovered
	assert_eq(LocationMgr.get_discovered_links_from("forest"), 1)  # only town
	assert_eq(LocationMgr.get_discovered_links_from("town"), 1)  # forest is discovered

func test_get_exploration_percent():
	_create_test_locations()
	# forest has 2 links, 1 discovered (town), 1 undiscovered (cave)
	assert_eq(LocationMgr.get_exploration_percent("forest"), 50.0)
	# town has 1 link, 1 discovered (forest)
	assert_eq(LocationMgr.get_exploration_percent("town"), 100.0)

func test_get_exploration_percent_no_links():
	var isolated = Location.new("isolated", "Isolated")
	LocationMgr.register_location(isolated)
	assert_eq(LocationMgr.get_exploration_percent("isolated"), 100.0)

# --- Area Query Tests ---

func test_get_locations_in_area():
	var world = Location.new("World\\", "World")
	var village = Location.new("World\\Village", "Village")
	var dungeon = Location.new("World\\Dungeon", "Dungeon")
	var tavern = Location.new("World\\Village\\Tavern", "Tavern")  # Different area

	LocationMgr.register_location(world)
	LocationMgr.register_location(village)
	LocationMgr.register_location(dungeon)
	LocationMgr.register_location(tavern)

	var in_world = LocationMgr.get_locations_in_area("World\\")
	assert_eq(in_world.size(), 2)  # village and dungeon

func test_get_exit_link_name_top_level():
	assert_eq(LocationMgr.get_exit_link_name("World\\Village\\"), "Travel")

func test_get_exit_link_name_nested():
	assert_eq(LocationMgr.get_exit_link_name("World\\Village\\Tavern\\"), "Leave")
