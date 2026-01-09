extends GutTest

func test_init_default():
	var link = LocationLink.new()
	assert_eq(link.from_location_id, "")
	assert_eq(link.to_location_id, "")
	assert_eq(link.travel_distance, 1)

func test_init_with_values():
	var link = LocationLink.new("city\\gates", "forest\\edge", 3)
	assert_eq(link.from_location_id, "city\\gates")
	assert_eq(link.to_location_id, "forest\\edge")
	assert_eq(link.travel_distance, 3)

func test_connects_from():
	var link = LocationLink.new("A", "B", 2)
	assert_true(link.connects("A"))

func test_connects_to():
	var link = LocationLink.new("A", "B", 2)
	assert_true(link.connects("B"))

func test_connects_neither():
	var link = LocationLink.new("A", "B", 2)
	assert_false(link.connects("C"))

func test_get_other_end_from_a():
	var link = LocationLink.new("A", "B", 2)
	assert_eq(link.get_other_end("A"), "B")

func test_get_other_end_from_b():
	var link = LocationLink.new("A", "B", 2)
	assert_eq(link.get_other_end("B"), "A")

func test_get_other_end_invalid():
	var link = LocationLink.new("A", "B", 2)
	assert_eq(link.get_other_end("C"), "")

func test_to_dict():
	var link = LocationLink.new("town\\square", "town\\market", 1)
	var dict = link.to_dict()
	assert_eq(dict["from_location_id"], "town\\square")
	assert_eq(dict["to_location_id"], "town\\market")
	assert_eq(dict["travel_distance"], 1)

func test_from_dict():
	var dict = {
		"from_location_id": "desert\\oasis",
		"to_location_id": "desert\\dunes",
		"travel_distance": 5
	}
	var link = LocationLink.from_dict(dict)
	assert_eq(link.from_location_id, "desert\\oasis")
	assert_eq(link.to_location_id, "desert\\dunes")
	assert_eq(link.travel_distance, 5)

func test_serialization_roundtrip():
	var original = LocationLink.new("start", "end", 10)
	var dict = original.to_dict()
	var restored = LocationLink.from_dict(dict)
	assert_eq(restored.from_location_id, original.from_location_id)
	assert_eq(restored.to_location_id, original.to_location_id)
	assert_eq(restored.travel_distance, original.travel_distance)
