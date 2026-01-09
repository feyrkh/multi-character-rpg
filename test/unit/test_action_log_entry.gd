extends GutTest

func test_init_default():
	var entry = ActionLogEntry.new()
	assert_eq(entry.month, 1)
	assert_eq(entry.day, 1)
	assert_eq(entry.description, "")

func test_init_with_values():
	var entry = ActionLogEntry.new(5, 15, "Won a battle")
	assert_eq(entry.month, 5)
	assert_eq(entry.day, 15)
	assert_eq(entry.description, "Won a battle")

func test_to_dict():
	var entry = ActionLogEntry.new(3, 10, "Discovered a location")
	var dict = entry.to_dict()
	assert_eq(dict["month"], 3)
	assert_eq(dict["day"], 10)
	assert_eq(dict["description"], "Discovered a location")

func test_from_dict():
	var dict = {
		"month": 7,
		"day": 22,
		"description": "Fled from combat"
	}
	var entry = ActionLogEntry.from_dict(dict)
	assert_eq(entry.month, 7)
	assert_eq(entry.day, 22)
	assert_eq(entry.description, "Fled from combat")

func test_serialization_roundtrip():
	var original = ActionLogEntry.new(12, 30, "End of year event")
	var dict = original.to_dict()
	var restored = ActionLogEntry.from_dict(dict)
	assert_eq(restored.month, original.month)
	assert_eq(restored.day, original.day)
	assert_eq(restored.description, original.description)
