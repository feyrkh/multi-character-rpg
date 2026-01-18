extends GutTest


func test_dialogue_event_loads_from_file() -> void:
	# Test that a DialogueEvent can be loaded from a file path
	var event_path = "res://data/events/dialogue/tavern_conversation.json"
	var event = ExplorationEvent.load_from_file(event_path)

	assert_not_null(event, "Dialogue event should load successfully")
	assert_true(event is DialogueEvent, "Should be a DialogueEvent instance")


func test_dialogue_event_extracts_type_from_path() -> void:
	# Test that event type is correctly extracted from path
	var event_path = "res://data/events/dialogue/tavern_conversation.json"
	var event_type = ExplorationEvent._extract_event_type_from_path(event_path)

	assert_eq(event_type, "dialogue", "Should extract 'dialogue' from path")


func test_dialogue_event_parses_json_data() -> void:
	# Test that DialogueEvent correctly parses event JSON
	var event_path = "res://data/events/dialogue/tavern_conversation.json"
	var event = ExplorationEvent.load_from_file(event_path) as DialogueEvent

	assert_not_null(event)
	assert_eq(event.event_id, "tavern_conversation")
	assert_eq(event.dialogue_mode, "file")
	assert_eq(event.dialogue_file, "res://data/dialogues/tavern_keeper.dialogue")
	assert_eq(event.right_portrait, "res://assets/portraits/tavern_keeper.png")
	assert_eq(event.background_image, "res://assets/backgrounds/tavern_interior.png")


func test_dialogue_file_exists() -> void:
	# Test that dialogue file exists and is in dialogue_manager format
	var file_path = "res://data/dialogues/tavern_keeper.dialogue"
	assert_true(FileAccess.file_exists(file_path), "Dialogue file should exist")

	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()

	# Check for dialogue_manager format markers
	assert_true(content.contains("~"), "Should contain dialogue_manager title markers")
	assert_true(content.contains("Tavern Keeper:"), "Should contain character dialogue")


func test_dialogue_event_execution() -> void:
	# Test that dialogue event executes and emits signals
	var event = DialogueEvent.new()
	event.event_id = "test_dialogue"
	event.dialogue_mode = "inline"
	event.dialogue_text = "Hello, world!"
	event.left_portrait = "res://assets/portraits/npc.png"

	watch_signals(event)
	var context = {}
	event.execute(context)

	assert_signal_emitted(event, "event_completed")
	# Verify the context was populated with dialogue data
	assert_eq(context["dialogue_text"], "Hello, world!")
	assert_eq(context["left_portrait"], "res://assets/portraits/npc.png")


func test_dialogue_event_inline_mode() -> void:
	# Test inline dialogue mode
	var event_data = {
		"event_id": "test_inline",
		"dialogue_text": "This is inline dialogue",
		"left_portrait": "res://assets/portraits/character.png"
	}

	var event = DialogueEvent.from_dict(event_data)

	assert_eq(event.dialogue_mode, "inline")
	assert_eq(event.dialogue_text, "This is inline dialogue")
	assert_eq(event.left_portrait, "res://assets/portraits/character.png")


func test_dialogue_event_file_mode() -> void:
	# Test file reference dialogue mode
	var event_data = {
		"event_id": "test_file",
		"dialogue_file": "res://data/dialogues/tavern_keeper.dialogue",
		"dialogue_title": "greeting"
	}

	var event = DialogueEvent.from_dict(event_data)

	assert_eq(event.dialogue_mode, "file")
	assert_eq(event.dialogue_file, "res://data/dialogues/tavern_keeper.dialogue")
	assert_eq(event.dialogue_title, "greeting")


func test_dialogue_file_has_titles() -> void:
	# Test that dialogue file has dialogue_manager titles
	var file_path = "res://data/dialogues/tavern_keeper.dialogue"
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()

	# Check for expected titles
	assert_true(content.contains("~ greeting"), "Should have greeting title")
	assert_true(content.contains("~ rumors"), "Should have rumors title")
	assert_gt(content.length(), 0, "File should not be empty")


func test_dialogue_file_has_choices() -> void:
	# Test that dialogue file has choice options
	var file_path = "res://data/dialogues/tavern_keeper.dialogue"
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()

	# Check for choice markers (lines starting with -)
	assert_true(content.contains("- Ask about"), "Should have choice options")
	assert_true(content.contains("=>"), "Should have flow control markers")
