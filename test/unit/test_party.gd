extends GutTest

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()

func after_each():
	_registry.clear_all()

func test_init_default():
	var party = Party.new()
	assert_eq(party.party_name, "")
	assert_eq(party.member_ids.size(), 0)
	assert_eq(party.current_location_id, "")

func test_init_with_name():
	var party = Party.new("The Fellowship")
	assert_eq(party.party_name, "The Fellowship")

func test_add_member_id():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	assert_eq(party.member_ids.size(), 1)
	assert_true("char_1" in party.member_ids)

func test_add_member_id_no_duplicates():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	party.add_member_id("char_1")
	assert_eq(party.member_ids.size(), 1)

func test_add_multiple_members():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	party.add_member_id("char_2")
	party.add_member_id("char_3")
	assert_eq(party.member_ids.size(), 3)

func test_remove_member_id_success():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	party.add_member_id("char_2")
	var result = party.remove_member_id("char_1")
	assert_true(result)
	assert_eq(party.member_ids.size(), 1)
	assert_false("char_1" in party.member_ids)

func test_remove_member_id_not_found():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	var result = party.remove_member_id("char_99")
	assert_false(result)
	assert_eq(party.member_ids.size(), 1)

func test_get_member_count():
	var party = Party.new("Test Party")
	assert_eq(party.get_member_count(), 0)
	party.add_member_id("char_1")
	assert_eq(party.get_member_count(), 1)
	party.add_member_id("char_2")
	assert_eq(party.get_member_count(), 2)

func test_is_empty_true():
	var party = Party.new("Empty Party")
	assert_true(party.is_empty())

func test_is_empty_false():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	assert_false(party.is_empty())

func test_has_member_true():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	assert_true(party.has_member("char_1"))

func test_has_member_false():
	var party = Party.new("Test Party")
	party.add_member_id("char_1")
	assert_false(party.has_member("char_2"))

func test_get_id_assigns_id():
	var party = Party.new("Test Party")
	var id = party.get_id()
	assert_ne(id, "")
	assert_true(party.has_id())

func test_to_dict():
	var party = Party.new("Adventure Group")
	party.current_location_id = "forest\\clearing"
	party.add_member_id("hero_1")
	party.add_member_id("hero_2")
	party.get_id()

	var dict = party.to_dict()
	assert_eq(dict["party_name"], "Adventure Group")
	assert_eq(dict["current_location_id"], "forest\\clearing")
	assert_eq(dict["member_ids"].size(), 2)
	assert_true(dict.has("__class__"))
	assert_true(dict.has("__id__"))

func test_from_dict():
	var original = Party.new("Rescue Team")
	original.current_location_id = "dungeon\\entrance"
	original.add_member_id("rescuer_1")
	original.add_member_id("rescuer_2")
	original.get_id()

	var dict = original.to_dict()
	_registry.clear_all()

	var restored = Party.from_dict(dict)
	assert_eq(restored.party_name, "Rescue Team")
	assert_eq(restored.current_location_id, "dungeon\\entrance")
	assert_eq(restored.member_ids.size(), 2)

func test_serialization_roundtrip():
	var original = Party.new("Elite Squad")
	original.current_location_id = "castle\\throne_room"
	original.add_member_id("knight_1")
	original.add_member_id("knight_2")
	original.add_member_id("mage_1")
	original.get_id()

	var dict = original.to_dict()
	_registry.clear_all()
	var restored = Party.from_dict(dict)

	assert_eq(restored.party_name, original.party_name)
	assert_eq(restored.current_location_id, original.current_location_id)
	assert_eq(restored.member_ids.size(), original.member_ids.size())
