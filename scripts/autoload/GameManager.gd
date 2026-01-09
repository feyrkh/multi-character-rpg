# GameManager.gd
# Manages characters, parties, and game state persistence
extends Node

signal active_party_changed(party: Party)
signal character_created(character: PlayableCharacter)
signal character_updated(character: PlayableCharacter)
signal party_created(party: Party)
signal party_deleted(party: Party)

var active_party: Party = null

func _ready() -> void:
	pass

# --- Character Management ---

func create_character(char_name: String, location_id: String = "") -> PlayableCharacter:
	var character = PlayableCharacter.new(char_name)
	character.current_location_id = location_id
	character.get_id()  # Ensure ID is assigned and registered
	character_created.emit(character)
	return character

func get_character_by_id(id: String) -> PlayableCharacter:
	var registry = InstanceRegistry.get_registry()
	return registry.get_instance("PlayableCharacter", id)

func get_all_characters() -> Array[PlayableCharacter]:
	var registry = InstanceRegistry.get_registry()
	var instances = registry.get_all_instances("PlayableCharacter")
	var result: Array[PlayableCharacter] = []
	for inst in instances:
		if inst is PlayableCharacter:
			result.append(inst)
	return result

func update_character_notes(character: PlayableCharacter, notes: String) -> void:
	character.notes = notes
	character_updated.emit(character)

# --- Party Management ---

func create_party(party_name: String, members: Array[PlayableCharacter] = [], location_id: String = "") -> Party:
	var party = Party.new(party_name)
	party.current_location_id = location_id
	for member in members:
		party.add_member_id(member.get_id())
		member.current_location_id = location_id
	party.get_id()  # Ensure ID is assigned and registered
	party_created.emit(party)
	return party

func get_party_by_id(id: String) -> Party:
	var registry = InstanceRegistry.get_registry()
	return registry.get_instance("Party", id)

func get_all_parties() -> Array[Party]:
	var registry = InstanceRegistry.get_registry()
	var instances = registry.get_all_instances("Party")
	var result: Array[Party] = []
	for inst in instances:
		if inst is Party:
			result.append(inst)
	return result

func set_active_party(party: Party) -> void:
	var old_party = active_party
	active_party = party
	active_party_changed.emit(party)

func get_party_members(party: Party) -> Array[PlayableCharacter]:
	var result: Array[PlayableCharacter] = []
	for member_id in party.member_ids:
		var character = get_character_by_id(member_id)
		if character:
			result.append(character)
	return result

func switch_party(new_party: Party, updated_notes: Dictionary = {}) -> void:
	# Update notes for outgoing party members if provided
	if active_party:
		for member_id in active_party.member_ids:
			if updated_notes.has(member_id):
				var character = get_character_by_id(member_id)
				if character:
					update_character_notes(character, updated_notes[member_id])

	set_active_party(new_party)

func remove_character_from_party(party: Party, character: PlayableCharacter) -> Party:
	# Cannot remove last member
	if party.get_member_count() <= 1:
		return null

	party.remove_member_id(character.get_id())

	# Create a new solo party for the removed character
	var solo_party = create_party(character.char_name + "'s Party", [character], character.current_location_id)
	return solo_party

func add_character_to_party(party: Party, character: PlayableCharacter) -> void:
	# Find and delete the character's current solo party if they have one
	var current_party = find_party_containing(character)
	if current_party and current_party != party:
		if current_party.get_member_count() == 1:
			delete_party(current_party)
		else:
			current_party.remove_member_id(character.get_id())

	party.add_member_id(character.get_id())
	character.current_location_id = party.current_location_id

func find_party_containing(character: PlayableCharacter) -> Party:
	var char_id = character.get_id()
	for party in get_all_parties():
		if party.has_member(char_id):
			return party
	return null

func delete_party(party: Party) -> void:
	if party == active_party:
		active_party = null

	var registry = InstanceRegistry.get_registry()
	registry.unregister_instance("Party", party.get_id())
	party_deleted.emit(party)

# --- Save/Load ---

const SAVE_FILE_REGISTRY = "registry"
const SAVE_FILE_GAME_STATE = "game_state"

func save_game(slot_name: String) -> bool:
	# Save the instance registry (contains all characters and parties)
	InstanceRegistry.save_to_file(slot_name, SAVE_FILE_REGISTRY)

	# Save additional game state
	var game_state = {
		"active_party_id": active_party.get_id() if active_party else ""
	}
	return SaveSystem.save_game(game_state, slot_name, SAVE_FILE_GAME_STATE)

func load_game(slot_name: String) -> bool:
	# Load the instance registry
	InstanceRegistry.load_from_file(slot_name, SAVE_FILE_REGISTRY)

	# Load additional game state
	var game_state = LoadSystem.load_object(slot_name, SAVE_FILE_GAME_STATE)
	if game_state is Dictionary:
		var active_id = game_state.get("active_party_id", "")
		if active_id != "":
			active_party = get_party_by_id(active_id)
			if active_party:
				active_party_changed.emit(active_party)
		return true
	return false

func has_save(slot_name: String) -> bool:
	var path = "user://saves/" + slot_name + "/" + SAVE_FILE_REGISTRY
	return FileAccess.file_exists(path + ".json") or FileAccess.file_exists(path + ".bin")

func new_game() -> void:
	# Clear the registry and start fresh
	var registry = InstanceRegistry.get_registry()
	registry.clear_all()
	active_party = null
