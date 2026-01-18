# test_composite_branching.gd
# Unit tests for composite event branching logic
extends GutTest

var party: Party
var location: Location
var test_event: CompositeEvent

func before_each():
	# Setup party with a character
	party = Party.new()
	party.party_name = "Test Party"

	var character = PlayableCharacter.new()
	character.char_name = "Test Hero"
	character.stats = {"hp": 100, "max_hp": 100, "attack": 10, "defense": 5, "level": 5}
	character.days_remaining = 30

	GameManager.add_character(character)
	party.add_member(character.id)

	# Setup location
	location = Location.new()
	location.id = "Test Location"
	location.display_name = "Test Location"

func after_each():
	if party:
		for member_id in party.member_ids.duplicate():
			var char = GameManager.get_character_by_id(member_id)
			if char:
				GameManager.remove_character(char.id)
		party = null
	test_event = null

func test_combat_branching_on_flee():
	# Test that combat branching correctly routes to flee dialogue
	var event_data = {
		"event_type": "composite",
		"event_id": "test_combat_branch",
		"branch_mode": "branching",
		"steps": [
			{
				"step_id": 0,
				"event_type": "dialogue",
				"dialogue_text": "Enemy approaches!"
			},
			{
				"step_id": 1,
				"event_type": "combat",
				"enemies": ["res://data/enemies/bandit.json"],
				"next_step": {
					"branches": [
						{"condition": "step_1.combat_result == 0", "goto_step": 2},
						{"condition": "step_1.combat_result == 1", "goto_step": 3},
						{"condition": "step_1.combat_result == 2", "goto_step": 4}
					]
				}
			},
			{
				"step_id": 2,
				"event_type": "dialogue",
				"dialogue_text": "Victory!"
			},
			{
				"step_id": 3,
				"event_type": "dialogue",
				"dialogue_text": "Defeat..."
			},
			{
				"step_id": 4,
				"event_type": "dialogue",
				"dialogue_text": "You escaped!"
			}
		]
	}

	test_event = CompositeEvent.from_dict(event_data)
	assert_not_null(test_event, "Event should be created")
	assert_eq(test_event.branch_mode, "branching", "Should be in branching mode")

	var context = {"party": party, "location": location}

	# Start the event
	test_event.execute(context)

	# Step 0 should emit dialogue
	await get_tree().process_frame
	assert_eq(test_event.current_step, 0, "Should be at step 0")

	# Simulate dialogue completion
	test_event.continue_to_next_step()
	await get_tree().process_frame
	assert_eq(test_event.current_step, 1, "Should advance to combat at step 1")

	# Simulate combat completion with FLED result
	var combat_data = {
		"combat_outcome": "Fled",
		"combat_result": 2,
		"damage_dealt": 0,
		"damage_received": 0,
		"turns_taken": 0,
		"enemy_name": "Bandit"
	}
	test_event.continue_to_next_step(combat_data)
	await get_tree().process_frame

	# Should branch to step 4 (flee dialogue)
	assert_eq(test_event.current_step, 4, "Should branch to step 4 (flee dialogue)")

	# Check that step_1 context has combat data
	var step_1_data = test_event._context["composite_context"]["step_1"]
	assert_not_null(step_1_data, "Step 1 context should exist")
	assert_eq(step_1_data["combat_result"], 2, "Combat result should be FLED (2)")

	# Complete flee dialogue
	test_event.continue_to_next_step()
	await get_tree().process_frame

	# Should be complete (step 5 is out of bounds)
	assert_true(test_event.current_step >= test_event.steps.size(), "Event should be complete")

func test_combat_branching_on_victory():
	# Test victory path
	var event_data = {
		"event_type": "composite",
		"event_id": "test_combat_branch_victory",
		"branch_mode": "branching",
		"steps": [
			{
				"step_id": 0,
				"event_type": "combat",
				"enemies": ["res://data/enemies/bandit.json"],
				"next_step": {
					"branches": [
						{"condition": "step_0.combat_result == 0", "goto_step": 1},
						{"condition": "step_0.combat_result == 2", "goto_step": 2}
					]
				}
			},
			{
				"step_id": 1,
				"event_type": "dialogue",
				"dialogue_text": "Victory!"
			},
			{
				"step_id": 2,
				"event_type": "dialogue",
				"dialogue_text": "You escaped!"
			}
		]
	}

	test_event = CompositeEvent.from_dict(event_data)
	var context = {"party": party, "location": location}
	test_event.execute(context)
	await get_tree().process_frame

	# Simulate victory
	var combat_data = {
		"combat_result": 0,
		"combat_outcome": "Victory"
	}
	test_event.continue_to_next_step(combat_data)
	await get_tree().process_frame

	assert_eq(test_event.current_step, 1, "Should branch to victory dialogue at step 1")

func test_condition_evaluator_combat_result():
	# Test that ConditionEvaluator can properly evaluate combat results
	var context = {
		"composite_context": {
			"step_1": {
				"combat_result": 2,
				"combat_outcome": "Fled"
			}
		}
	}

	var result_win = ConditionEvaluator.evaluate("step_1.combat_result == 0", context)
	assert_false(result_win, "Should not match WIN (0)")

	var result_loss = ConditionEvaluator.evaluate("step_1.combat_result == 1", context)
	assert_false(result_loss, "Should not match LOSS (1)")

	var result_fled = ConditionEvaluator.evaluate("step_1.combat_result == 2", context)
	assert_true(result_fled, "Should match FLED (2)")

func test_bandit_ambush_event_structure():
	# Load the actual bandit ambush event and verify structure
	var event_file = "res://data/events/composite/bandit_ambush_complete.json"
	if not FileAccess.file_exists(event_file):
		fail_test("Bandit ambush event file not found: " + event_file)
		return

	var event = ExplorationEvent.load_from_file(event_file)
	assert_not_null(event, "Should load bandit event")
	assert_true(event is CompositeEvent, "Should be composite event")

	var composite = event as CompositeEvent
	assert_eq(composite.branch_mode, "branching", "Should have branching mode")
	assert_eq(composite.steps.size(), 6, "Should have 6 steps")

	# Check step 1 has branching
	var step_1 = composite.steps[1]
	assert_true(step_1.has("next_step"), "Step 1 should have next_step")
	assert_true(step_1["next_step"] is Dictionary, "next_step should be dictionary")
	assert_true(step_1["next_step"].has("branches"), "Should have branches array")

	var branches = step_1["next_step"]["branches"]
	assert_eq(branches.size(), 3, "Should have 3 branches (win/loss/fled)")

	# Verify flee branch
	var fled_branch = null
	for branch in branches:
		if "step_1.combat_result == 2" in branch["condition"]:
			fled_branch = branch
			break

	assert_not_null(fled_branch, "Should have flee branch")
	assert_eq(fled_branch["goto_step"], 5, "Flee should goto step 5")

func test_bandit_ambush_flee_simulation():
	# Simulate the entire bandit encounter with flee
	var event_file = "res://data/events/composite/bandit_ambush_complete.json"
	test_event = ExplorationEvent.load_from_file(event_file) as CompositeEvent
	assert_not_null(test_event, "Should load event")

	var context = {"party": party, "location": location}
	test_event.execute(context)
	await get_tree().process_frame

	# Step 0: Initial dialogue
	assert_eq(test_event.current_step, 0, "Should start at step 0")
	test_event.continue_to_next_step()
	await get_tree().process_frame

	# Step 1: Combat
	assert_eq(test_event.current_step, 1, "Should be at combat (step 1)")

	# Flee from combat
	var flee_data = {
		"combat_result": 2,
		"combat_outcome": "Fled",
		"damage_dealt": 0,
		"damage_received": 0,
		"turns_taken": 0,
		"enemy_name": "Bandit"
	}
	test_event.continue_to_next_step(flee_data)
	await get_tree().process_frame

	# Should jump to step 5 (flee dialogue)
	assert_eq(test_event.current_step, 5, "Should jump to step 5 after fleeing")

	# Check visited steps
	assert_true(0 in test_event.visited_steps, "Should have visited step 0")
	assert_true(1 in test_event.visited_steps, "Should have visited step 1")
	assert_false(2 in test_event.visited_steps, "Should NOT have visited step 2")
	assert_false(3 in test_event.visited_steps, "Should NOT have visited step 3")
	assert_false(4 in test_event.visited_steps, "Should NOT have visited step 4")
	assert_true(5 in test_event.visited_steps, "Should have visited step 5")

	# Complete flee dialogue
	test_event.continue_to_next_step()
	await get_tree().process_frame

	# Should be complete
	assert_true(test_event.current_step >= test_event.steps.size(), "Event should be complete after flee dialogue")
