# ConditionEvaluator.gd
# Safe evaluation of branching conditions for exploration events
class_name ConditionEvaluator
extends RefCounted

## Helper class for providing callable functions in expressions
class ConditionHelpers extends RefCounted:
	func random() -> float:
		return randf()

	func random_int(min_val: int, max_val: int) -> int:
		return randi_range(min_val, max_val)

## Evaluate a single condition string against the given context
## Returns true if the condition passes, false otherwise
## Supports party stats, character stats, step results, and random functions
static func evaluate(condition: String, context: Dictionary) -> bool:
	# Handle special literal cases
	if condition == "" or condition == "true":
		return true
	if condition == "false":
		return false

	var expr = Expression.new()
	var eval_context = _prepare_evaluation_context(context)

	# Parse expression with available variables
	var error = expr.parse(condition, eval_context.keys())
	if error != OK:
		push_error("ConditionEvaluator: Failed to parse condition '%s'" % condition)
		return false

	# Execute expression with helper object for callable functions
	var helpers = ConditionHelpers.new()
	var result = expr.execute(eval_context.values(), helpers, true)

	if expr.has_execute_failed():
		push_error("ConditionEvaluator: Failed to execute condition '%s'" % condition)
		return false

	# Convert result to boolean
	return bool(result)

## Prepare the evaluation context with party, character, step results, and utility functions
static func _prepare_evaluation_context(context: Dictionary) -> Dictionary:
	var eval_context = {}

	# Add party reference
	if context.has("party"):
		eval_context["party"] = _create_party_proxy(context["party"])

	# Add character reference (first party member)
	if context.has("party") and context["party"].get_member_count() > 0:
		var char_id = context["party"].member_ids[0]
		var character = GameManager.get_character_by_id(char_id)
		if character:
			eval_context["character"] = _create_character_proxy(character)

	# Add composite step results
	if context.has("composite_context"):
		var composite = context["composite_context"]
		for key in composite.keys():
			eval_context[key] = composite[key]

	# Note: random() and random_int() are available as methods on the base_instance (ConditionHelpers)
	# passed to execute(), not as variables

	return eval_context

## Create a read-only proxy dictionary for party data
static func _create_party_proxy(party: Party) -> Dictionary:
	return {
		"gold": party.gold if "gold" in party else 0,
		"member_count": party.get_member_count(),
		"location_id": party.current_location_id
	}

## Create a read-only proxy dictionary for character data
static func _create_character_proxy(character: PlayableCharacter) -> Dictionary:
	return {
		"name": character.char_name,
		"level": character.stats.get("level", 1) if character.stats else 1,
		"stats": character.stats.duplicate() if character.stats else {},
		"hp": character.stats.get("hp", 0) if character.stats else 0,
		"max_hp": character.stats.get("max_hp", 0) if character.stats else 0,
		"days_remaining": character.days_remaining
	}
