# PlayableCharacter.gd
# A character that can be controlled by the player
class_name PlayableCharacter
extends RegisteredObject

var char_name: String = ""
var current_location_id: String = ""
var days_remaining: int = 30
var stats: Dictionary = {
	"hp": 100,
	"max_hp": 100,
	"mp": 50,
	"max_mp": 50,
	"attack": 10,
	"defense": 10
}
var combat_forms: Array[CombatForm] = []           # Forms available to this character, order matters
var known_actions: Array[KnownCombatAction] = []   # Actions this character has learned
var max_action_sequence_length: int = 3            # Max actions per form
var defense_type: String = "fighter"               # Defense style: "fighter", "cleric", etc.
var notes: String = ""
var action_log: Array[ActionLogEntry] = []

func _init(p_name: String = "") -> void:
	char_name = p_name
	# All characters start with basic attack and defend actions
	known_actions.append(KnownCombatAction.new("attack"))
	known_actions.append(KnownCombatAction.new("defend"))

func add_log_entry(month: int, day: int, description: String) -> void:
	action_log.append(ActionLogEntry.new(month, day, description))

func reset_days() -> void:
	days_remaining = 30

func spend_days(amount: int) -> bool:
	if days_remaining < amount:
		return false
	days_remaining -= amount
	return true

func can_spend_days(amount: int) -> bool:
	return days_remaining >= amount

func to_dict() -> Dictionary:
	var result = super.to_dict()
	result["char_name"] = char_name
	result["current_location_id"] = current_location_id
	result["days_remaining"] = days_remaining
	result["stats"] = stats.duplicate()
	result["combat_forms"] = combat_forms.map(func(f): return f.to_dict())
	result["known_actions"] = known_actions.map(func(a): return a.to_dict())
	result["max_action_sequence_length"] = max_action_sequence_length
	result["defense_type"] = defense_type
	result["notes"] = notes
	result["action_log"] = action_log.map(func(entry): return entry.to_dict())
	return result

static func from_dict(dict: Dictionary) -> RegisteredObject:
	var character = PlayableCharacter.new(dict.get("char_name", ""))
	character.current_location_id = dict.get("current_location_id", "")
	character.days_remaining = dict.get("days_remaining", 30)
	character.stats = dict.get("stats", {}).duplicate()
	character.max_action_sequence_length = dict.get("max_action_sequence_length", 3)
	character.defense_type = dict.get("defense_type", "fighter")
	character.notes = dict.get("notes", "")

	# Restore combat forms
	var forms_data = dict.get("combat_forms", [])
	for form_dict in forms_data:
		character.combat_forms.append(CombatForm.from_dict(form_dict))

	# Restore known actions (clear defaults if save has actions to avoid duplicates)
	var actions_data = dict.get("known_actions", [])
	if actions_data.size() > 0:
		character.known_actions.clear()
		for action_dict in actions_data:
			character.known_actions.append(KnownCombatAction.from_dict(action_dict))

	# Restore action log
	var log_data = dict.get("action_log", [])
	for entry_dict in log_data:
		character.action_log.append(ActionLogEntry.from_dict(entry_dict))

	return _resolve_canonical(character, dict)
