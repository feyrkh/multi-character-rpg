extends GutTest

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()
	GameManager.new_game()

func after_each():
	_registry.clear_all()

# --- Character Creation Tests ---

func test_create_character():
	var char = GameManager.create_character("Hero")
	assert_not_null(char)
	assert_eq(char.char_name, "Hero")
	assert_true(char.has_id())

func test_create_character_with_location():
	var char = GameManager.create_character("Warrior", "town\\square")
	assert_eq(char.current_location_id, "town\\square")

func test_get_character_by_id():
	var char = GameManager.create_character("Mage")
	var id = char.get_id()
	var retrieved = GameManager.get_character_by_id(id)
	assert_eq(retrieved, char)

func test_get_all_characters():
	GameManager.create_character("Char1")
	GameManager.create_character("Char2")
	GameManager.create_character("Char3")
	var chars = GameManager.get_all_characters()
	assert_eq(chars.size(), 3)

func test_update_character_notes():
	var char = GameManager.create_character("Test")
	GameManager.update_character_notes(char, "Important note")
	assert_eq(char.notes, "Important note")

# --- Party Creation Tests ---

func test_create_party_empty():
	var party = GameManager.create_party("Empty Party")
	assert_not_null(party)
	assert_eq(party.party_name, "Empty Party")
	assert_eq(party.get_member_count(), 0)

func test_create_party_with_members():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party = GameManager.create_party("Heroes", [char1, char2])
	assert_eq(party.get_member_count(), 2)
	assert_true(party.has_member(char1.get_id()))
	assert_true(party.has_member(char2.get_id()))

func test_create_party_sets_member_locations():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party = GameManager.create_party("Heroes", [char1, char2], "start\\location")
	assert_eq(char1.current_location_id, "start\\location")
	assert_eq(char2.current_location_id, "start\\location")

func test_get_party_by_id():
	var party = GameManager.create_party("Test Party")
	var id = party.get_id()
	var retrieved = GameManager.get_party_by_id(id)
	assert_eq(retrieved, party)

func test_get_all_parties():
	GameManager.create_party("Party1")
	GameManager.create_party("Party2")
	var parties = GameManager.get_all_parties()
	assert_eq(parties.size(), 2)

# --- Active Party Tests ---

func test_set_active_party():
	var party = GameManager.create_party("Main Party")
	GameManager.set_active_party(party)
	assert_eq(GameManager.active_party, party)

func test_get_party_members():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party = GameManager.create_party("Heroes", [char1, char2])
	var members = GameManager.get_party_members(party)
	assert_eq(members.size(), 2)
	assert_true(char1 in members)
	assert_true(char2 in members)

func test_switch_party():
	var char1 = GameManager.create_character("Hero1")
	var party1 = GameManager.create_party("Party1", [char1])
	var char2 = GameManager.create_character("Hero2")
	var party2 = GameManager.create_party("Party2", [char2])

	GameManager.set_active_party(party1)
	GameManager.switch_party(party2)
	assert_eq(GameManager.active_party, party2)

func test_switch_party_updates_notes():
	var char1 = GameManager.create_character("Hero1")
	var party1 = GameManager.create_party("Party1", [char1])
	var party2 = GameManager.create_party("Party2")

	GameManager.set_active_party(party1)
	var notes = {char1.get_id(): "Updated notes"}
	GameManager.switch_party(party2, notes)
	assert_eq(char1.notes, "Updated notes")

# --- Party Member Management ---

func test_find_party_containing():
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char])
	var found = GameManager.find_party_containing(char)
	assert_eq(found, party)

func test_find_party_containing_not_found():
	var char = GameManager.create_character("Loner")
	var found = GameManager.find_party_containing(char)
	assert_null(found)

func test_remove_character_from_party():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party = GameManager.create_party("Party", [char1, char2])

	var solo_party = GameManager.remove_character_from_party(party, char1)
	assert_not_null(solo_party)
	assert_eq(party.get_member_count(), 1)
	assert_eq(solo_party.get_member_count(), 1)
	assert_true(solo_party.has_member(char1.get_id()))

func test_remove_last_character_fails():
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char])
	var result = GameManager.remove_character_from_party(party, char)
	assert_null(result)
	assert_eq(party.get_member_count(), 1)

func test_add_character_to_party():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	var party1 = GameManager.create_party("Party1", [char1], "location_a")
	var party2 = GameManager.create_party("Party2", [char2], "location_b")

	GameManager.add_character_to_party(party1, char2)
	assert_eq(party1.get_member_count(), 2)
	assert_eq(char2.current_location_id, "location_a")

# --- New Game ---

func test_new_game_clears_state():
	GameManager.create_character("Hero")
	GameManager.create_party("Party")
	GameManager.new_game()
	assert_eq(GameManager.get_all_characters().size(), 0)
	assert_eq(GameManager.get_all_parties().size(), 0)
	assert_null(GameManager.active_party)

# --- Signal Tests ---

func test_character_created_signal():
	watch_signals(GameManager)
	GameManager.create_character("Hero")
	assert_signal_emitted(GameManager, "character_created")

func test_party_created_signal():
	watch_signals(GameManager)
	GameManager.create_party("Party")
	assert_signal_emitted(GameManager, "party_created")

func test_active_party_changed_signal():
	var party = GameManager.create_party("Party")
	watch_signals(GameManager)
	GameManager.set_active_party(party)
	assert_signal_emitted(GameManager, "active_party_changed")
