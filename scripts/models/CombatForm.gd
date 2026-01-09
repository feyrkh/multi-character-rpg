# CombatForm.gd
# A sequence of combat actions that defines a fighting style
class_name CombatForm
extends RefCounted

var form_name: String = ""
var description: String = ""
var actions: Array[CombatAction] = []

func _init(p_name: String = "") -> void:
	form_name = p_name

func add_action(action: CombatAction) -> void:
	actions.append(action)

func get_action_count() -> int:
	return actions.size()

func get_total_power() -> int:
	var total = 0
	for action in actions:
		total += action.power
	return total

func to_dict() -> Dictionary:
	var actions_data = []
	for action in actions:
		actions_data.append(action.to_dict())

	return {
		"form_name": form_name,
		"description": description,
		"actions": actions_data
	}

static func from_dict(dict: Dictionary) -> CombatForm:
	var form = CombatForm.new(dict.get("form_name", ""))
	form.description = dict.get("description", "")

	var actions_data = dict.get("actions", [])
	for action_dict in actions_data:
		form.actions.append(CombatAction.from_dict(action_dict))

	return form
