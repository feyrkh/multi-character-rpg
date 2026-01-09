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
var combat_form_ids: Array[String] = []
var notes: String = ""
var action_log: Array[ActionLogEntry] = []

func _init(p_name: String = "") -> void:
	char_name = p_name

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
	result["combat_form_ids"] = combat_form_ids.duplicate()
	result["notes"] = notes
	result["action_log"] = action_log.map(func(entry): return entry.to_dict())
	return result

static func from_dict(dict: Dictionary) -> RegisteredObject:
	var character = PlayableCharacter.new(dict.get("char_name", ""))
	character.current_location_id = dict.get("current_location_id", "")
	character.days_remaining = dict.get("days_remaining", 30)
	character.stats = dict.get("stats", {}).duplicate()
	character.combat_form_ids = Array(dict.get("combat_form_ids", []), TYPE_STRING, "", null)
	character.notes = dict.get("notes", "")

	var log_data = dict.get("action_log", [])
	for entry_dict in log_data:
		character.action_log.append(ActionLogEntry.from_dict(entry_dict))

	return _resolve_canonical(character, dict)
