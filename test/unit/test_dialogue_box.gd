extends GutTest


func test_dialogue_box_scene_loads() -> void:
	# Test that the dialogue box scene can be loaded
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	assert_not_null(dialogue_box_scene, "Dialogue box scene should load")

	var dialogue_box = dialogue_box_scene.instantiate()
	assert_not_null(dialogue_box, "Dialogue box should instantiate")
	dialogue_box.queue_free()


func test_dialogue_box_starts_with_lines() -> void:
	# Test that dialogue box can start with dialogue lines
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	var lines = [
		{"character": "Test Character", "text": "First line"},
		{"character": "Test Character", "text": "Second line"}
	]

	dialogue_box.start_dialogue(lines)

	assert_eq(dialogue_box.current_line_index, 0, "Should start at first line")
	assert_eq(dialogue_box.dialogue_lines.size(), 2, "Should have 2 lines")


func test_dialogue_box_advances_lines() -> void:
	# Test that dialogue advances through lines
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	var lines = [
		{"character": "NPC", "text": "Line 1"},
		{"character": "NPC", "text": "Line 2"},
		{"character": "NPC", "text": "Line 3"}
	]

	dialogue_box.start_dialogue(lines)
	assert_eq(dialogue_box.current_line_index, 0)

	dialogue_box._advance_dialogue()
	assert_eq(dialogue_box.current_line_index, 1, "Should advance to line 1")

	dialogue_box._advance_dialogue()
	assert_eq(dialogue_box.current_line_index, 2, "Should advance to line 2")


func test_dialogue_box_emits_finished_signal() -> void:
	# Test that dialogue box emits finished signal when done
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	watch_signals(dialogue_box)

	var lines = [
		{"character": "NPC", "text": "Only line"}
	]

	dialogue_box.start_dialogue(lines)
	dialogue_box._advance_dialogue()  # Advance past the last line

	assert_signal_emitted(dialogue_box, "dialogue_finished")


func test_dialogue_box_auto_advance_toggle() -> void:
	# Test that auto-advance mode can be toggled
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	assert_false(dialogue_box.auto_advance_enabled, "Auto-advance should be off by default")

	dialogue_box._on_auto_toggle_pressed()
	assert_true(dialogue_box.auto_advance_enabled, "Auto-advance should be enabled")

	dialogue_box._on_auto_toggle_pressed()
	assert_false(dialogue_box.auto_advance_enabled, "Auto-advance should be disabled")


func test_dialogue_box_displays_character_name() -> void:
	# Test that dialogue box shows character name correctly
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	var lines = [
		{"character": "Tavern Keeper", "text": "Welcome!"}
	]

	dialogue_box.start_dialogue(lines)

	assert_eq(dialogue_box.character_name_label.text, "Tavern Keeper")
	assert_eq(dialogue_box.dialogue_text_label.text, "Welcome!")


func test_dialogue_box_empty_lines_finishes_immediately() -> void:
	# Test that empty dialogue lines emit finished signal
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	watch_signals(dialogue_box)

	dialogue_box.start_dialogue([])
	assert_push_error("No dialogue lines provided")

	assert_signal_emitted(dialogue_box, "dialogue_finished")


func test_dialogue_box_visuals_setup() -> void:
	# Test that visual setup doesn't crash with empty paths
	var dialogue_box_scene = load("res://scenes/ui/dialogue_box.tscn")
	var dialogue_box = dialogue_box_scene.instantiate()
	add_child_autofree(dialogue_box)

	# Should not crash with empty paths
	dialogue_box.setup_visuals("", "", "", "")

	# Should hide elements when paths are empty
	assert_false(dialogue_box.left_portrait.visible, "Left portrait should be hidden with empty path")
	assert_false(dialogue_box.right_portrait.visible, "Right portrait should be hidden with empty path")
	assert_false(dialogue_box.background_image.visible, "Background should be hidden with empty path")
	assert_false(dialogue_box.central_overlay.visible, "Overlay should be hidden with empty path")
