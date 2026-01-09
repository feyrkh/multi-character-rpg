extends GutTest

var _registry: InstanceRegistry

func before_each():
	# Get a fresh registry for each test
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()

func after_each():
	_registry.clear_all()

func test_init_default():
	var char = PlayableCharacter.new()
	assert_eq(char.char_name, "")
	assert_eq(char.current_location_id, "")
	assert_eq(char.days_remaining, 30)
	assert_eq(char.notes, "")

func test_init_with_name():
	var char = PlayableCharacter.new("Hero")
	assert_eq(char.char_name, "Hero")

func test_default_stats():
	var char = PlayableCharacter.new("Test")
	assert_eq(char.stats["hp"], 100)
	assert_eq(char.stats["max_hp"], 100)
	assert_eq(char.stats["mp"], 50)
	assert_eq(char.stats["max_mp"], 50)
	assert_eq(char.stats["attack"], 10)
	assert_eq(char.stats["defense"], 10)

func test_spend_days_success():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 30
	var result = char.spend_days(10)
	assert_true(result)
	assert_eq(char.days_remaining, 20)

func test_spend_days_failure():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 5
	var result = char.spend_days(10)
	assert_false(result)
	assert_eq(char.days_remaining, 5)

func test_can_spend_days_true():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 15
	assert_true(char.can_spend_days(10))

func test_can_spend_days_false():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 5
	assert_false(char.can_spend_days(10))

func test_can_spend_days_exact():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 10
	assert_true(char.can_spend_days(10))

func test_reset_days():
	var char = PlayableCharacter.new("Test")
	char.days_remaining = 5
	char.reset_days()
	assert_eq(char.days_remaining, 30)

func test_add_log_entry():
	var char = PlayableCharacter.new("Test")
	char.add_log_entry(3, 15, "Won a battle")
	assert_eq(char.action_log.size(), 1)
	assert_eq(char.action_log[0].month, 3)
	assert_eq(char.action_log[0].day, 15)
	assert_eq(char.action_log[0].description, "Won a battle")

func test_add_multiple_log_entries():
	var char = PlayableCharacter.new("Test")
	char.add_log_entry(1, 1, "Started journey")
	char.add_log_entry(1, 5, "Found treasure")
	char.add_log_entry(2, 10, "Defeated boss")
	assert_eq(char.action_log.size(), 3)

func test_get_id_assigns_id():
	var char = PlayableCharacter.new("Test")
	var id = char.get_id()
	assert_ne(id, "")
	assert_true(char.has_id())

func test_to_dict():
	var char = PlayableCharacter.new("Warrior")
	char.current_location_id = "town\\square"
	char.days_remaining = 25
	char.notes = "Remember to buy potions"
	char.add_log_entry(1, 1, "Test entry")
	char.get_id()  # Ensure ID is assigned

	var dict = char.to_dict()
	assert_eq(dict["char_name"], "Warrior")
	assert_eq(dict["current_location_id"], "town\\square")
	assert_eq(dict["days_remaining"], 25)
	assert_eq(dict["notes"], "Remember to buy potions")
	assert_eq(dict["action_log"].size(), 1)
	assert_true(dict.has("__class__"))
	assert_true(dict.has("__id__"))

func test_from_dict():
	# First create and register an original character
	var original = PlayableCharacter.new("Mage")
	original.current_location_id = "tower\\library"
	original.days_remaining = 20
	original.notes = "Study spells"
	original.stats["mp"] = 100
	var original_id = original.get_id()

	# Clear registry and restore from dict
	var dict = original.to_dict()
	_registry.clear_all()

	var restored = PlayableCharacter.from_dict(dict)
	assert_eq(restored.char_name, "Mage")
	assert_eq(restored.current_location_id, "tower\\library")
	assert_eq(restored.days_remaining, 20)
	assert_eq(restored.notes, "Study spells")

func test_serialization_roundtrip():
	var original = PlayableCharacter.new("Rogue")
	original.current_location_id = "city\\back_alley"
	original.days_remaining = 15
	original.notes = "Find the hidden entrance"
	original.stats["attack"] = 15
	original.add_log_entry(5, 10, "Stole valuable item")
	original.get_id()

	var dict = original.to_dict()
	_registry.clear_all()
	var restored = PlayableCharacter.from_dict(dict)

	assert_eq(restored.char_name, original.char_name)
	assert_eq(restored.current_location_id, original.current_location_id)
	assert_eq(restored.days_remaining, original.days_remaining)
	assert_eq(restored.notes, original.notes)
	assert_eq(restored.action_log.size(), original.action_log.size())
